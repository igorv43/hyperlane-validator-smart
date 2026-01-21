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

# IGP Program ID (fixo)
IGP_PROGRAM_ID="5p7Hii6CJL4xGBYYTGEQmH9LnUSZteFJUu9AVLDExZX2"

# Warp Route Program ID
WARP_ROUTE_PROGRAM_ID="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"

# Parâmetros do Gas Oracle (seguindo lógica do Terra Classic IGP)
# Terra Classic: exchange_rate=40000000000000, gas_price=1, custo 200k gas=800 LUNC
# Calculado: token_exchange_rate=400000000000000000, gas_price=1, token_decimals=6
# Resultado: 3M gas = 0.12 SOL (12,000 LUNC)
TOKEN_EXCHANGE_RATE=${1:-400000000000000000}  # Seguindo lógica do Terra Classic
GAS_PRICE=${2:-1}                              # Mesmo do Terra Classic
TOKEN_DECIMALS=${3:-6}                         # LUNC tem 6 decimais

print_header "CRIAR IGP E ASSOCIAR AO WARP ROUTE - SCRIPT COMPLETO"

print_info "Este script irá:"
print_value "1. Criar um novo IGP account (você será o owner)"
print_value "2. Configurar o Gas Oracle para Terra Classic (Domain $TERRA_DOMAIN)"
print_value "3. Associar o novo IGP ao Warp Route"
echo ""

print_info "Configurações:"
print_value "Warp Route Program ID: $WARP_ROUTE_PROGRAM_ID"
print_value "IGP Program ID: $IGP_PROGRAM_ID"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

read -p "Deseja continuar? (s/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    print_info "Operação cancelada."
    exit 0
fi

echo ""

# ============================================================================
# PASSO 1: Criar novo IGP account
# ============================================================================
print_header "PASSO 1: CRIAR NOVO IGP ACCOUNT"

# Gerar salt único para o novo IGP
SALT=$(python3 -c "import secrets; print('0x' + secrets.token_hex(32))" 2>/dev/null || echo "0x$(openssl rand -hex 32)")

print_info "Salt para o novo IGP: $SALT"
print_info "Criando novo IGP account..."
echo ""

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

if [ $INIT_EXIT_CODE -ne 0 ]; then
    print_error "Erro ao criar IGP account (exit code: $INIT_EXIT_CODE)"
    exit 1
fi

# Extrair IGP Account do arquivo de artifacts
# O arquivo pode ter o nome com ou sem o prefixo 0x no salt
IGP_ACCOUNTS_FILE_WITH_0X="$ENVIRONMENTS_DIR/$ENVIRONMENT/igp/$CHAIN_NAME/default/igp-accounts-${SALT}.json"
IGP_ACCOUNTS_FILE_WITHOUT_0X="$ENVIRONMENTS_DIR/$ENVIRONMENT/igp/$CHAIN_NAME/default/igp-accounts-${SALT#0x}.json"
IGP_ACCOUNTS_FILE_DEFAULT="$ENVIRONMENTS_DIR/$ENVIRONMENT/igp/$CHAIN_NAME/default/igp-accounts.json"

NEW_IGP_ACCOUNT=""

# Tentar ler do arquivo com 0x
if [ -f "$IGP_ACCOUNTS_FILE_WITH_0X" ]; then
    NEW_IGP_ACCOUNT=$(python3 << PYEOF
import json
try:
    with open('$IGP_ACCOUNTS_FILE_WITH_0X', 'r') as f:
        data = json.load(f)
        igp_account = data.get('igp_account', '')
        if igp_account and igp_account != '':
            print(igp_account)
except:
    pass
PYEOF
)
fi

# Tentar ler do arquivo sem 0x
if [ -z "$NEW_IGP_ACCOUNT" ] && [ -f "$IGP_ACCOUNTS_FILE_WITHOUT_0X" ]; then
    NEW_IGP_ACCOUNT=$(python3 << PYEOF
import json
try:
    with open('$IGP_ACCOUNTS_FILE_WITHOUT_0X', 'r') as f:
        data = json.load(f)
        igp_account = data.get('igp_account', '')
        if igp_account and igp_account != '':
            print(igp_account)
except:
    pass
PYEOF
)
fi

# Tentar ler do arquivo default
if [ -z "$NEW_IGP_ACCOUNT" ] && [ -f "$IGP_ACCOUNTS_FILE_DEFAULT" ]; then
    NEW_IGP_ACCOUNT=$(python3 << PYEOF
import json
try:
    with open('$IGP_ACCOUNTS_FILE_DEFAULT', 'r') as f:
        data = json.load(f)
        igp_account = data.get('igp_account', '')
        if igp_account and igp_account != '':
            print(igp_account)
except:
    pass
PYEOF
)
fi

# Tentar extrair do output como último recurso
if [ -z "$NEW_IGP_ACCOUNT" ]; then
    NEW_IGP_ACCOUNT=$(echo "$INIT_OUTPUT" | grep -oE "Initialized IGP account [A-HJ-NP-Za-km-z1-9]{32,44}" | grep -oE '[A-HJ-NP-Za-km-z1-9]{32,44}' | head -1)
fi

# Tentar extrair do output de outra forma
if [ -z "$NEW_IGP_ACCOUNT" ]; then
    NEW_IGP_ACCOUNT=$(echo "$INIT_OUTPUT" | grep -oE "igp_account.*[A-HJ-NP-Za-km-z1-9]{32,44}" | grep -oE '[A-HJ-NP-Za-km-z1-9]{32,44}' | head -1)
fi

