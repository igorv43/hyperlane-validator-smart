#!/bin/bash

TX_HASH="0x5b98eaab735fb039790f6007528cf3a205b95e4adb49f4d018ce1eb7305e6891"
RPC="https://sepolia.drpc.org"
FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"

echo "========================================="
echo "🔧 OBTENDO ENDEREÇO E CONFIGURANDO"
echo "========================================="
echo ""

echo "Buscando evento ModuleDeployed via Etherscan API..."
echo ""

# Buscar eventos do factory
EVENT_SIG="0x9ead1e8752d06495979d851a64b37d5670b1cc60b5901298b3f41eea356c78ef"
TX_BLOCK=$(cast tx "$TX_HASH" --rpc-url "$RPC" 2>/dev/null | grep -i "blockNumber" | grep -oE "[0-9]+" | head -1)
if [ -z "$TX_BLOCK" ]; then
    LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    TX_BLOCK=$((LATEST_BLOCK - 10))
fi

FROM_BLOCK=$((TX_BLOCK - 10))
TO_BLOCK=$((TX_BLOCK + 10))

echo "Buscando eventos de $FROM_BLOCK até $TO_BLOCK..."
echo ""

# Buscar via Etherscan API
RESPONSE=$(curl -s "https://api-sepolia.etherscan.io/api?module=logs&action=getLogs&fromBlock=$FROM_BLOCK&toBlock=$TO_BLOCK&address=$FACTORY&topic0=$EVENT_SIG&apikey=$API_KEY" 2>/dev/null)

NEW_ISM=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('status') == '1' and data.get('result'):
        logs = data.get('result', [])
        for log in logs:
            # O endereço do DomainRoutingISM está no primeiro tópico após a assinatura
            topics = log.get('topics', [])
            if len(topics) > 1:
                addr = '0x' + topics[1][-40:]
                if addr != '0x0000000000000000000000000000000000000000':
                    print(addr)
                    break
            # Ou pode estar nos dados
            data_field = log.get('data', '')
            if len(data_field) >= 66:
                addr = '0x' + data_field[-40:]
                if addr != '0x0000000000000000000000000000000000000000':
                    print(addr)
                    break
except:
    pass
" 2>/dev/null | head -1)

if [ -z "$NEW_ISM" ]; then
    echo "⚠️  Não foi possível obter via API"
    echo ""
    echo "Por favor, acesse:"
    echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    echo "E encontre o evento 'ModuleDeployed'"
    echo "O endereço do DomainRoutingISM está no campo 'module' do evento"
    echo ""
    read -p "Digite o endereço do DomainRoutingISM: " NEW_ISM
    
    if [ -z "$NEW_ISM" ]; then
        echo "❌ Endereço não fornecido"
        exit 1
    fi
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo ""
echo "✅ DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

# Verificar se é DomainRoutingISM
TYPE=$(cast call "$NEW_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" != "1" ]; then
    echo "❌ Não é DomainRoutingISM (tipo: $TYPE_DEC)"
    exit 1
fi

echo "✅ Confirmado: É DomainRoutingISM"
echo ""

# Verificar e configurar
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Configurando para Terra Classic..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
    echo "✅ Configurado!"
else
    ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
    if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo "✅ Já está configurado para Terra Classic"
    else
        echo "Atualizando para Terra Classic..."
        cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
        echo "✅ Atualizado!"
    fi
fi

echo ""
echo "Configurando Warp Route..."
cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$NEW_ISM_CHECKSUM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
echo "✅ Warp Route configurado!"
echo ""

echo "========================================="
echo "✅ VERIFICAÇÃO FINAL"
echo "========================================="
echo ""

FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)
FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM final: $FINAL_ISM_CHECKSUM"
echo "Tipo: $FINAL_TYPE_DEC"

if [ "$FINAL_TYPE_DEC" = "1" ]; then
    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    
    echo "ISM para Terra Classic (1325): $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
        echo "   O Warp Route agora está configurado como no Solana:"
        echo "   → ISM = DomainRoutingISM"
        echo "   → DomainRoutingISM.module(1325) = ISM do Terra Classic"
    else
        echo ""
        echo "⚠️  Configuração pode estar incorreta"
        echo "   Esperado: $TERRA_ISM_CHECKSUM"
        echo "   Obtido: $FINAL_ISM_FOR_TERRA_CHECKSUM"
    fi
else
    echo ""
    echo "❌ ISM não é DomainRoutingISM (tipo $FINAL_TYPE_DEC)"
fi

echo ""
echo "========================================="

