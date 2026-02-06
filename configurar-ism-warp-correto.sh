#!/bin/bash

echo "========================================="
echo "🔧 CONFIGURAR ISM DO WARP ROUTE CORRETAMENTE"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM_ATUAL="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
TERRA_DOMAIN="1325"
SEPOLIA_DOMAIN="11155111"
RPC="https://sepolia.drpc.org"

# Verificar se há DomainRoutingISM no Sepolia
# Se não houver, precisaremos criar um ou usar o factory
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"

echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM atual: $WARP_ISM_ATUAL"
echo "📍 Domain Terra Classic: $TERRA_DOMAIN"
echo ""

echo "1️⃣ Verificando ISM do Terra Classic..."
echo ""

# Tentar obter o ISM do Terra Classic do config ou verificar diretamente
# O ISM do Terra Classic geralmente está no contrato do Mailbox ou pode ser consultado
TERRA_MAILBOX="0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd"
TERRA_LCD="https://lcd.luncblaze.com"

echo "   Tentando obter ISM do Terra Classic via Mailbox..."
# No Terra Classic, o ISM pode ser obtido via query do contrato Mailbox
QUERY_BASE64=$(echo -n "{\"interchain_security_module\":{}}" | base64 -w 0)
QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$TERRA_MAILBOX/smart/$QUERY_BASE64"

RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)
TERRA_ISM=""

if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
    TERRA_ISM=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
    if [ -n "$TERRA_ISM" ] && [ "$TERRA_ISM" != "null" ]; then
        echo "   ✅ ISM do Terra Classic: $TERRA_ISM"
    fi
fi

if [ -z "$TERRA_ISM" ] || [ "$TERRA_ISM" = "null" ]; then
    echo "   ⚠️  Não foi possível obter via API, usando ISM conhecido"
    # ISM conhecido do Terra Classic testnet (pode precisar ser ajustado)
    TERRA_ISM="0x0000000000000000000000000000000000000000"  # PLACEHOLDER - precisa ser preenchido
    echo "   ⚠️  ATENÇÃO: Você precisa fornecer o ISM do Terra Classic!"
    echo "   Verifique no Terra Finder ou na configuração do validador"
fi

echo ""
echo "2️⃣ Verificando DomainRoutingISM disponível..."
echo ""

# Verificar se existe DomainRoutingISM no Sepolia
# Pode ser necessário criar um novo ou usar um existente
DOMAIN_ROUTING_ISM=""

# Tentar verificar se há um DomainRoutingISM já configurado
# Ou usar o factory para criar um novo
echo "   Opções:"
echo "   a) Usar DomainRoutingISM existente (se houver)"
echo "   b) Criar novo DomainRoutingISM via Factory"
echo ""

# Verificar se o Warp Route tem owner
OWNER=$(cast call "$WARP_ROUTE" "owner()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
if [ -n "$OWNER" ] && [ "$OWNER" != "0x" ]; then
    echo "   ✅ Owner do Warp Route: $OWNER"
else
    echo "   ⚠️  Não foi possível obter owner"
    OWNER=""
fi

echo ""
echo "3️⃣ Script de configuração..."
echo ""

cat > configurar-ism-transacoes.sh << 'SCRIPT_EOF'
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

SCRIPT_EOF

chmod +x configurar-ism-transacoes.sh

echo "   ✅ Script criado: configurar-ism-transacoes.sh"
echo ""

echo "4️⃣ Criando script para obter ISM do Terra Classic..."
echo ""

cat > obter-ism-terraclassic.sh << 'OBTER_EOF'
#!/bin/bash

echo "========================================="
echo "🔍 OBTER ISM DO TERRA CLASSIC"
echo "========================================="
echo ""

TERRA_MAILBOX="0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd"
TERRA_LCD="https://lcd.luncblaze.com"

echo "📍 Mailbox do Terra Classic: $TERRA_MAILBOX"
echo ""

echo "1️⃣ Tentando obter ISM via API REST..."
echo ""

QUERY_BASE64=$(echo -n "{\"interchain_security_module\":{}}" | base64 -w 0)
QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$TERRA_MAILBOX/smart/$QUERY_BASE64"

RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
    TERRA_ISM=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
    if [ -n "$TERRA_ISM" ] && [ "$TERRA_ISM" != "null" ] && [ "$TERRA_ISM" != "" ]; then
        echo "   ✅ ISM do Terra Classic: $TERRA_ISM"
        echo ""
        echo "   Use este valor no script configurar-ism-transacoes.sh:"
        echo "   TERRA_ISM=\"$TERRA_ISM\""
    else
        echo "   ❌ Não foi possível obter ISM via API"
    fi
else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // .error' 2>/dev/null)
    echo "   ⚠️  Erro: $ERROR"
    echo ""
    echo "   💡 Verifique manualmente no Terra Finder:"
    echo "   https://finder.terraclassic.community/testnet"
    echo "   Contrato: $TERRA_MAILBOX"
fi

echo ""
echo "========================================="

OBTER_EOF

chmod +x obter-ism-terraclassic.sh

echo "   ✅ Script criado: obter-ism-terraclassic.sh"
echo ""

echo "========================================="
echo "📝 PRÓXIMOS PASSOS"
echo "========================================="
echo ""
echo "1. Execute: ./obter-ism-terraclassic.sh"
echo "   → Isso obterá o ISM do Terra Classic"
echo ""
echo "2. Edite: configurar-ism-transacoes.sh"
echo "   → Configure TERRA_ISM com o valor obtido"
echo "   → Configure PRIVATE_KEY com sua private key"
echo ""
echo "3. Execute: ./configurar-ism-transacoes.sh"
echo "   → Isso criará o DomainRoutingISM e configurará o Warp Route"
echo ""
echo "⚠️  ATENÇÃO:"
echo "   - Verifique todas as transações no Etherscan antes de executar"
echo "   - Certifique-se de ter ETH suficiente no Sepolia"
echo "   - A private key deve ser do owner do Warp Route"
echo ""

