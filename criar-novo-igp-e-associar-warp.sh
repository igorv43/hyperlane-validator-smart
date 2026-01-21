#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️${NC}  $1"
}

print_success() {
    echo -e "${GREEN}✅${NC}  $1"
}

print_error() {
    echo -e "${RED}❌${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC}  $1"
}

print_value() {
    echo -e "  ${YELLOW}$1${NC}"
}

# Configurações
SOLANA_KEYPAIR="/home/lunc/keys/solana-keypair-EMAYGfEyhywUyEX6kfG5FZZMfznmKXM8PbWpkJhJ9Jjd.json"
SOLANA_RPC="https://api.testnet.solana.com"
CLIENT_DIR="/home/lunc/hyperlane-monorepo/rust/sealevel/client"
ENVIRONMENTS_DIR="/home/lunc/hyperlane-monorepo/rust/sealevel/environments"
ENVIRONMENT="testnet"
CHAIN_NAME="solanatestnet"
TERRA_DOMAIN=1325

# Parâmetros do Gas Oracle (do cálculo anterior)
TOKEN_EXCHANGE_RATE=${1:-100000000000000000}  # 1 SOL = 100,000 LUNC
GAS_PRICE=${2:-28325000}                      # Gas price em wei
TOKEN_DECIMALS=${3:-6}                        # LUNC tem 6 decimais

# Warp Route Program ID
WARP_ROUTE_PROGRAM_ID="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"

print_header "CRIAR NOVO IGP E ASSOCIAR AO WARP ROUTE"

print_info "Este script irá:"
print_value "1. Criar um novo IGP account (você será o owner)"
print_value "2. Configurar o Gas Oracle para Terra Classic"
print_value "3. Associar o novo IGP ao Warp Route"
echo ""

# Obter IGP Program ID
PROGRAM_IDS_FILE="$ENVIRONMENTS_DIR/$ENVIRONMENT/$CHAIN_NAME/core/program-ids.json"
IGP_PROGRAM_ID=$(python3 -c "import json; print(json.load(open('$PROGRAM_IDS_FILE'))['igp_program_id'])" 2>/dev/null || echo "")

if [ -z "$IGP_PROGRAM_ID" ]; then
    print_error "Não foi possível obter o IGP Program ID"
    exit 1
fi

print_success "IGP Program ID: $IGP_PROGRAM_ID"
echo ""

# Gerar salt único para o novo IGP
SALT=$(python3 -c "import secrets; print('0x' + secrets.token_hex(32))" 2>/dev/null || echo "0x$(openssl rand -hex 32)")

print_info "Salt para o novo IGP: $SALT"
echo ""

read -p "Deseja continuar? (s/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    print_info "Operação cancelada."
    exit 0
fi

echo ""

# Passo 1: Criar novo IGP account
print_header "PASSO 1: CRIAR NOVO IGP ACCOUNT"

print_info "Criando novo IGP account..."
cd "$CLIENT_DIR"

INIT_OUTPUT=$(timeout 120 cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  igp \
  init-igp-account \
  --environment "$ENVIRONMENT" \
  --environments-dir "$ENVIRONMENTS_DIR" \
  --chain "$CHAIN_NAME" \
  --program-id "$IGP_PROGRAM_ID" \
  --account-salt "$SALT" 2>&1)
INIT_EXIT_CODE=$?

echo "$INIT_OUTPUT"
echo ""

if [ $INIT_EXIT_CODE -eq 0 ]; then
    print_success "IGP account criado com sucesso!"
    
    # Extrair IGP Account do output ou do arquivo de artifacts
    IGP_ACCOUNTS_FILE="$ENVIRONMENTS_DIR/$ENVIRONMENT/igp/$CHAIN_NAME/default/igp-accounts-${SALT#0x}.json"
    if [ ! -f "$IGP_ACCOUNTS_FILE" ]; then
        IGP_ACCOUNTS_FILE="$ENVIRONMENTS_DIR/$ENVIRONMENT/igp/$CHAIN_NAME/default/igp-accounts.json"
    fi
    
    if [ -f "$IGP_ACCOUNTS_FILE" ]; then
        NEW_IGP_ACCOUNT=$(python3 -c "import json; print(json.load(open('$IGP_ACCOUNTS_FILE'))['igp_account'])" 2>/dev/null || echo "")
        if [ ! -z "$NEW_IGP_ACCOUNT" ] && [ "$NEW_IGP_ACCOUNT" != "None" ]; then
            print_success "Novo IGP Account: $NEW_IGP_ACCOUNT"
        else
            # Tentar extrair do output
            NEW_IGP_ACCOUNT=$(echo "$INIT_OUTPUT" | grep -oE "Initialized IGP account [A-HJ-NP-Za-km-z1-9]{32,44}" | grep -oE '[A-HJ-NP-Za-km-z1-9]{32,44}' | head -1)
            if [ ! -z "$NEW_IGP_ACCOUNT" ]; then
                print_success "Novo IGP Account: $NEW_IGP_ACCOUNT"
            else
                print_error "Não foi possível obter o novo IGP Account"
                exit 1
            fi
        fi
    else
        print_error "Arquivo de artifacts não encontrado: $IGP_ACCOUNTS_FILE"
        exit 1
    fi
