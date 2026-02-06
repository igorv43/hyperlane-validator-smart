#!/bin/bash

set -e

RPC="https://sepolia.drpc.org"
FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"

echo "========================================="
echo "🔍 BUSCANDO E CONFIGURANDO DOMAINROUTINGISM"
echo "========================================="
echo ""

echo "Buscando DomainRoutingISMs criados recentemente..."
echo ""

# Buscar em um range maior de blocos
LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 1000))

echo "Buscando de $FROM_BLOCK até $LATEST_BLOCK..."
echo ""

# Buscar todos os logs do factory
LOGS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
    --address "$FACTORY" \
    --rpc-url "$RPC" 2>&1)

# Extrair todos os endereços únicos
ALL_ADDRESSES=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | sort -u | grep -v "$FACTORY" | grep -v "$OWNER")

NEW_ISM=""
COUNT=0

echo "Verificando contratos encontrados..."
echo ""

for ADDR in $ALL_ADDRESSES; do
    if [ -z "$ADDR" ] || [ "$ADDR" = "0x0000000000000000000000000000000000000000" ]; then
        continue
    fi
    
    COUNT=$((COUNT + 1))
    if [ $COUNT -gt 20 ]; then
        break
    fi
    
    # Verificar se tem código (é um contrato)
    CODE=$(cast code "$ADDR" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    if [ -z "$CODE" ] || [ "$CODE" = "0x" ]; then
        continue
    fi
    
    # Verificar se é DomainRoutingISM
    TYPE=$(cast call "$ADDR" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
    TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")
    
    if [ "$TYPE_DEC" = "1" ]; then
        # Verificar owner
        ISM_OWNER=$(cast call "$ADDR" "owner()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "")
        if [ "$ISM_OWNER" = "$OWNER" ]; then
            echo "   ✅ Encontrado DomainRoutingISM: $ADDR"
            NEW_ISM="$ADDR"
            break
        fi
    fi
done

if [ -z "$NEW_ISM" ]; then
    echo ""
    echo "⚠️  Não foi possível encontrar automaticamente"
    echo ""
    echo "💡 Verifique no Etherscan:"
    echo "   https://sepolia.etherscan.io/tx/0x5b98eaab735fb039790f6007528cf3a205b95e4adb49f4d018ce1eb7305e6891"
    echo ""
    echo "   Procure pelo evento 'ModuleDeployed' e copie o endereço"
    echo ""
    read -p "Digite o endereço do DomainRoutingISM: " NEW_ISM
    
    if [ -z "$NEW_ISM" ]; then
        echo "❌ Endereço não fornecido"
        exit 1
    fi
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo ""
echo "✅ Usando DomainRoutingISM: $NEW_ISM_CHECKSUM"
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

