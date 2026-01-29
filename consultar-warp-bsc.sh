#!/bin/bash

echo "🔍 CONSULTANDO WARP CONTRACT BSC"
echo "=================================="
echo ""

# Configurações
WARP_ADDRESS="0x2144Be4477202ba2d50c9A8be3181241878cf7D8"
RPC_URL="https://bsc-testnet.publicnode.com"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}📍 Warp Address: ${WARP_ADDRESS}${NC}"
echo -e "${BLUE}🌐 RPC: ${RPC_URL}${NC}"
echo ""
echo "=================================="
echo ""

# Verificar se cast está instalado
if ! command -v cast &> /dev/null; then
    echo "⚠️  'cast' não encontrado. Tentando usar curl direto..."
    USE_CURL=true
else
    echo "✅ Usando 'cast' (Foundry)"
    USE_CURL=false
fi

echo ""

# Função para fazer chamada RPC
call_rpc() {
    local method=$1
    local params=$2
    
    curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" \
        | jq -r '.result'
}

# Função para converter hex para endereço
hex_to_address() {
    local hex=$1
    # Remove 0x e pega os últimos 40 caracteres (20 bytes)
    echo "0x${hex: -40}"
}

echo -e "${YELLOW}🔍 BUSCANDO INFORMAÇÕES DO WARP...${NC}"
echo ""

# 1. ISM do warp - interchainSecurityModule()
echo "1️⃣  Consultando ISM (Interchain Security Module)..."
if [ "$USE_CURL" = true ]; then
    # Signature: interchainSecurityModule() = 0x8b2f991e
    ISM=$(call_rpc "eth_call" "[{\"to\":\"$WARP_ADDRESS\",\"data\":\"0x8b2f991e\"},\"latest\"]")
    ISM=$(hex_to_address "$ISM")
