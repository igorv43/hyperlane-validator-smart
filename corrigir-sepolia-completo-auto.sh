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
echo "🔧 CORRIGINDO ISM DO WARP ROUTE SEPOLIA"
echo "========================================="
echo ""

TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM Terra Classic: $TERRA_ISM_CHECKSUM"
echo "📍 Domain Terra Classic: $TERRA_DOMAIN"
echo ""

echo "1️⃣ Verificando ISM atual..."
CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
CURRENT_ISM_CHECKSUM=$(cast --to-checksum-address "$CURRENT_ISM" 2>/dev/null)
MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   ISM atual: $CURRENT_ISM_CHECKSUM (tipo $TYPE_DEC)"
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "   ✅ Já é DomainRoutingISM"
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "   ✅ Já está configurado corretamente!"
            exit 0
        fi
    fi
    echo "   Configurando para Terra Classic..."
    cast send "$CURRENT_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
    echo "   ✅ Configurado!"
    exit 0
fi

echo "2️⃣ Criando novo DomainRoutingISM..."
echo ""

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
echo "   ✅ Transação enviada: $TX_HASH"
echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
echo ""

echo "3️⃣ Aguardando confirmação e buscando endereço..."
sleep 5

# Tentar obter o endereço do evento
# O evento ModuleDeployed tem o endereço do contrato
LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TX_BLOCK=$(cast tx "$TX_HASH" --rpc-url "$RPC" 2>/dev/null | grep -i "blockNumber" | grep -oE "[0-9]+" | head -1)

if [ -z "$TX_BLOCK" ]; then
    TX_BLOCK=$((LATEST_BLOCK - 5))
fi

echo "   Buscando evento ModuleDeployed no bloco $TX_BLOCK..."
echo ""

# Buscar logs do factory
LOGS=$(cast logs --from-block "$TX_BLOCK" --to-block "$LATEST_BLOCK" \
    --address "$DOMAIN_ROUTING_ISM_FACTORY" \
    --rpc-url "$RPC" 2>&1)

# Tentar extrair endereço dos logs
NEW_ISM=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | grep -v "$DOMAIN_ROUTING_ISM_FACTORY" | grep -v "$OWNER" | head -1)

if [ -z "$NEW_ISM" ]; then
    echo "   ⚠️  Não foi possível obter endereço automaticamente"
    echo "   Verifique no Etherscan e informe o endereço:"
    echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    echo "   O endereço estará no evento 'ModuleDeployed'"
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo "   ✅ DomainRoutingISM encontrado: $NEW_ISM_CHECKSUM"
echo ""

echo "4️⃣ Verificando DomainRoutingISM..."
MODULE_TYPE=$(cast call "$NEW_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" != "1" ]; then
    echo "   ⚠️  Não é DomainRoutingISM (tipo: $TYPE_DEC)"
    exit 1
fi

echo "   ✅ É DomainRoutingISM"

ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)

if [ "$ISM_FOR_TERRA_CHECKSUM" != "$TERRA_ISM_CHECKSUM" ]; then
    echo "   ⚠️  Não está configurado corretamente para Terra Classic"
    echo "   Configurando..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
    echo "   ✅ Configurado!"
fi

echo ""
echo "5️⃣ Configurando Warp Route..."
cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$NEW_ISM_CHECKSUM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
echo "   ✅ Warp Route configurado!"
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
    
    echo "ISM para Terra Classic (1325): $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
        echo "   O Warp Route agora está configurado como no Solana"
    fi
fi

echo ""
echo "========================================="

