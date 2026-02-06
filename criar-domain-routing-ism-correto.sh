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
echo "🔧 CRIANDO DOMAINROUTINGISM CORRETAMENTE"
echo "========================================="
echo ""

echo "📍 Parâmetros:"
echo "   Factory: $DOMAIN_ROUTING_ISM_FACTORY"
echo "   Owner: $OWNER"
echo "   Domain Terra Classic: $TERRA_DOMAIN"
echo "   ISM Terra Classic: $TERRA_ISM"
echo ""

# Verificar se já está configurado
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

# A assinatura correta é: deploy(address owner, uint32[] domains, address[] modules)
# Onde modules é um array de endereços de ISMs
echo "📝 Assinatura correta: deploy(address, uint32[], address[])"
echo ""

# Criar DomainRoutingISM com os parâmetros corretos
echo "Enviando transação..."
TX_OUTPUT=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
    "deploy(address,uint32[],address[])" \
    "$OWNER" \
    "[$TERRA_DOMAIN]" \
    "[$TERRA_ISM]" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC" 2>&1)

echo "$TX_OUTPUT"

TX_HASH=$(echo "$TX_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)

if [ -z "$TX_HASH" ]; then
    echo "❌ Erro ao criar DomainRoutingISM"
    exit 1
fi

echo ""
echo "✅ Transação enviada: $TX_HASH"
echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
echo ""

echo "Aguardando confirmação..."
sleep 5

echo ""
echo "Buscando endereço do DomainRoutingISM criado..."
echo ""

# Obter o bloco da transação
TX_BLOCK=$(cast tx "$TX_HASH" --rpc-url "$RPC" 2>/dev/null | grep -i "blockNumber" | grep -oE "[0-9]+" | head -1)

if [ -z "$TX_BLOCK" ]; then
    LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    TX_BLOCK=$((LATEST_BLOCK - 5))
fi

FROM_BLOCK=$((TX_BLOCK - 1))
TO_BLOCK=$((TX_BLOCK + 1))

echo "Buscando eventos no bloco $TX_BLOCK..."
echo ""

# Buscar logs do factory
LOGS=$(cast logs --from-block "$FROM_BLOCK" --to-block "$TO_BLOCK" \
    --address "$DOMAIN_ROUTING_ISM_FACTORY" \
    --rpc-url "$RPC" 2>&1)

# Tentar extrair endereços
ADDRESSES=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | sort -u | grep -v "$DOMAIN_ROUTING_ISM_FACTORY" | grep -v "$OWNER")

NEW_ISM=""

for ADDR in $ADDRESSES; do
    if [ -z "$ADDR" ] || [ "$ADDR" = "0x0000000000000000000000000000000000000000" ]; then
        continue
    fi
    
    echo "Verificando: $ADDR"
    
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
    echo "⚠️  Não foi possível obter automaticamente"
    echo ""
    echo "💡 Verifique no Etherscan:"
    echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    echo "   Procure pelo evento 'ModuleDeployed' e copie o endereço"
    echo ""
    echo "   Depois execute:"
    echo "   export DOMAIN_ROUTING_ISM=\"<endereco>\""
    echo "   ./configurar-com-endereco.sh"
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo ""
echo "✅ DomainRoutingISM criado: $NEW_ISM_CHECKSUM"
echo ""

# Verificar se já está configurado para Terra Classic
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "⚠️  Não está configurado para Terra Classic (deveria estar via initialize)"
    echo "   Configurando..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
    echo "   ✅ Configurado!"
else
    ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
    if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo "✅ Já está configurado corretamente para Terra Classic"
    else
        echo "⚠️  Configurado mas aponta para ISM diferente"
        echo "   Atualizando..."
        cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
        echo "   ✅ Atualizado!"
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