else
    ISM=$(cast call "$WARP_ADDRESS" "interchainSecurityModule()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
fi

if [ -n "$ISM" ] && [ "$ISM" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}   ✅ ISM: ${ISM}${NC}"
else
    echo "   ⚠️  ISM não encontrado ou não configurado"
    ISM="NOT_SET"
fi
echo ""

# 2. Hook do warp (pode ter o IGP)
echo "2️⃣  Consultando Hook (pode conter IGP)..."
if [ "$USE_CURL" = true ]; then
    # Signature: hook() = 0xd8635330
    HOOK=$(call_rpc "eth_call" "[{\"to\":\"$WARP_ADDRESS\",\"data\":\"0xd8635330\"},\"latest\"]")
    HOOK=$(hex_to_address "$HOOK")
else
    HOOK=$(cast call "$WARP_ADDRESS" "hook()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
fi

if [ -n "$HOOK" ] && [ "$HOOK" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}   ✅ Hook: ${HOOK}${NC}"
else
    echo "   ⚠️  Hook não encontrado"
    HOOK="NOT_SET"
fi
echo ""

# 3. Mailbox
echo "3️⃣  Consultando Mailbox..."
if [ "$USE_CURL" = true ]; then
    # Signature: mailbox() = 0xd5438eae
    MAILBOX=$(call_rpc "eth_call" "[{\"to\":\"$WARP_ADDRESS\",\"data\":\"0xd5438eae\"},\"latest\"]")
    MAILBOX=$(hex_to_address "$MAILBOX")
else
    MAILBOX=$(cast call "$WARP_ADDRESS" "mailbox()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
fi

if [ -n "$MAILBOX" ] && [ "$MAILBOX" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}   ✅ Mailbox: ${MAILBOX}${NC}"
else
    echo "   ⚠️  Mailbox não encontrado"
    MAILBOX="0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D"
    echo -e "   ℹ️  Usando mailbox padrão: ${MAILBOX}"
fi
echo ""

# 4. Token subjacente (se for HypERC20)
echo "4️⃣  Consultando token subjacente..."
if [ "$USE_CURL" = true ]; then
    # Signature: wrappedToken() = 0x99a88ec4
    TOKEN=$(call_rpc "eth_call" "[{\"to\":\"$WARP_ADDRESS\",\"data\":\"0x99a88ec4\"},\"latest\"]")
    TOKEN=$(hex_to_address "$TOKEN")
else
    TOKEN=$(cast call "$WARP_ADDRESS" "wrappedToken()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
fi

if [ -n "$TOKEN" ] && [ "$TOKEN" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}   ✅ Token: ${TOKEN}${NC}"
else
    echo "   ℹ️  Pode ser um HypNative (não tem token subjacente)"
    TOKEN="NATIVE"
fi
echo ""

# 5. Se tiver Hook, consultar o IGP do Hook
if [ "$HOOK" != "NOT_SET" ] && [ "$HOOK" != "0x0000000000000000000000000000000000000000" ]; then
    echo "5️⃣  Consultando IGP do Hook..."
    
    # Tentar ler como ProtocolFeeHook ou InterchainGasPaymaster
    if [ "$USE_CURL" = true ]; then
        # Signature: interchainGasPaymaster() = 0x63012de5
        IGP_FROM_HOOK=$(call_rpc "eth_call" "[{\"to\":\"$HOOK\",\"data\":\"0x63012de5\"},\"latest\"]")
        IGP_FROM_HOOK=$(hex_to_address "$IGP_FROM_HOOK")
    else
        IGP_FROM_HOOK=$(cast call "$HOOK" "interchainGasPaymaster()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    fi
    
    if [ -n "$IGP_FROM_HOOK" ] && [ "$IGP_FROM_HOOK" != "0x0000000000000000000000000000000000000000" ]; then
        echo -e "${GREEN}   ✅ IGP (do Hook): ${IGP_FROM_HOOK}${NC}"
        IGP="$IGP_FROM_HOOK"
    else
        echo "   ℹ️  Hook não expõe IGP ou não é um ProtocolFeeHook"
        IGP="NOT_SET"
    fi
else
    IGP="NOT_SET"
fi
echo ""

# 6. Consultar o mailbox para ver o defaultHook
echo "6️⃣  Consultando defaultHook do Mailbox..."
if [ "$USE_CURL" = true ]; then
    # Signature: defaultHook() = 0xbcb2ffa5
    DEFAULT_HOOK=$(call_rpc "eth_call" "[{\"to\":\"$MAILBOX\",\"data\":\"0xbcb2ffa5\"},\"latest\"]")
    DEFAULT_HOOK=$(hex_to_address "$DEFAULT_HOOK")
else
    DEFAULT_HOOK=$(cast call "$MAILBOX" "defaultHook()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
fi

if [ -n "$DEFAULT_HOOK" ] && [ "$DEFAULT_HOOK" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}   ✅ Default Hook: ${DEFAULT_HOOK}${NC}"
else
    echo "   ⚠️  Default Hook não encontrado"
    DEFAULT_HOOK="NOT_SET"
fi
echo ""

# 7. Se não encontramos IGP ainda, usar o padrão
if [ "$IGP" = "NOT_SET" ]; then
    echo "7️⃣  IGP não encontrado no warp/hook. Usando padrão do Hyperlane..."
    IGP="0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949"
    echo -e "   ℹ️  IGP padrão: ${IGP}"
fi
echo ""

echo "=================================="
echo ""
echo -e "${YELLOW}📋 RESUMO DAS CONFIGURAÇÕES:${NC}"
echo ""
echo -e "${GREEN}Warp Address:${NC}     $WARP_ADDRESS"
echo -e "${GREEN}ISM:${NC}              $ISM"
echo -e "${GREEN}IGP:${NC}              $IGP"
echo -e "${GREEN}Mailbox:${NC}          $MAILBOX"
echo -e "${GREEN}Hook:${NC}             $HOOK"
echo -e "${GREEN}Default Hook:${NC}     $DEFAULT_HOOK"
echo -e "${GREEN}Token:${NC}            $TOKEN"
echo ""
echo "=================================="
echo ""

# Salvar em arquivo JSON
OUTPUT_FILE="/home/lunc/hyperlane-validator-smart/warp-bsc-config.json"
cat > "$OUTPUT_FILE" <<EOF
{
  "warp": "$WARP_ADDRESS",
  "chain": "bsctestnet",
  "ism": "$ISM",
  "igp": "$IGP",
  "mailbox": "$MAILBOX",
  "hook": "$HOOK",
  "defaultHook": "$DEFAULT_HOOK",
  "token": "$TOKEN",
  "rpcUrl": "$RPC_URL"
}
EOF

echo -e "${GREEN}✅ Configuração salva em: ${OUTPUT_FILE}${NC}"
echo ""

# Gerar comando para atualizar agent-config
echo "=================================="
echo ""
echo -e "${YELLOW}🔧 PRÓXIMO PASSO:${NC}"
echo ""
echo "Para atualizar o agent-config.docker-testnet.json, execute:"
echo ""
echo -e "${BLUE}# Atualizar IGP${NC}"
echo "jq '.chains.bsctestnet.interchainGasPaymaster = \"$IGP\"' \\"
echo "  hyperlane/agent-config.docker-testnet.json > temp.json && \\"
echo "  mv temp.json hyperlane/agent-config.docker-testnet.json"
echo ""
if [ "$ISM" != "NOT_SET" ]; then
    echo -e "${BLUE}# Atualizar ISM${NC}"
    echo "jq '.chains.bsctestnet.interchainSecurityModule = \"$ISM\"' \\"
    echo "  hyperlane/agent-config.docker-testnet.json > temp.json && \\"
    echo "  mv temp.json hyperlane/agent-config.docker-testnet.json"
    echo ""
fi
echo -e "${BLUE}# Reiniciar relayer${NC}"
echo "docker-compose -f docker-compose-testnet.yml restart relayer"
echo ""
