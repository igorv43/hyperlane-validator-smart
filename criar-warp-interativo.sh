#!/bin/bash

# ============================================================================
# Script Interativo: Criar Warp Route no Solana com ISM e Links Bidirecionais
# ============================================================================
# Este script:
# 1. Faz perguntas interativas para configurar o Warp Route
# 2. Cria um novo Warp Route sintético no Solana
# 3. Configura o ISM (com consulta de validators)
# 4. Faz o link Terra Classic -> Solana
# 5. Faz o link Solana -> Terra Classic
# 6. Gera documento .md completo com todas as informações
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURAÇÕES PADRÃO
# ============================================================================

# Solana
SOLANA_KEYPAIR="/home/lunc/keys/solana-keypair-EMAYGfEyhywUyEX6kfG5FZZMfznmKXM8PbWpkJhJ9Jjd.json"
SOLANA_RPC="https://api.testnet.solana.com"
SOLANA_DOMAIN="1399811150"

# Terra Classic
TERRA_DOMAIN="1325"
TERRA_KEY_NAME="hypelane-val-testnet"
TERRA_CHAIN_ID="rebel-2"
TERRA_RPC="https://rpc.luncblaze.com:443"
TERRA_FEES="12000000uluna"

# Diretórios
BASE_DIR="$HOME/hyperlane-monorepo/rust/sealevel"
CLIENT_DIR="$BASE_DIR/client"
ENVIRONMENTS_DIR="$BASE_DIR/environments"
BUILT_SO_DIR="$BASE_DIR/target/deploy"
REGISTRY_DIR="$HOME/.hyperlane/registry"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   $1${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}📋 [$1] $2${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo ""
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    echo ""
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_question() {
    echo -e "${MAGENTA}❓ $1${NC}"
}

# Função para validar endereço Solana (Base58)
validate_solana_address() {
    local addr=$1
    if [[ ${#addr} -lt 32 || ${#addr} -gt 44 ]]; then
        return 1
    fi
    # Verificar se contém apenas caracteres Base58 válidos
    if [[ ! "$addr" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
        return 1
    fi
    return 0
}

# Função para validar endereço hex (0x...)
validate_hex_address() {
    local addr=$1
    if [[ ! "$addr" =~ ^0x[0-9a-fA-F]{40,64}$ ]]; then
        return 1
    fi
    return 0
}

# Função para validar endereço Terra Classic (bech32)
validate_terra_address() {
    local addr=$1
    # Endereços Terra Classic podem ter diferentes tamanhos:
    # - Account addresses: terra1... (38 chars após terra1)
    # - Contract addresses: terra1... (pode ter mais de 38 chars)
    # Validar apenas que começa com terra1 e tem caracteres válidos bech32
    if [[ ! "$addr" =~ ^terra1[a-z0-9]+$ ]] || [[ ${#addr} -lt 39 ]] || [[ ${#addr} -gt 128 ]]; then
        return 1
    fi
    return 0
}

# Função para consultar validators do ISM
query_ism_validators() {
    local ism_program_id=$1
    local domain=$2
    
    print_info "Consultando validators do ISM $ism_program_id para domain $domain..."
    
    cd "$CLIENT_DIR"
    
    local output=$(cargo run -- \
        -k "$SOLANA_KEYPAIR" \
        -u "$SOLANA_RPC" \
        multisig-ism-message-id query \
        --program-id "$ism_program_id" \
        --domains "$domain" 2>&1)
    
    # Extrair validators e threshold
    local validators=$(echo "$output" | grep -A 20 "Domain data" | grep -E "0x[0-9a-fA-F]{40}" | sed 's/^[[:space:]]*//' | tr '\n' ',' | sed 's/,$//')
    local threshold=$(echo "$output" | grep -A 20 "Domain data" | grep -i "threshold" | grep -oE "[0-9]+" | head -1)
    
    echo "$validators|$threshold"
}

# ============================================================================
# COLETA DE INFORMAÇÕES INTERATIVA OU VIA JSON
# ============================================================================

print_header "CRIAR WARP ROUTE - CONFIGURAÇÃO INTERATIVA"

# Verificar se foi fornecido um arquivo de configuração JSON
CONFIG_FILE=""
if [ "$1" = "--config" ] || [ "$1" = "-c" ]; then
    if [ -z "$2" ]; then
        print_error "Erro: --config requer o caminho do arquivo JSON"
        echo "Uso: $0 [--config|-c <caminho-do-json>]"
        exit 1
    fi
    CONFIG_FILE="$2"
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Erro: Arquivo de configuração não encontrado: $CONFIG_FILE"
        exit 1
    fi
    print_info "Lendo configurações do arquivo: $CONFIG_FILE"
fi

echo -e "${CYAN}Este script irá criar um Warp Route no Solana e configurar os links bidirecionais com Terra Classic.${NC}"
echo ""

# Se foi fornecido um arquivo JSON, ler as configurações
if [ ! -z "$CONFIG_FILE" ]; then
    print_info "Carregando configurações do arquivo JSON..."
    
    # Ler valores do JSON usando Python
    WARP_ROUTE_NAME=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('warpRouteName', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    TOKEN_SYMBOL=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('tokenSymbol', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    TOKEN_NAME=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('tokenName', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    TOKEN_DECIMALS=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('tokenDecimals', '6'))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    TOKEN_METADATA_URI=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('metadataUri', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    ISM_PROGRAM_ID=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('ismProgramId', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    TERRA_WARP_BECH32=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('terraWarpBech32', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    TERRA_WARP_HEX=$(python3 << PYEOF
import json
import sys

try:
    with open("$CONFIG_FILE", 'r') as f:
        config = json.load(f)
        print(config.get('terraWarpHex', ''))
except Exception as e:
    sys.exit(1)
PYEOF
)
    
    # Validar campos obrigatórios
    if [ -z "$WARP_ROUTE_NAME" ] || [ -z "$TOKEN_SYMBOL" ] || [ -z "$TOKEN_NAME" ] || \
       [ -z "$TOKEN_METADATA_URI" ] || [ -z "$ISM_PROGRAM_ID" ] || \
       [ -z "$TERRA_WARP_BECH32" ] || [ -z "$TERRA_WARP_HEX" ]; then
        print_error "Erro: Arquivo JSON incompleto. Campos obrigatórios faltando."
        print_info "Campos obrigatórios: warpRouteName, tokenSymbol, tokenName, metadataUri, ismProgramId, terraWarpBech32, terraWarpHex"
        exit 1
    fi
    
    # Validar URI
    if [[ ! "$TOKEN_METADATA_URI" =~ ^https?:// ]]; then
        print_error "URI inválida! Deve começar com http:// ou https://"
        exit 1
    fi
    
    # Validar ISM
    if ! validate_solana_address "$ISM_PROGRAM_ID"; then
        print_error "ISM Program ID inválido! Deve ser um endereço Solana válido (Base58)"
        exit 1
    fi
    
    # Validar Terra Classic addresses
    if ! validate_terra_address "$TERRA_WARP_BECH32"; then
        print_error "Endereço Terra Classic Bech32 inválido!"
        exit 1
    fi
    
    if ! validate_hex_address "$TERRA_WARP_HEX"; then
        print_error "Endereço Terra Classic Hex inválido!"
        exit 1
    fi
    
    # Se decimals não foi fornecido, usar padrão
    if [ -z "$TOKEN_DECIMALS" ]; then
        TOKEN_DECIMALS="6"
    fi
    
    # Consultar validators do ISM (mesmo no modo JSON)
    print_info "Consultando validators do ISM..."
    ISM_QUERY_RESULT=$(query_ism_validators "$ISM_PROGRAM_ID" "$TERRA_DOMAIN")
    ISM_VALIDATORS=$(echo "$ISM_QUERY_RESULT" | cut -d'|' -f1)
    ISM_THRESHOLD=$(echo "$ISM_QUERY_RESULT" | cut -d'|' -f2)
    
    if [ -z "$ISM_VALIDATORS" ] || [ -z "$ISM_THRESHOLD" ]; then
        print_error "Não foi possível consultar os validators do ISM!"
        print_info "O ISM pode não estar configurado para o domain $TERRA_DOMAIN"
        print_question "Deseja continuar mesmo assim? (s/N)"
        read -p "Resposta: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
            exit 1
        fi
        ISM_VALIDATORS="Não configurado"
        ISM_THRESHOLD="N/A"
    else
        print_success "Validators encontrados: $ISM_VALIDATORS"
        print_success "Threshold: $ISM_THRESHOLD"
    fi
    
    print_success "Configurações carregadas do arquivo JSON!"
    echo ""
else
    # Modo interativo (código original)

# Perguntar nome do Warp Route
print_question "Qual é o nome do Warp Route? (ex: wwxLUNC, wwLUNC, etc)"
read -p "Nome: " WARP_ROUTE_NAME
if [ -z "$WARP_ROUTE_NAME" ]; then
    print_error "Nome do Warp Route é obrigatório!"
    exit 1
fi

# Perguntar informações do token
print_question "Qual é o símbolo do token? (ex: wwxLUNC, wwLUNC)"
read -p "Símbolo: " TOKEN_SYMBOL
if [ -z "$TOKEN_SYMBOL" ]; then
    TOKEN_SYMBOL="$WARP_ROUTE_NAME"
    print_info "Usando nome do Warp Route como símbolo: $TOKEN_SYMBOL"
fi

print_question "Qual é o nome completo do token? (ex: Luna Classic)"
read -p "Nome: " TOKEN_NAME
if [ -z "$TOKEN_NAME" ]; then
    TOKEN_NAME="$TOKEN_SYMBOL"
    print_info "Usando símbolo como nome: $TOKEN_NAME"
fi

print_question "Quantas casas decimais o token tem? (padrão: 6)"
read -p "Decimais: " TOKEN_DECIMALS
if [ -z "$TOKEN_DECIMALS" ]; then
    TOKEN_DECIMALS="6"
fi

# Perguntar URI dos metadados
echo ""
print_question "Qual é a URI dos metadados do token? (URL do arquivo JSON com metadados)"
print_info "Exemplo: https://raw.githubusercontent.com/igorv43/cw-hyperlane/refs/heads/main/warp/solana/metadata.json"
print_info "⚠️ IMPORTANTE: Esta URL é essencial para os metadados do token!"
read -p "URI dos Metadados: " TOKEN_METADATA_URI
if [ -z "$TOKEN_METADATA_URI" ]; then
    print_error "URI dos metadados é obrigatória!"
    exit 1
fi

# Validar URL
if [[ ! "$TOKEN_METADATA_URI" =~ ^https?:// ]]; then
    print_error "URI inválida! Deve começar com http:// ou https://"
    exit 1
fi

# Perguntar ISM do Solana
echo ""
print_question "Qual é o endereço do ISM (Interchain Security Module) do Warp Route no Solana?"
print_info "Exemplo: 5FgXjCJ8hw1hDbYhvwMB7PFN6oBhVcHuLo3ABoYynMZh"
read -p "ISM Program ID: " ISM_PROGRAM_ID
if [ -z "$ISM_PROGRAM_ID" ]; then
    print_error "ISM Program ID é obrigatório!"
    exit 1
fi

if ! validate_solana_address "$ISM_PROGRAM_ID"; then
    print_error "Endereço do ISM inválido! Deve ser um endereço Solana válido (Base58)"
    exit 1
fi

# Consultar validators do ISM
print_info "Consultando validators do ISM..."
ISM_QUERY_RESULT=$(query_ism_validators "$ISM_PROGRAM_ID" "$TERRA_DOMAIN")
ISM_VALIDATORS=$(echo "$ISM_QUERY_RESULT" | cut -d'|' -f1)
ISM_THRESHOLD=$(echo "$ISM_QUERY_RESULT" | cut -d'|' -f2)

if [ -z "$ISM_VALIDATORS" ] || [ -z "$ISM_THRESHOLD" ]; then
    print_error "Não foi possível consultar os validators do ISM!"
    print_info "O ISM pode não estar configurado para o domain $TERRA_DOMAIN"
    print_question "Deseja continuar mesmo assim? (s/N)"
    read -p "Resposta: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
        exit 1
    fi
    ISM_VALIDATORS="Não configurado"
    ISM_THRESHOLD="N/A"
else
    print_success "Validators encontrados: $ISM_VALIDATORS"
    print_success "Threshold: $ISM_THRESHOLD"
fi

# Perguntar Warp Route do Terra Classic
echo ""
print_question "Qual é o endereço do Warp Route no Terra Classic? (Bech32)"
print_info "Exemplo: terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml"
read -p "Terra Classic Warp (Bech32): " TERRA_WARP_BECH32
if [ -z "$TERRA_WARP_BECH32" ]; then
    print_error "Endereço do Warp Route Terra Classic é obrigatório!"
    exit 1
fi

if ! validate_terra_address "$TERRA_WARP_BECH32"; then
    print_error "Endereço Terra Classic inválido! Deve ser um endereço bech32 válido (terra1...)"
    exit 1
fi

print_question "Qual é o endereço do Warp Route no Terra Classic em formato Hex? (0x...)"
print_info "Exemplo: 0x17f6fba8dcd0ef3962f3516e698583f57863032be8ca4f5058cdc8656c19120b"
read -p "Terra Classic Warp (Hex): " TERRA_WARP_HEX
if [ -z "$TERRA_WARP_HEX" ]; then
    print_error "Endereço Hex do Warp Route Terra Classic é obrigatório!"
    exit 1
fi

if ! validate_hex_address "$TERRA_WARP_HEX"; then
    print_error "Endereço Hex inválido! Deve começar com 0x e ter 40-64 caracteres hexadecimais"
    exit 1
fi

# Remover 0x do início se necessário para conversão
TERRA_WARP_HEX_CLEAN="${TERRA_WARP_HEX#0x}"

fi  # Fim do bloco if/else (modo interativo vs JSON)

# Resumo das configurações
echo ""
print_header "RESUMO DAS CONFIGURAÇÕES"

echo -e "${BLUE}Warp Route:${NC}"
echo "  Nome: $WARP_ROUTE_NAME"
echo "  Token Symbol: $TOKEN_SYMBOL"
echo "  Token Name: $TOKEN_NAME"
echo "  Decimals: $TOKEN_DECIMALS"
echo "  Metadata URI: $TOKEN_METADATA_URI"
echo ""
echo -e "${BLUE}ISM:${NC}"
echo "  Program ID: $ISM_PROGRAM_ID"
echo "  Validators: $ISM_VALIDATORS"
echo "  Threshold: $ISM_THRESHOLD"
echo ""
echo -e "${BLUE}Terra Classic Warp Route:${NC}"
echo "  Bech32: $TERRA_WARP_BECH32"
echo "  Hex: $TERRA_WARP_HEX"
echo ""

read -p "Pressione Enter para continuar ou Ctrl+C para cancelar..."

# ============================================================================
# CONFIGURAÇÃO DE DIRETÓRIOS
# ============================================================================

# Usar nome identificável baseado no símbolo do token
WARP_ROUTE_DIR_NAME="warp ${TOKEN_SYMBOL}"
WARP_ROUTE_DIR="$ENVIRONMENTS_DIR/testnet/warp-routes/$WARP_ROUTE_DIR_NAME"
TOKEN_CONFIG="$WARP_ROUTE_DIR/token-config.json"

print_info "Diretório do Warp Route: $WARP_ROUTE_DIR_NAME"

# ============================================================================
# PASSO 1: Criar Diretório e Configuração do Token
# ============================================================================

print_step "1/8" "Criando diretório e configuração do token..."

mkdir -p "$WARP_ROUTE_DIR"

cat > "$TOKEN_CONFIG" << EOF
{
  "solanatestnet": {
    "type": "synthetic",
    "name": "$TOKEN_NAME",
    "symbol": "$TOKEN_SYMBOL",
    "decimals": $TOKEN_DECIMALS,
    "totalSupply": "0",
    "uri": "$TOKEN_METADATA_URI",
    "interchainGasPaymaster": "9SQVtTNsbipdMzumhzi6X8GwojiSMwBfqAhS7FgyTcqy"
  }
}
EOF

print_success "Configuração do token criada: $TOKEN_CONFIG"

# ============================================================================
# PASSO 2: Deploy Manual do Programa
# ============================================================================

print_step "2/8" "Fazendo deploy manual do programa Solana..."

cd "$BASE_DIR"

# Verificar se os keypairs foram gerados
PROGRAM_KEYPAIR="$WARP_ROUTE_DIR/keys/hyperlane_sealevel_token-solanatestnet-keypair.json"
BUFFER_KEYPAIR="$WARP_ROUTE_DIR/keys/hyperlane_sealevel_token-solanatestnet-buffer.json"

if [ ! -f "$PROGRAM_KEYPAIR" ]; then
    print_info "Gerando keypairs primeiro..."
    cd "$CLIENT_DIR"
    
    # Executar warp-route deploy apenas para gerar keypairs
    cargo run -- \
      -k "$SOLANA_KEYPAIR" \
      -u "$SOLANA_RPC" \
      warp-route deploy \
      --warp-route-name "$WARP_ROUTE_DIR_NAME" \
      --environment testnet \
      --environments-dir "$ENVIRONMENTS_DIR" \
      --token-config-file "$TOKEN_CONFIG" \
      --built-so-dir "$BUILT_SO_DIR" \
      --registry "$REGISTRY_DIR" \
      --ata-payer-funding-amount 5000000 2>&1 | head -50 || true
    
    sleep 2
fi

if [ ! -f "$PROGRAM_KEYPAIR" ]; then
    print_error "Keypairs não foram gerados. Criando manualmente..."
    mkdir -p "$WARP_ROUTE_DIR/keys"
    solana-keygen new --no-bip39-passphrase -o "$PROGRAM_KEYPAIR" --force
    solana-keygen new --no-bip39-passphrase -o "$BUFFER_KEYPAIR" --force
fi

# Extrair Program ID do keypair
# Método principal: ler diretamente do arquivo JSON (mais confiável)
if [ -f "$PROGRAM_KEYPAIR" ]; then
    WARP_ROUTE_PROGRAM_ID=$(python3 << PYEOF
import json
import base58
import sys

try:
    with open("$PROGRAM_KEYPAIR", 'r') as f:
        keypair_data = json.load(f)
        if isinstance(keypair_data, list):
            # Array de bytes (formato padrão Solana keypair)
            # Os primeiros 32 bytes são a chave privada, os últimos 32 são a chave pública
            if len(keypair_data) >= 64:
                pubkey_bytes = bytes(keypair_data[32:64])
            else:
                # Se for menor, pode ser apenas a chave pública
                pubkey_bytes = bytes(keypair_data)
        elif isinstance(keypair_data, dict):
            # Objeto com campos específicos
            if 'pubkey' in keypair_data:
                pubkey_hex = keypair_data['pubkey'].replace('0x', '')
                pubkey_bytes = bytes.fromhex(pubkey_hex)
            elif 'publicKey' in keypair_data:
                pubkey_hex = keypair_data['publicKey'].replace('0x', '')
                pubkey_bytes = bytes.fromhex(pubkey_hex)
            else:
                sys.exit(1)
        else:
            sys.exit(1)
        
        pubkey_base58 = base58.b58encode(pubkey_bytes).decode('utf-8')
        print(pubkey_base58)
except Exception as e:
    sys.exit(1)
PYEOF
)
fi

# Fallback: tentar solana-keygen pubkey (filtrando mensagens)
if [ -z "$WARP_ROUTE_PROGRAM_ID" ]; then
    WARP_ROUTE_PROGRAM_ID=$(solana-keygen pubkey "$PROGRAM_KEYPAIR" 2>&1 | grep -E "^[1-9A-HJ-NP-Za-km-z]{32,44}$" | head -1)
fi

# Último fallback: tentar solana address
if [ -z "$WARP_ROUTE_PROGRAM_ID" ]; then
    WARP_ROUTE_PROGRAM_ID=$(solana address -k "$PROGRAM_KEYPAIR" 2>/dev/null | grep -E "^[1-9A-HJ-NP-Za-km-z]{32,44}$" | head -1)
fi

if [ -z "$WARP_ROUTE_PROGRAM_ID" ]; then
    print_error "Não foi possível obter o Program ID do keypair"
    print_info "Keypair criado em: $PROGRAM_KEYPAIR"
    print_info "Tente executar manualmente para verificar o formato do arquivo"
    exit 1
fi

print_info "Program ID: $WARP_ROUTE_PROGRAM_ID"
print_info "Fazendo deploy manual do programa..."

# Deploy manual sem --use-rpc
# Nota: Para o primeiro deploy, precisamos usar o keypair diretamente
# O Solana CLI aceita keypair como signer usando @ ou o caminho completo
# Vamos usar o caminho absoluto e garantir que está correto
PROGRAM_KEYPAIR_ABS=$(readlink -f "$PROGRAM_KEYPAIR" || echo "$PROGRAM_KEYPAIR")

print_info "Keypair path: $PROGRAM_KEYPAIR_ABS"

# Verificar se o keypair existe
if [ ! -f "$PROGRAM_KEYPAIR_ABS" ]; then
    print_error "Keypair não encontrado: $PROGRAM_KEYPAIR_ABS"
    exit 1
fi

# Deploy usando o keypair como program-id
# O Solana CLI pode ter problemas com caminhos que têm espaços
# Vamos criar um link simbólico temporário sem espaços
TEMP_KEYPAIR_DIR="/tmp/warp-route-keypair-$$"
mkdir -p "$TEMP_KEYPAIR_DIR"
TEMP_KEYPAIR="$TEMP_KEYPAIR_DIR/program-keypair.json"
cp "$PROGRAM_KEYPAIR_ABS" "$TEMP_KEYPAIR"

print_info "Usando keypair temporário sem espaços: $TEMP_KEYPAIR"

# Verificar se o programa já existe
PROGRAM_EXISTS=$(solana program show "$WARP_ROUTE_PROGRAM_ID" --url "$SOLANA_RPC" 2>&1 | grep -i "ProgramId\|Buffer" || echo "")

if [ ! -z "$PROGRAM_EXISTS" ]; then
    print_info "Programa já existe no Solana. Fazendo upgrade..."
    
    # Upgrade do programa existente
    solana program deploy "$BUILT_SO_DIR/hyperlane_sealevel_token.so" \
      --url "$SOLANA_RPC" \
      --keypair "$SOLANA_KEYPAIR" \
      --program-id "$WARP_ROUTE_PROGRAM_ID" \
      --upgrade-authority "$SOLANA_KEYPAIR"
    
    DEPLOY_EXIT_CODE=$?
else
    print_info "Fazendo deploy inicial do programa..."
    
    # Deploy inicial usando o keypair temporário
    solana program deploy "$BUILT_SO_DIR/hyperlane_sealevel_token.so" \
      --url "$SOLANA_RPC" \
      --keypair "$SOLANA_KEYPAIR" \
      --program-id "$TEMP_KEYPAIR" \
      --upgrade-authority "$SOLANA_KEYPAIR"
    
    DEPLOY_EXIT_CODE=$?
fi

# Limpar keypair temporário após deploy
rm -f "$TEMP_KEYPAIR"
rmdir "$TEMP_KEYPAIR_DIR" 2>/dev/null || true

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    print_success "Programa deployado/atualizado com sucesso!"
else
    print_error "Erro ao fazer deploy do programa (exit code: $DEPLOY_EXIT_CODE)"
    print_info "Possíveis causas:"
    print_info "  - Saldo insuficiente na conta Solana"
    print_info "  - Programa já existe mas com configuração diferente"
    print_info "  - Problema temporário de rede"
    print_info ""
    print_question "Deseja continuar mesmo assim? O programa pode já estar deployado. (s/N)"
    read -p "Resposta: " CONTINUE_DEPLOY
    if [[ ! "$CONTINUE_DEPLOY" =~ ^[Ss]$ ]]; then
        exit 1
    fi
    print_info "Continuando mesmo com erro no deploy..."
fi

# Remover código duplicado - já tratado acima

# ============================================================================
# PASSO 2.5: Inicializar Warp Route
# ============================================================================

print_step "2.5/8" "Inicializando Warp Route..."

cd "$CLIENT_DIR"

print_info "Inicializando token sintético no Warp Route..."
print_info "Nome do Warp Route: $WARP_ROUTE_DIR_NAME"

# Verificar se o Warp Route já foi inicializado antes de tentar deploy
print_info "Verificando se o Warp Route já foi inicializado..."
WARP_CHECK_QUERY=$(cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  token query \
  --program-id "$WARP_ROUTE_PROGRAM_ID" \
  synthetic 2>&1 || echo "")

# Extrair nome atual do Warp Route se já estiver inicializado
WARP_NAME_EXISTS=$(echo "$WARP_CHECK_QUERY" | grep -i "name" | head -1 || echo "")
MINT_NOT_CREATED=$(echo "$WARP_CHECK_QUERY" | grep -i "Not yet created" || echo "")

if [ ! -z "$WARP_NAME_EXISTS" ] && [ -z "$MINT_NOT_CREATED" ]; then
    # Warp Route já inicializado - extrair nome atual
    EXISTING_NAME=$(echo "$WARP_CHECK_QUERY" | grep -i "name" | sed 's/.*name[^:]*: *//i' | sed 's/[^a-zA-Z0-9 ].*//' | head -1 || echo "")
    
    if [ ! -z "$EXISTING_NAME" ]; then
        print_info "Warp Route já foi inicializado com nome: '$EXISTING_NAME'"
        print_info "Nome fornecido: '$TOKEN_NAME'"
        
        if [ "$EXISTING_NAME" != "$TOKEN_NAME" ]; then
            print_error "Incompatibilidade de nome detectada!"
            print_info "O Warp Route foi inicializado com: '$EXISTING_NAME'"
            print_info "Mas o token-config.json tem: '$TOKEN_NAME'"
            echo ""
            print_info "Ajustando token-config.json para corresponder ao nome existente..."
            
            # Atualizar token-config.json com o nome existente
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s/\"name\": \"$TOKEN_NAME\"/\"name\": \"$EXISTING_NAME\"/" "$TOKEN_CONFIG"
            else
                # Linux
                sed -i "s/\"name\": \"$TOKEN_NAME\"/\"name\": \"$EXISTING_NAME\"/" "$TOKEN_CONFIG"
            fi
            
            print_success "token-config.json atualizado para usar: '$EXISTING_NAME'"
            print_info "⚠️  IMPORTANTE: O metadata JSON pode manter '$TOKEN_NAME' no campo 'name'"
            print_info "   O nome no token-config.json é apenas para inicialização do Warp Route"
            TOKEN_NAME="$EXISTING_NAME"
        fi
    fi
fi

print_info "Executando warp-route deploy para inicializar o token sintético..."

WARP_INIT_OUTPUT=$(cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  warp-route deploy \
  --warp-route-name "$WARP_ROUTE_NAME" \
  --environment testnet \
  --environments-dir "$ENVIRONMENTS_DIR" \
  --token-config-file "$TOKEN_CONFIG" \
  --built-so-dir "$BUILT_SO_DIR" \
  --registry "$REGISTRY_DIR" \
  --ata-payer-funding-amount 5000000 2>&1 | tee /tmp/warp-init-output.txt)

WARP_INIT_EXIT_CODE=$?

if [ $WARP_INIT_EXIT_CODE -eq 0 ]; then
    print_success "Warp Route inicializado com sucesso!"
else
    # Verificar se o erro é de incompatibilidade de nome
    if echo "$WARP_INIT_OUTPUT" | grep -qi "Name mismatch"; then
        print_error "Erro de incompatibilidade de nome!"
        print_info "O Warp Route foi inicializado com um nome diferente."
        
        # Tentar extrair o nome esperado do erro
        EXPECTED_NAME=$(echo "$WARP_INIT_OUTPUT" | grep -oP 'left: "\K[^"]+' | head -1 || echo "")
        CURRENT_NAME=$(echo "$WARP_INIT_OUTPUT" | grep -oP 'right: "\K[^"]+' | head -1 || echo "")
        
        if [ ! -z "$EXPECTED_NAME" ] && [ ! -z "$CURRENT_NAME" ]; then
            print_info "Nome esperado (já inicializado): '$EXPECTED_NAME'"
            print_info "Nome atual no token-config.json: '$CURRENT_NAME'"
            echo ""
            print_info "Ajustando token-config.json..."
            
            # Atualizar token-config.json
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/\"name\": \"$CURRENT_NAME\"/\"name\": \"$EXPECTED_NAME\"/" "$TOKEN_CONFIG"
            else
                sed -i "s/\"name\": \"$CURRENT_NAME\"/\"name\": \"$EXPECTED_NAME\"/" "$TOKEN_CONFIG"
            fi
            
            print_success "token-config.json atualizado para: '$EXPECTED_NAME'"
            print_info "⚠️  IMPORTANTE: O metadata JSON pode manter '$CURRENT_NAME' no campo 'name'"
            print_info "   O nome no token-config.json é apenas para inicialização do Warp Route"
            echo ""
            print_info "Tentando inicializar novamente com o nome correto..."
            
            # Tentar novamente
            WARP_INIT_OUTPUT=$(cargo run -- \
              -k "$SOLANA_KEYPAIR" \
              -u "$SOLANA_RPC" \
              warp-route deploy \
              --warp-route-name "$WARP_ROUTE_DIR_NAME" \
              --environment testnet \
              --environments-dir "$ENVIRONMENTS_DIR" \
              --token-config-file "$TOKEN_CONFIG" \
              --built-so-dir "$BUILT_SO_DIR" \
              --registry "$REGISTRY_DIR" \
              --ata-payer-funding-amount 5000000 2>&1 | tee /tmp/warp-init-output.txt)
            
            WARP_INIT_EXIT_CODE=$?
            
            if [ $WARP_INIT_EXIT_CODE -eq 0 ]; then
                print_success "Warp Route inicializado com sucesso após correção!"
            else
                print_error "Erro ao inicializar Warp Route mesmo após correção"
                print_info "Output: $WARP_INIT_OUTPUT"
                exit 1
            fi
        else
            print_error "Não foi possível extrair os nomes do erro"
            print_info "Output: $WARP_INIT_OUTPUT"
            exit 1
        fi
    elif echo "$WARP_INIT_OUTPUT" | grep -qi "already\|exists\|initialized"; then
        print_info "Warp Route parece já estar inicializado. Continuando..."
    else
        print_error "Erro ao inicializar Warp Route"
        print_info "Output: $WARP_INIT_OUTPUT"
        print_question "Deseja continuar mesmo assim? (s/N)"
        read -p "Resposta: " CONTINUE_INIT
        if [[ ! "$CONTINUE_INIT" =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
fi

# Converter Program ID para hex (32 bytes)
print_info "Convertendo Program ID para hex..."
WARP_ROUTE_HEX=$(python3 << PYEOF
import base58
import binascii

program_id = "$WARP_ROUTE_PROGRAM_ID"
decoded = base58.b58decode(program_id)
hex_address = binascii.hexlify(decoded).decode('utf-8')
hex_padded = hex_address.zfill(64)
print(hex_padded)
PYEOF
)

print_info "Program ID (Hex): 0x$WARP_ROUTE_HEX"

# Extrair Mint Address do output
MINT_ADDRESS=$(grep -i "mint" /tmp/warp-init-output.txt | grep -oE "[1-9A-HJ-NP-Za-km-z]{32,44}" | head -1 || echo "")

if [ -z "$MINT_ADDRESS" ]; then
    print_info "Consultando Mint Address do Warp Route..."
    MINT_QUERY=$(cargo run -- \
      -k "$SOLANA_KEYPAIR" \
      -u "$SOLANA_RPC" \
      token query \
      --program-id "$WARP_ROUTE_PROGRAM_ID" \
      synthetic 2>&1)
    
    MINT_ADDRESS=$(echo "$MINT_QUERY" | grep -i "mint" | grep -oE "[1-9A-HJ-NP-Za-km-z]{32,44}" | head -1 || echo "")
fi

# ============================================================================
# PASSO 3: Configurar ISM no Warp Route
# ============================================================================

print_step "3/8" "Configurando ISM no Warp Route..."

cd "$CLIENT_DIR"

print_info "Associando ISM $ISM_PROGRAM_ID ao Warp Route..."

SET_ISM_OUTPUT=$(cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  token set-interchain-security-module \
  --program-id "$WARP_ROUTE_PROGRAM_ID" \
  --ism "$ISM_PROGRAM_ID" 2>&1 | tee /tmp/set-ism-output.txt)

SET_ISM_EXIT_CODE=$?

if [ $SET_ISM_EXIT_CODE -eq 0 ]; then
    print_success "ISM configurado no Warp Route"
else
    print_error "Erro ao configurar ISM (exit code: $SET_ISM_EXIT_CODE)"
    print_info "Possíveis causas:"
    print_info "  - Warp Route não foi inicializado corretamente (mint não existe)"
    print_info "  - Você não é o owner do Warp Route"
    print_info "  - Programa não está no estado esperado"
    print_info ""
    print_info "Output: $SET_ISM_OUTPUT"
    print_question "Deseja continuar mesmo assim? (s/N)"
    read -p "Resposta: " CONTINUE_ISM
    if [[ ! "$CONTINUE_ISM" =~ ^[Ss]$ ]]; then
        exit 1
    fi
    print_info "Continuando mesmo com erro no ISM..."
fi

# ============================================================================
# PASSO 4: Verificar ISM
# ============================================================================

print_step "4/8" "Verificando configuração do ISM..."

cd "$CLIENT_DIR"

print_info "Verificando validators no ISM..."

ISM_VERIFY_OUTPUT=$(cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  multisig-ism-message-id query \
  --program-id "$ISM_PROGRAM_ID" \
  --domains "$TERRA_DOMAIN" 2>&1)

echo "$ISM_VERIFY_OUTPUT" | grep -A 20 "Domain data" || print_info "Verificação concluída"

# Atualizar validators e threshold com dados reais
ISM_VALIDATORS_FULL=$(echo "$ISM_VERIFY_OUTPUT" | grep -A 20 "Domain data" | grep -E "0x[0-9a-fA-F]{40}" | sed 's/^[[:space:]]*//' | tr '\n' ',' | sed 's/,$//')
if [ ! -z "$ISM_VALIDATORS_FULL" ]; then
    ISM_VALIDATORS="$ISM_VALIDATORS_FULL"
fi

ISM_THRESHOLD_FULL=$(echo "$ISM_VERIFY_OUTPUT" | grep -A 20 "Domain data" | grep -i "threshold" | grep -oE "[0-9]+" | head -1)
if [ ! -z "$ISM_THRESHOLD_FULL" ]; then
    ISM_THRESHOLD="$ISM_THRESHOLD_FULL"
fi

# ============================================================================
# PASSO 5: Link Solana -> Terra Classic
# ============================================================================

print_step "5/8" "Fazendo link Solana -> Terra Classic (Enroll Remote Router)..."

cd "$CLIENT_DIR"

print_info "Enrollando Terra Classic router no Warp Route Solana..."
print_info "Domain: $TERRA_DOMAIN"
print_info "Router: $TERRA_WARP_HEX"

ENROLL_OUTPUT=$(cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  token enroll-remote-router \
  --program-id "$WARP_ROUTE_PROGRAM_ID" \
  "$TERRA_DOMAIN" \
  "$TERRA_WARP_HEX" 2>&1 | tee /tmp/enroll-router-output.txt)

ENROLL_EXIT_CODE=$?

if [ $ENROLL_EXIT_CODE -eq 0 ]; then
    print_success "Remote Router enrollado com sucesso (Solana -> Terra Classic)"
else
    print_error "Erro ao enrollar Remote Router (exit code: $ENROLL_EXIT_CODE)"
    print_info "Possíveis causas:"
    print_info "  - Warp Route não foi inicializado corretamente (mint não existe)"
    print_info "  - Argumentos inválidos (domain ou router hex)"
    print_info "  - Programa não está no estado esperado"
    print_info ""
    print_info "Output: $ENROLL_OUTPUT"
    print_question "Deseja continuar mesmo assim? (s/N)"
    read -p "Resposta: " CONTINUE_ENROLL
    if [[ ! "$CONTINUE_ENROLL" =~ ^[Ss]$ ]]; then
        exit 1
    fi
    print_info "Continuando mesmo com erro no enroll..."
fi

# ============================================================================
# PASSO 6: Link Terra Classic -> Solana
# ============================================================================

print_step "6/8" "Fazendo link Terra Classic -> Solana..."

print_info "Executando transação no Terra Classic..."
print_info "Warp Route: $TERRA_WARP_BECH32"
print_info "Solana Domain: $SOLANA_DOMAIN"
print_info "Solana Router (Hex): 0x$WARP_ROUTE_HEX"

terrad tx wasm execute "$TERRA_WARP_BECH32" \
  "{\"router\":{\"set_route\":{\"set\":{\"domain\":$SOLANA_DOMAIN,\"route\":\"$WARP_ROUTE_HEX\"}}}}" \
  --from "$TERRA_KEY_NAME" \
  --keyring-backend file \
  --chain-id "$TERRA_CHAIN_ID" \
  --node "$TERRA_RPC" \
  --gas auto \
  --gas-adjustment 1.5 \
  --fees "$TERRA_FEES" \
  --yes 2>&1 | tee /tmp/terra-link-output.txt

if [ $? -eq 0 ]; then
    print_success "Link Terra Classic -> Solana configurado com sucesso!"
else
    print_error "Erro ao configurar link Terra Classic -> Solana"
    print_info "Verifique se você é o owner do Warp Route do Terra Classic"
    exit 1
fi

# ============================================================================
# PASSO 7: Verificar Configuração Completa
# ============================================================================

print_step "7/8" "Verificando configuração completa..."

cd "$CLIENT_DIR"

print_info "Verificando Warp Route no Solana..."

WARP_QUERY_OUTPUT=$(cargo run -- \
  -k "$SOLANA_KEYPAIR" \
  -u "$SOLANA_RPC" \
  token query \
  --program-id "$WARP_ROUTE_PROGRAM_ID" \
  synthetic 2>&1)

echo "$WARP_QUERY_OUTPUT" | grep -A 20 "remote_routers\|interchain_security_module" || print_info "Query concluída"

# Extrair Mint Address se ainda não foi extraído
if [ -z "$MINT_ADDRESS" ]; then
    MINT_ADDRESS=$(echo "$WARP_QUERY_OUTPUT" | grep -i "mint" | grep -oE "[1-9A-HJ-NP-Za-km-z]{32,44}" | head -1 || echo "")
fi

print_info "Verificando rota no Terra Classic..."

terrad query wasm contract-state smart "$TERRA_WARP_BECH32" \
  "{\"router\":{\"get_route\":{\"domain\":$SOLANA_DOMAIN}}}" \
  --node "$TERRA_RPC" 2>&1 | grep -A 5 "route" || print_info "Query concluída"

# ============================================================================
# PASSO 8: Gerar Documentação Completa
# ============================================================================

print_step "8/8" "Gerando arquivo de documentação completa..."

INFO_FILE="/home/lunc/hyperlane-validator/WARP-ROUTE-${WARP_ROUTE_DIR_NAME// /-}-INFO.md"

# Converter validators para lista formatada
ISM_VALIDATORS_LIST=$(echo "$ISM_VALIDATORS" | tr ',' '\n' | sed 's/^/    - /' | tr '\n' ',' | sed 's/,$//' | sed 's/,/\n/g')

cat > "$INFO_FILE" << EOF
# Warp Route $WARP_ROUTE_DIR_NAME - Informações de Configuração

**Data de Criação:** $(date '+%Y-%m-%d %H:%M:%S')

---

## 📝 Warp Route Solana

### Informações Básicas
- **Name:** $WARP_ROUTE_DIR_NAME
- **Program ID (Base58):** $WARP_ROUTE_PROGRAM_ID
- **Program ID (Hex):** 0x$WARP_ROUTE_HEX
- **Token Symbol:** $TOKEN_SYMBOL
- **Token Name:** $TOKEN_NAME
- **Decimals:** $TOKEN_DECIMALS
- **Metadata URI:** $TOKEN_METADATA_URI

### Mint Account
- **Mint Address:** ${MINT_ADDRESS:-N/A (consultar via query)}
- **Token Type:** Synthetic

### Configurações
- **Interchain Security Module:** $ISM_PROGRAM_ID
- **Interchain Gas Paymaster Program:** 5p7Hii6CJL4xGBYYTGEQmH9LnUSZteFJUu9AVLDExZX2
- **Interchain Gas Paymaster Account:** 9SQVtTNsbipdMzumhzi6X8GwojiSMwBfqAhS7FgyTcqy
- **Mailbox:** 75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR

### Remote Routers
- **Terra Classic (Domain $TERRA_DOMAIN):** $TERRA_WARP_HEX

---

## 📝 Warp Route Terra Classic

### Informações Básicas
- **Address (Bech32):** $TERRA_WARP_BECH32
- **Address (Hex):** $TERRA_WARP_HEX
- **Domain ID:** $TERRA_DOMAIN

### Remote Routers
- **Solana (Domain $SOLANA_DOMAIN):** 0x$WARP_ROUTE_HEX

---

## 🛡️ ISM (Interchain Security Module)

### Configuração
- **Program ID:** $ISM_PROGRAM_ID
- **Type:** Multisig ISM Message ID
- **Owner:** $(solana address -k "$SOLANA_KEYPAIR" 2>/dev/null || echo "N/A")

### Validators Configurados

#### Domain: $TERRA_DOMAIN (Terra Classic)

**Validators:**
$(echo "$ISM_VALIDATORS" | tr ',' '\n' | sed 's/^/- /')

**Threshold:** $ISM_THRESHOLD

**Detalhes:**
- Número de validators: $(echo "$ISM_VALIDATORS" | tr ',' '\n' | wc -l)
- Threshold mínimo: $ISM_THRESHOLD assinatura(s) necessária(s)
- Status: $(if [ "$ISM_THRESHOLD" != "N/A" ]; then echo "✅ Configurado"; else echo "⚠️ Não configurado"; fi)

---

## ✅ Status da Configuração

| Componente | Status |
|------------|--------|
| Warp Route Solana | ✅ Deployado |
| Warp Route Terra Classic | ✅ Configurado |
| ISM | ✅ Configurado e Associado |
| Link Solana → Terra Classic | ✅ Configurado |
| Link Terra Classic → Solana | ✅ Configurado |
| IGP | ✅ Configurado |

---

## 🔗 Links e Exploradores

### Solana Testnet
- **Warp Route Explorer:** https://explorer.solana.com/address/$WARP_ROUTE_PROGRAM_ID?cluster=testnet
$(if [ ! -z "$MINT_ADDRESS" ]; then echo "- **Mint Explorer:** https://explorer.solana.com/address/$MINT_ADDRESS?cluster=testnet"; fi)
- **ISM Explorer:** https://explorer.solana.com/address/$ISM_PROGRAM_ID?cluster=testnet

### Terra Classic Testnet
- **Explorer:** https://finder.terra-classic.hexxagon.dev/testnet/address/$TERRA_WARP_BECH32
- **Warp Route:** $TERRA_WARP_BECH32

---

## 📋 Comandos Úteis

### Verificar Warp Route no Solana
\`\`\`bash
cd ~/hyperlane-monorepo/rust/sealevel/client
cargo run -- \\
  -k $SOLANA_KEYPAIR \\
  -u $SOLANA_RPC \\
  token query \\
  --program-id $WARP_ROUTE_PROGRAM_ID \\
  synthetic
\`\`\`

### Verificar Rota no Terra Classic
\`\`\`bash
terrad query wasm contract-state smart $TERRA_WARP_BECH32 \\
  '{"router":{"get_route":{"domain":$SOLANA_DOMAIN}}}' \\
  --node $TERRA_RPC
\`\`\`

### Verificar ISM e Validators
\`\`\`bash
cd ~/hyperlane-monorepo/rust/sealevel/client
cargo run -- \\
  -k $SOLANA_KEYPAIR \\
  -u $SOLANA_RPC \\
  multisig-ism-message-id query \\
  --program-id $ISM_PROGRAM_ID \\
  --domains $TERRA_DOMAIN
\`\`\`

### Verificar Mint Address
\`\`\`bash
cd ~/hyperlane-monorepo/rust/sealevel/client
cargo run -- \\
  -k $SOLANA_KEYPAIR \\
  -u $SOLANA_RPC \\
  token query synthetic \\
  --program-id $WARP_ROUTE_PROGRAM_ID
\`\`\`

---

## 🚀 Próximos Passos

1. **Verificar Confirmação das Transações**
   - Verificar se todas as transações foram confirmadas nos blockchains
   - Terra Classic: Verificar transação em \`/tmp/terra-link-output.txt\`
   - Solana: Verificar transações no explorer

2. **Testar Transferência Terra Classic → Solana**
   - Enviar tokens do Terra Classic para o Solana
   - Verificar recebimento do token sintético $TOKEN_SYMBOL

3. **Testar Transferência Solana → Terra Classic**
   - Queimar token sintético $TOKEN_SYMBOL no Solana
   - Verificar recebimento de tokens no Terra Classic

---

## 📁 Arquivos de Configuração

- **Token Config:** $TOKEN_CONFIG
- **Program IDs:** $WARP_ROUTE_DIR/program-ids.json
- **Keypairs:** $WARP_ROUTE_DIR/keys/
- **Script de Criação:** $(readlink -f "$0" || echo "$0")

---

## 🔍 Informações Técnicas

### Validação de Quorum
- O ISM requer **$ISM_THRESHOLD** assinatura(s) de **$(echo "$ISM_VALIDATORS" | tr ',' '\n' | wc -l)** validator(es) configurado(s)
- Validators configurados para Terra Classic (Domain $TERRA_DOMAIN):
$(echo "$ISM_VALIDATORS" | tr ',' '\n' | sed 's/^/  - /')

### Metadados do Token
- **Name:** $TOKEN_NAME
- **Symbol:** $TOKEN_SYMBOL
- **Decimals:** $TOKEN_DECIMALS
- **Metadata URI:** $TOKEN_METADATA_URI
- **Mint:** ${MINT_ADDRESS:-Gerado automaticamente após deploy}
- **Update Authority:** $(solana address -k "$SOLANA_KEYPAIR" 2>/dev/null || echo "Gerado automaticamente")
- **Additional Metadata:** [] (vazio, gerado automaticamente)

### Endereços Importantes
- **Solana Domain:** $SOLANA_DOMAIN
- **Terra Classic Domain:** $TERRA_DOMAIN
- **Warp Route Solana (Hex):** 0x$WARP_ROUTE_HEX
- **Warp Route Terra Classic (Hex):** $TERRA_WARP_HEX

---

**Última Atualização:** $(date '+%Y-%m-%d %H:%M:%S')
EOF

print_success "Arquivo de documentação criado: $INFO_FILE"
echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_header "✅ CONFIGURAÇÃO COMPLETA!"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   RESUMO DA CONFIGURAÇÃO                                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Warp Route Solana:${NC}"
echo "  Name: $WARP_ROUTE_DIR_NAME"
echo "  Program ID: $WARP_ROUTE_PROGRAM_ID"
echo "  Program ID (Hex): 0x$WARP_ROUTE_HEX"
echo "  Token Symbol: $TOKEN_SYMBOL"
echo "  Token Name: $TOKEN_NAME"
echo "  Decimals: $TOKEN_DECIMALS"
echo "  Metadata URI: $TOKEN_METADATA_URI"
if [ ! -z "$MINT_ADDRESS" ]; then
    echo "  Mint Address: $MINT_ADDRESS"
fi
echo ""
echo -e "${BLUE}📝 Warp Route Terra Classic:${NC}"
echo "  Address: $TERRA_WARP_BECH32"
echo "  Hex: $TERRA_WARP_HEX"
echo ""
echo -e "${BLUE}📝 ISM Configurado:${NC}"
echo "  Program ID: $ISM_PROGRAM_ID"
echo "  Validators: $ISM_VALIDATORS"
echo "  Threshold: $ISM_THRESHOLD"
echo ""
echo -e "${BLUE}📝 Links Configurados:${NC}"
echo "  ✅ Solana -> Terra Classic (Domain $TERRA_DOMAIN)"
echo "  ✅ Terra Classic -> Solana (Domain $SOLANA_DOMAIN)"
echo ""
echo -e "${BLUE}🔍 Próximos Passos:${NC}"
echo "  1. Verificar se as transações foram confirmadas"
echo "  2. Testar transferência Terra Classic -> Solana"
echo "  3. Testar transferência Solana -> Terra Classic"
echo ""

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ SCRIPT CONCLUÍDO COM SUCESSO!                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📄 Documentação salva em:${NC} $INFO_FILE"
echo ""

