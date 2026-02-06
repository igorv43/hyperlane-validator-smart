#!/bin/bash

set -e

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"

echo "========================================="
echo "🔧 CRIANDO E CONFIGURANDO DOMAINROUTINGISM"
echo "========================================="
echo ""

# Verificar se já está correto
CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" = "1" ]; then
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "✅ Já está configurado corretamente!"
            exit 0
        fi
    fi
fi

echo "Criando DomainRoutingISM..."
echo ""

# O factory.deploy() retorna o endereço do contrato criado
# Vamos usar cast send e capturar o retorno
TX_OUTPUT=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
    "deploy(uint32[],address[],address)" \
    "[$TERRA_DOMAIN]" \
    "[$TERRA_ISM]" \
    "$OWNER" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC" 2>&1)

echo "$TX_OUTPUT"

TX_HASH=$(echo "$TX_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)

if [ -z "$TX_HASH" ]; then
    echo "❌ Erro ao criar DomainRoutingISM"
    exit 1
fi

echo ""
echo "✅ Transação: $TX_HASH"
echo ""

# O factory.deploy() retorna o endereço, mas cast send não mostra o retorno
# Vamos tentar obter via trace da transação ou calcular

echo "Obtendo endereço do DomainRoutingISM..."
echo ""

# Aguardar confirmação
sleep 5

# Tentar obter via trace (se disponível)
TRACE=$(cast run "$TX_HASH" --rpc-url "$RPC" 2>&1 | grep -i "return\|address\|deployed" | head -10 || echo "")

# Tentar extrair endereço do trace
NEW_ISM=$(echo "$TRACE" | grep -oE "0x[a-fA-F0-9]{40}" | grep -v "$DOMAIN_ROUTING_ISM_FACTORY" | grep -v "$OWNER" | head -1)

if [ -z "$NEW_ISM" ]; then
    # Tentar via Etherscan API
    API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"
    RESPONSE=$(curl -s "https://api-sepolia.etherscan.io/api?module=proxy&action=eth_getTransactionReceipt&txhash=$TX_HASH&apikey=$API_KEY" 2>/dev/null)
    
    # Tentar extrair do response
    ADDRESSES=$(echo "$RESPONSE" | grep -oE "0x[a-fA-F0-9]{40}" | sort -u | grep -v "$DOMAIN_ROUTING_ISM_FACTORY" | grep -v "$OWNER")
    
    for ADDR in $ADDRESSES; do
        TYPE=$(cast call "$ADDR" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
        TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")
        if [ "$TYPE_DEC" = "1" ]; then
            NEW_ISM="$ADDR"
            break
        fi
    done
fi

if [ -z "$NEW_ISM" ]; then
    echo "⚠️  Não foi possível obter automaticamente"
    echo ""
    echo "Verifique no Etherscan:"
    echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    echo "O endereço estará no evento 'ModuleDeployed'"
    echo ""
    echo "Depois execute:"
    echo "   export DOMAIN_ROUTING_ISM=\"<endereco>\""
    echo "   export PRIVATE_KEY=\"$PRIVATE_KEY\""
    echo "   ./continuar-correcao-sepolia.sh"
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo "✅ DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

# Verificar e configurar
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Configurando para Terra Classic..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
    echo "✅ Configurado!"
fi

echo ""
echo "Configurando Warp Route..."
cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$NEW_ISM_CHECKSUM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
echo "✅ Warp Route configurado!"
echo ""

echo "Verificando configuração final..."
FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)
FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM: $FINAL_ISM_CHECKSUM (tipo $FINAL_TYPE_DEC)"

if [ "$FINAL_TYPE_DEC" = "1" ]; then
    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
    echo "ISM Terra Classic: $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
    fi
fi

