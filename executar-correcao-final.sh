#!/bin/bash

set -e

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"

echo "========================================="
echo "🔧 CORREÇÃO FINAL DO ISM SEPOLIA"
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

echo "Criando DomainRoutingISM e configurando..."
echo ""

DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"

# Criar DomainRoutingISM
TX_OUTPUT=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
    "deploy(uint32[],address[],address)" \
    "[$TERRA_DOMAIN]" \
    "[$TERRA_ISM]" \
    "$OWNER" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC" 2>&1)

TX_HASH=$(echo "$TX_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)

if [ -z "$TX_HASH" ]; then
    echo "❌ Erro ao criar DomainRoutingISM"
    exit 1
fi

echo "✅ Transação: $TX_HASH"
echo ""

# Aguardar e buscar endereço
sleep 5

# Buscar em um range de blocos recentes
LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 200))

echo "Buscando DomainRoutingISM criado..."
echo ""

# Tentar encontrar verificando contratos que sejam DomainRoutingISM
# e que tenham o módulo configurado para Terra Classic
# Vamos verificar alguns endereços possíveis baseados em padrões

# Na verdade, vamos usar uma abordagem diferente:
# Verificar se o factory retorna o endereço na chamada
# Ou verificar eventos diretamente

# Como última tentativa, vamos verificar se há algum DomainRoutingISM
# que foi criado recentemente e que tenha o owner correto

echo "Verificando eventos do factory..."
LOGS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
    --address "$DOMAIN_ROUTING_ISM_FACTORY" \
    --rpc-url "$RPC" 2>&1)

# Tentar extrair endereços
ADDRESSES=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | sort -u | grep -v "$DOMAIN_ROUTING_ISM_FACTORY" | grep -v "$OWNER")

NEW_ISM=""

for ADDR in $ADDRESSES; do
    TYPE=$(cast call "$ADDR" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
    TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")
    
    if [ "$TYPE_DEC" = "1" ]; then
        # Verificar se tem o owner correto
        ISM_OWNER=$(cast call "$ADDR" "owner()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "")
        if [ "$ISM_OWNER" = "$OWNER" ]; then
            NEW_ISM="$ADDR"
            echo "✅ Encontrado: $ADDR"
            break
        fi
    fi
done

if [ -z "$NEW_ISM" ]; then
    echo "⚠️  Não encontrado automaticamente"
    echo ""
    echo "Verifique no Etherscan:"
    echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    echo "E execute:"
    echo "   export DOMAIN_ROUTING_ISM=\"<endereco>\""
    echo "   export PRIVATE_KEY=\"$PRIVATE_KEY\""
    echo "   ./continuar-correcao-sepolia.sh"
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)

# Verificar e configurar
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Configurando para Terra Classic..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
fi

echo ""
echo "Configurando Warp Route..."
cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$NEW_ISM_CHECKSUM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1

echo ""
echo "✅ Verificação final..."
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

