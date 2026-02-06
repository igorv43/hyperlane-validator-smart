#!/bin/bash

# Deployar DomainRoutingIsmFactory no Sepolia e depois criar o DomainRoutingISM

set -e

RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"

echo "========================================="
echo "🔧 DEPLOYAR FACTORY E CRIAR DOMAINROUTINGISM"
echo "========================================="
echo ""

echo "1️⃣ Deployando DomainRoutingIsmFactory..."
echo ""

cd /home/lunc/hyperlane-monorepo/solidity

# Deployar o factory
FACTORY_OUTPUT=$(forge create \
    --rpc-url "$RPC" \
    --private-key "$PRIVATE_KEY" \
    contracts/isms/routing/DomainRoutingIsmFactory.sol:DomainRoutingIsmFactory 2>&1)

FACTORY=$(echo "$FACTORY_OUTPUT" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)

if [ -z "$FACTORY" ]; then
    echo "❌ Erro ao deployar factory"
    echo "$FACTORY_OUTPUT"
    exit 1
fi

FACTORY_CHECKSUM=$(cast --to-checksum-address "$FACTORY" 2>/dev/null)
echo "✅ Factory deployado: $FACTORY_CHECKSUM"
echo ""

echo "2️⃣ Criando DomainRoutingISM usando o factory..."
echo ""

# Criar DomainRoutingISM usando o factory
TX_OUTPUT=$(cast send "$FACTORY" \
    "deploy(address,uint32[],address[])" \
    "$OWNER" \
    "[$TERRA_DOMAIN]" \
    "[$TERRA_ISM]" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC" 2>&1)

TX_HASH=$(echo "$TX_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)

if [ -z "$TX_HASH" ]; then
    echo "❌ Erro ao criar DomainRoutingISM"
    echo "$TX_OUTPUT"
    exit 1
fi

echo "✅ Transação enviada: $TX_HASH"
echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
echo ""

echo "Aguardando confirmação..."
sleep 5

echo ""
echo "3️⃣ Buscando endereço do DomainRoutingISM criado..."
echo ""

# Buscar o endereço via eventos
TX_BLOCK=$(cast tx "$TX_HASH" --rpc-url "$RPC" 2>/dev/null | grep -i "blockNumber" | grep -oE "[0-9]+" | head -1)
FROM_BLOCK=$((TX_BLOCK - 1))
TO_BLOCK=$((TX_BLOCK + 1))

EVENT_SIG="0x9ead1e8752d06495979d851a64b37d5670b1cc60b5901298b3f41eea356c78ef"
LOGS=$(cast logs --from-block "$FROM_BLOCK" --to-block "$TO_BLOCK" \
    --address "$FACTORY" \
    --topic0 "$EVENT_SIG" \
    --rpc-url "$RPC" 2>&1)

NEW_ISM=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | grep -v "$FACTORY" | grep -v "$OWNER" | head -1)

if [ -z "$NEW_ISM" ]; then
    echo "⚠️  Não foi possível obter automaticamente"
    echo "Verifique: https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    read -p "Digite o endereço do DomainRoutingISM: " NEW_ISM
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo "✅ DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

echo "4️⃣ Configurando Warp Route..."
cast send "$WARP_ROUTE" \
    "setInterchainSecurityModule(address)" \
    "$NEW_ISM_CHECKSUM" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC" >/dev/null 2>&1

echo "✅ Warp Route configurado!"
echo ""

echo "Verificação final..."
FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)
FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM: $FINAL_ISM_CHECKSUM (tipo $FINAL_TYPE_DEC)"

if [ "$FINAL_TYPE_DEC" = "1" ]; then
    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    
    echo "ISM Terra Classic: $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
    fi
fi