if [ -z "$NEW_IGP_ACCOUNT" ]; then
    print_error "Não foi possível obter o novo IGP Account"
    print_info "Arquivos verificados:"
    print_value "$IGP_ACCOUNTS_FILE_WITH_0X"
    print_value "$IGP_ACCOUNTS_FILE_WITHOUT_0X"
    print_value "$IGP_ACCOUNTS_FILE_DEFAULT"
    print_info "Verifique o output acima para mais detalhes"
    exit 1
fi

print_success "IGP account criado com sucesso!"
print_success "Novo IGP Account: $NEW_IGP_ACCOUNT"
echo ""

# ============================================================================
# PASSO 2: Configurar Gas Oracle no novo IGP
# ============================================================================
print_header "PASSO 2: CONFIGURAR GAS ORACLE PARA TERRA CLASSIC"

print_info "Para configurar o Gas Oracle no novo IGP, precisamos modificar temporariamente o program-ids.json"
print_info "Fazendo backup do arquivo original..."
echo ""

PROGRAM_IDS_FILE="$ENVIRONMENTS_DIR/$ENVIRONMENT/$CHAIN_NAME/core/program-ids.json"
PROGRAM_IDS_BACKUP="${PROGRAM_IDS_FILE}.backup.$(date +%s)"

if [ ! -f "$PROGRAM_IDS_FILE" ]; then
    print_error "Arquivo program-ids.json não encontrado: $PROGRAM_IDS_FILE"
    exit 1
fi

# Fazer backup
cp "$PROGRAM_IDS_FILE" "$PROGRAM_IDS_BACKUP"
print_success "Backup criado: $PROGRAM_IDS_BACKUP"

# Atualizar IGP account no arquivo
print_info "Atualizando program-ids.json com o novo IGP account..."
python3 << PYEOF
import json

file_path = "$PROGRAM_IDS_FILE"
new_igp_account = "$NEW_IGP_ACCOUNT"

with open(file_path, 'r') as f:
    data = json.load(f)

old_igp_account = data.get('igp_account', 'N/A')
data['igp_account'] = new_igp_account

with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)

print(f"✅ IGP account atualizado:")
print(f"   Antigo: {old_igp_account}")
print(f"   Novo: {new_igp_account}")
PYEOF

echo ""

# Configurar Gas Oracle
print_info "Configurando Gas Oracle para Terra Classic (Domain $TERRA_DOMAIN)..."
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

echo "$GAS_ORACLE_OUTPUT"
echo ""

# Restaurar arquivo original
print_info "Restaurando program-ids.json original..."
cp "$PROGRAM_IDS_BACKUP" "$PROGRAM_IDS_FILE"
print_success "Arquivo restaurado"

if [ $GAS_ORACLE_EXIT_CODE -ne 0 ]; then
    print_error "Erro ao configurar Gas Oracle (exit code: $GAS_ORACLE_EXIT_CODE)"
    print_warning "O IGP account foi criado, mas o Gas Oracle não foi configurado"
    print_info "Você pode tentar configurar manualmente depois"
    echo ""
else
    print_success "Gas Oracle configurado com sucesso!"
    echo ""
fi

# ============================================================================
# PASSO 3: Associar IGP ao Warp Route
# ============================================================================
print_header "PASSO 3: ASSOCIAR IGP AO WARP ROUTE"

print_info "Associando novo IGP ao Warp Route..."
print_value "Warp Route Program ID: $WARP_ROUTE_PROGRAM_ID"
print_value "IGP Program ID: $IGP_PROGRAM_ID"
print_value "Novo IGP Account: $NEW_IGP_ACCOUNT"
echo ""

# Garantir que estamos no diretório correto
cd "$CLIENT_DIR"

SET_IGP_OUTPUT=$(timeout 120 cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  token \
  igp \
  --program-id "$WARP_ROUTE_PROGRAM_ID" \
  set \
  "$IGP_PROGRAM_ID" \
  igp \
  "$NEW_IGP_ACCOUNT" 2>&1)
SET_IGP_EXIT_CODE=$?

echo "$SET_IGP_OUTPUT"
echo ""

if [ $SET_IGP_EXIT_CODE -ne 0 ]; then
    print_error "Erro ao associar IGP ao Warp Route (exit code: $SET_IGP_EXIT_CODE)"
    print_warning "O IGP foi criado e configurado, mas não foi associado ao Warp Route"
    print_info "Você pode tentar associar manualmente depois usando:"
    echo ""
    print_value "cargo run -- -k $SOLANA_KEYPAIR -u $SOLANA_RPC token igp \\"
    print_value "  --program-id $WARP_ROUTE_PROGRAM_ID \\"
    print_value "  set $IGP_PROGRAM_ID igp $NEW_IGP_ACCOUNT"
    echo ""
    exit 1
fi

print_success "IGP associado ao Warp Route com sucesso!"
echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================
print_header "✅ PROCESSO CONCLUÍDO COM SUCESSO!"

print_success "Novo IGP Account: $NEW_IGP_ACCOUNT"
print_success "Gas Oracle configurado para Terra Classic (Domain $TERRA_DOMAIN)"
print_success "IGP associado ao Warp Route: $WARP_ROUTE_PROGRAM_ID"
echo ""

print_info "Configurações do Gas Oracle:"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

print_info "Próximos passos:"
print_value "1. Teste uma transferência Solana -> Terra Classic"
print_value "2. Verifique se o gas está sendo pago corretamente"
print_value "3. Ajuste os valores do Gas Oracle se necessário"
echo ""

print_success "🎉 Tudo pronto! O Warp Route agora está usando o novo IGP!"