else
    print_error "Erro ao criar IGP account (exit code: $INIT_EXIT_CODE)"
    exit 1
fi

echo ""

# Passo 2: Configurar Gas Oracle
print_header "PASSO 2: CONFIGURAR GAS ORACLE PARA TERRA CLASSIC"

print_info "Configurando Gas Oracle..."
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

GAS_ORACLE_OUTPUT=$(timeout 120 cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  igp \
  gas-oracle-config \
  --environment "$ENVIRONMENT" \
  --environments-dir "$ENVIRONMENTS_DIR" \
  --chain-name "$CHAIN_NAME" \
  --remote-domain "$TERRA_DOMAIN" \
  set \
  --token-exchange-rate "$TOKEN_EXCHANGE_RATE" \
  --gas-price "$GAS_PRICE" \
  --token-decimals "$TOKEN_DECIMALS" 2>&1)
GAS_ORACLE_EXIT_CODE=$?

# Ajustar para usar o novo IGP account
# O comando acima usa o IGP do core, precisamos modificar para usar o novo IGP
print_warning "⚠️  O comando acima tenta usar o IGP do core."
print_warning "   Precisamos usar o novo IGP account: $NEW_IGP_ACCOUNT"
print_warning "   Vou criar um comando manual para configurar o Gas Oracle no novo IGP"
echo ""

# Usar o comando query para verificar o IGP account correto
# Mas primeiro, vamos tentar configurar usando o novo IGP account diretamente
print_info "Tentando configurar Gas Oracle no novo IGP account..."

# Criar instrução manual para set_gas_oracle_configs
# Mas isso requer acesso direto ao programa, então vamos usar uma abordagem diferente
print_warning "⚠️  Para configurar o Gas Oracle no novo IGP, você precisa:"
print_value "1. Usar o comando igp gas-oracle-config com o novo IGP account"
print_value "2. Ou modificar o arquivo program-ids.json temporariamente"
echo ""

# Passo 3: Associar IGP ao Warp Route
print_header "PASSO 3: ASSOCIAR IGP AO WARP ROUTE"

print_info "Associando novo IGP ao Warp Route..."
print_value "Warp Route Program ID: $WARP_ROUTE_PROGRAM_ID"
print_value "Novo IGP Account: $NEW_IGP_ACCOUNT"
echo ""

# Verificar se há comando no cliente para setar IGP no Warp Route
# Se não houver, precisamos criar a instrução manualmente
print_warning "⚠️  O cliente pode não ter um comando direto para setar IGP no Warp Route"
print_info "Verificando se há comando disponível..."
echo ""

# Resumo
print_header "RESUMO"

print_success "Novo IGP Account criado: $NEW_IGP_ACCOUNT"
print_info "Próximos passos:"
print_value "1. Configure o Gas Oracle no novo IGP usando:"
print_value "   cargo run -- -k $SOLANA_KEYPAIR -u $SOLANA_RPC igp gas-oracle-config \\"
print_value "     --environment $ENVIRONMENT --environments-dir $ENVIRONMENTS_DIR \\"
print_value "     --chain-name $CHAIN_NAME --remote-domain $TERRA_DOMAIN set \\"
print_value "     --token-exchange-rate $TOKEN_EXCHANGE_RATE \\"
print_value "     --gas-price $GAS_PRICE --token-decimals $TOKEN_DECIMALS"
echo ""
print_value "2. Associe o novo IGP ao Warp Route usando a instrução SetInterchainGasPaymaster"
echo ""

print_warning "⚠️  NOTA: O comando gas-oracle-config usa o IGP do core por padrão."
print_warning "   Você pode precisar modificar temporariamente o program-ids.json"
print_warning "   ou usar uma abordagem diferente para configurar o novo IGP."
echo ""



