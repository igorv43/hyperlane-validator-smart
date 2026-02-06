#!/bin/bash

# CONFIGURAÇÕES
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM=""  # PREENCHER COM O ISM DO TERRA CLASSIC
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY=""  # PREENCHER COM SUA PRIVATE KEY

echo "========================================="
echo "🔧 CONFIGURAR ISM DO WARP ROUTE"
echo "========================================="
echo ""

if [ -z "$TERRA_ISM" ] || [ "$TERRA_ISM" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ ERRO: TERRA_ISM não foi configurado!"
    echo "   Execute primeiro: ./obter-ism-terraclassic.sh"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ ERRO: PRIVATE_KEY não foi configurada!"
    echo "   Configure a variável PRIVATE_KEY no script"
    exit 1
fi

echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM do Terra Classic: $TERRA_ISM"
echo "📍 Domain Terra Classic: $TERRA_DOMAIN"
echo ""

# Passo 1: Criar ou obter DomainRoutingISM
echo "1️⃣ Criando/obtendo DomainRoutingISM..."
echo ""

# Verificar se já existe um DomainRoutingISM configurado
# Se não, criar um novo via factory

# ABI do DomainRoutingIsmFactory
# deploy(uint32[] domains, address[] modules, address owner) returns (address)
echo "   Criando DomainRoutingISM via Factory..."
echo ""

DOMAINS_ARRAY="[$TERRA_DOMAIN]"
MODULES_ARRAY="[$TERRA_ISM]"
OWNER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null | tr -d '\n')

if [ -z "$OWNER_ADDR" ]; then
    echo "❌ Erro ao obter endereço da private key"
    exit 1
fi

echo "   Domains: $DOMAINS_ARRAY"
echo "   Modules: $MODULES_ARRAY"
echo "   Owner: $OWNER_ADDR"
echo ""

# Calcular o endereço do DomainRoutingISM que será criado
# Ou usar um existente se já houver um configurado

# Por enquanto, vamos assumir que precisamos criar um novo
# O factory retorna o endereço do contrato criado

echo "   📝 Transação para criar DomainRoutingISM:"
echo "   cast send $DOMAIN_ROUTING_ISM_FACTORY \\"
echo "     \"deploy(uint32[],address[],address)\" \\"
echo "     \"[$TERRA_DOMAIN]\" \\"
echo "     \"[$TERRA_ISM]\" \\"
echo "     \"$OWNER_ADDR\" \\"
echo "     --private-key \$PRIVATE_KEY \\"
echo "     --rpc-url \$RPC"
echo ""

# Passo 2: Configurar o Warp Route para usar o DomainRoutingISM
echo "2️⃣ Configurando Warp Route para usar DomainRoutingISM..."
echo ""

echo "   📝 Transação para configurar ISM no Warp Route:"
echo "   cast send $WARP_ROUTE \\"
echo "     \"setInterchainSecurityModule(address)\" \\"
echo "     \"<DOMAIN_ROUTING_ISM_ADDRESS>\" \\"
echo "     --private-key \$PRIVATE_KEY \\"
echo "     --rpc-url \$RPC"
echo ""

echo "========================================="
echo "⚠️  IMPORTANTE"
echo "========================================="
echo ""
echo "1. Preencha TERRA_ISM com o ISM do Terra Classic"
echo "2. Preencha PRIVATE_KEY com sua private key"
echo "3. Execute as transações na ordem:"
echo "   a) Criar DomainRoutingISM"
echo "   b) Configurar Warp Route"
echo ""
echo "4. Verifique as transações no Etherscan antes de executar"
echo ""

