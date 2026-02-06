#!/bin/bash

# Script baseado na documentação oficial do Hyperlane
# https://docs.hyperlane.xyz/docs/protocol/ISM/standard-ISMs/routing-ISM

set -e

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"

echo "========================================="
echo "🔧 CRIANDO DOMAINROUTINGISM (Oficial)"
echo "========================================="
echo ""
echo "Baseado na documentação:"
echo "https://docs.hyperlane.xyz/docs/protocol/ISM/standard-ISMs/routing-ISM"
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

echo "📍 Configuração:"
echo "   Factory: $DOMAIN_ROUTING_ISM_FACTORY"
echo "   Owner: $OWNER"
echo "   Domain Terra Classic: $TERRA_DOMAIN"
echo "   ISM Terra Classic: $TERRA_ISM"
echo ""

echo "Criando DomainRoutingISM..."
echo ""

# A função deploy retorna o endereço do contrato criado
# Assinatura: deploy(address owner, uint32[] domains, IInterchainSecurityModule[] modules)
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

echo "Aguardando confirmação e buscando endereço..."
sleep 5

# O factory.deploy() retorna o endereço, mas cast send não mostra o retorno
# Precisamos obter via eventos ou Etherscan
echo ""
echo "📝 Para obter o endereço do DomainRoutingISM criado:"
echo "   1. Acesse: https://sepolia.etherscan.io/tx/$TX_HASH"
echo "   2. Procure pelo evento 'ModuleDeployed'"
echo "   3. O endereço está no campo 'module' do evento"
echo ""
echo "Depois execute:"
echo "   ./configurar-com-endereco-final.sh <endereco>"
echo ""

