#!/bin/bash

# Criar DomainRoutingISM diretamente sem factory
# Baseado na documentação: https://docs.hyperlane.xyz/docs/protocol/ISM/standard-ISMs/routing-ISM

set -e

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"

echo "========================================="
echo "🔧 CRIANDO DOMAINROUTINGISM DIRETAMENTE"
echo "========================================="
echo ""

echo "📍 Configuração:"
echo "   Owner: $OWNER"
echo "   Domain Terra Classic: $TERRA_DOMAIN"
echo "   ISM Terra Classic: $TERRA_ISM"
echo ""

echo "Deployando DomainRoutingISM diretamente..."
echo ""

# Deployar o contrato DomainRoutingISM diretamente
# O contrato é upgradeable, então podemos deployar diretamente
CONTRATO_PATH="/home/lunc/hyperlane-monorepo/solidity/contracts/isms/routing/DomainRoutingIsm.sol"

if [ ! -f "$CONTRATO_PATH" ]; then
    echo "❌ Contrato não encontrado em: $CONTRATO_PATH"
    exit 1
fi

echo "Compilando e deployando..."
echo ""

# Deployar usando forge ou cast
cd /home/lunc/hyperlane-monorepo/solidity

# Verificar se forge está disponível
if command -v forge &> /dev/null; then
    echo "Usando forge para deployar..."
    NEW_ISM=$(forge create \
        --rpc-url "$RPC" \
        --private-key "$PRIVATE_KEY" \
        --constructor-args "$OWNER" "[$TERRA_DOMAIN]" "[$TERRA_ISM]" \
        contracts/isms/routing/DomainRoutingIsm.sol:DomainRoutingIsm 2>&1 | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
else
    echo "Forge não encontrado. Tentando compilar primeiro..."
    # Compilar e depois deployar
    forge build --contracts contracts/isms/routing/DomainRoutingIsm.sol 2>&1 || true
    echo "Por favor, use forge ou outro método para deployar o contrato"
    exit 1
fi

if [ -z "$NEW_ISM" ]; then
    echo "❌ Erro ao deployar"
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo ""
echo "✅ DomainRoutingISM criado: $NEW_ISM_CHECKSUM"
echo ""

# Inicializar
echo "Inicializando..."
cast send "$NEW_ISM" \
    "initialize(address,uint32[],address[])" \
    "$OWNER" \
    "[$TERRA_DOMAIN]" \
    "[$TERRA_ISM]" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC" >/dev/null 2>&1

echo "✅ Inicializado!"
echo ""

# Configurar Warp Route
echo "Configurando Warp Route..."
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

