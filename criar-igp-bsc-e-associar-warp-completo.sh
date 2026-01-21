#!/bin/bash

# ============================================================================
# Script: Criar/Configurar IGP e Associar ao Warp Route - BSC Testnet
# ============================================================================
# Este script permite:
# 1. Criar um novo IGP proxy e associar ao Warp Route
# 2. Ou apenas configurar/atualizar taxa de gas em IGP existente
# ============================================================================

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

print_section() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
BSC_RPC="https://bsc-testnet.publicnode.com"
BSC_DOMAIN=97
TERRA_DOMAIN=1325
CHAIN_NAME="bsctestnet"

# Warp Route BSC
WARP_ROUTE_BSC="0x2144Be4477202ba2d50c9A8be3181241878cf7D8"

# Endereços conhecidos do Hyperlane BSC Testnet
PROXY_ADMIN="0xb12282d2E838Aa5f2A4F9Ee5f624a77b7199A078"
IGP_IMPLEMENTATION="0x795B9b7AA901C8B999b62B8c80299e79a5c96057"  # Implementação do IGP padrão
IGP_DEFAULT="0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949"  # IGP padrão (proxy)
STORAGE_GAS_ORACLE="0x124EBCBC018A5D4Efe639f02ED86f95cdC3f6498"  # StorageGasOracle padrão

# Parâmetros do Gas Oracle para Terra Classic
# Terra Classic: exchange_rate=40000000000000, gas_price=1, custo 200k gas=800 LUNC
# Calculado: token_exchange_rate=40000000000000000, gas_price=1, token_decimals=6
TOKEN_EXCHANGE_RATE=${TOKEN_EXCHANGE_RATE:-40000000000000000}
GAS_PRICE=${GAS_PRICE:-1}
TOKEN_DECIMALS=${TOKEN_DECIMALS:-6}
GAS_OVERHEAD=${GAS_OVERHEAD:-0}

# Diretório do monorepo Solidity
SOLIDITY_DIR="/home/lunc/hyperlane-monorepo/solidity"

# ============================================================================
# VERIFICAÇÕES INICIAIS
# ============================================================================

# Verificar se cast está instalado
if ! command -v cast &> /dev/null; then
    print_error "cast (Foundry) não está instalado"
    print_info "Instale: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# Verificar chave privada BSC
if [ -z "$BSC_PRIVATE_KEY" ] && [ -z "$BSC_KMS_ALIAS" ]; then
    print_warning "BSC_PRIVATE_KEY ou BSC_KMS_ALIAS não configurado"
    print_info "Fornecendo via variável de ambiente ou KMS alias"
    read -p "Digite a chave privada BSC (0x...) ou pressione Enter para usar KMS: " BSC_KEY_INPUT
    
    if [ ! -z "$BSC_KEY_INPUT" ]; then
        export BSC_PRIVATE_KEY="$BSC_KEY_INPUT"
    elif [ -z "$BSC_KMS_ALIAS" ]; then
        read -p "Digite o alias KMS (ex: alias/hyperlane-relayer-signer-bsc): " BSC_KMS_INPUT
        if [ ! -z "$BSC_KMS_INPUT" ]; then
            export BSC_KMS_ALIAS="$BSC_KMS_INPUT"
        else
            print_error "Chave privada ou KMS alias é obrigatório"
            exit 1
        fi
    fi
fi

# Obter endereço do owner
if [ ! -z "$BSC_PRIVATE_KEY" ]; then
    OWNER_ADDRESS=$(cast wallet address --private-key "$BSC_PRIVATE_KEY" 2>/dev/null)
    SIGNER_ARG="--private-key $BSC_PRIVATE_KEY"
elif [ ! -z "$BSC_KMS_ALIAS" ]; then
    OWNER_ADDRESS=$(cast wallet address --aws "$BSC_KMS_ALIAS" 2>/dev/null)
    SIGNER_ARG="--aws $BSC_KMS_ALIAS"
else
    print_error "Nenhuma chave configurada"
    exit 1
fi

if [ -z "$OWNER_ADDRESS" ]; then
    print_error "Não foi possível obter endereço do owner"
    exit 1
fi

# ============================================================================
# MENU PRINCIPAL
# ============================================================================
print_header "CRIAR/CONFIGURAR IGP E ASSOCIAR AO WARP ROUTE - BSC TESTNET"

print_info "Este script permite:"
print_value "1. Criar um novo IGP proxy e associar ao Warp Route"
print_value "2. Configurar/atualizar taxa de gas em IGP existente"
echo ""

print_info "Configurações:"
print_value "Warp Route BSC: $WARP_ROUTE_BSC"
print_value "Owner: $OWNER_ADDRESS"
print_value "BSC RPC: $BSC_RPC"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

# Escolher modo de operação
if [ -z "$AUTO_CONFIRM" ]; then
    echo "Escolha o modo de operação:"
    echo "  1) Criar novo IGP e associar ao Warp Route"
    echo "  2) Usar IGP existente e apenas configurar taxa de gas"
    read -p "Digite sua escolha (1 ou 2): " MODE_CHOICE
else
    # Em modo automático, usar variável de ambiente ou padrão
    if [ ! -z "$USE_EXISTING_IGP" ] && [[ "$USE_EXISTING_IGP" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        MODE_CHOICE="2"
        EXISTING_IGP_ADDRESS="$USE_EXISTING_IGP"
    else
        MODE_CHOICE="1"
    fi
fi

if [ "$MODE_CHOICE" = "2" ]; then
    # Modo 2: Usar IGP existente
    if [ -z "$EXISTING_IGP_ADDRESS" ]; then
        read -p "Digite o endereço do IGP existente (0x...): " EXISTING_IGP_ADDRESS
    fi
    
    if [ -z "$EXISTING_IGP_ADDRESS" ] || [[ ! "$EXISTING_IGP_ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Endereço de IGP inválido"
        exit 1
    fi
    
    NEW_IGP_ADDRESS="$EXISTING_IGP_ADDRESS"
    SKIP_DEPLOY=true
    SKIP_ASSOCIATION=true  # Não associar se já estiver associado
    print_info "Usando IGP existente: $NEW_IGP_ADDRESS"
else
    # Modo 1: Criar novo IGP
    SKIP_DEPLOY=false
    SKIP_ASSOCIATION=false
    print_info "Criando novo IGP proxy..."
fi

echo ""

# Confirmação automática se AUTO_CONFIRM estiver definido
if [ -z "$AUTO_CONFIRM" ]; then
    read -p "Deseja continuar? (s/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
        print_info "Operação cancelada."
        exit 0
    fi
else
    print_info "Execução automática habilitada (AUTO_CONFIRM=1)"
fi

echo ""

# ============================================================================
# PASSO 1: Criar novo proxy IGP (se necessário)
# ============================================================================
if [ "$SKIP_DEPLOY" != "true" ]; then
    print_section "PASSO 1: CRIAR NOVO PROXY IGP"
    
    print_info "O Hyperlane usa um padrão de proxy onde a implementação já está deployada"
    print_info "Vamos criar um NOVO proxy IGP apontando para a implementação existente"
    print_info "Isso não requer deploy completo, apenas instanciar um novo proxy"
    echo ""
    
    print_info "Configurações:"
    print_value "Proxy Admin: $PROXY_ADMIN"
    print_value "IGP Implementation: $IGP_IMPLEMENTATION"
    print_value "IGP Padrão (referência): $IGP_DEFAULT"
    echo ""
    
    # Criar novo proxy IGP usando TransparentUpgradeableProxy
    print_info "Criando novo proxy IGP usando TransparentUpgradeableProxy..."
    
    # Definir SOLIDITY_DIR se não estiver definido
    if [ -z "$SOLIDITY_DIR" ]; then
        SOLIDITY_DIR="/home/lunc/hyperlane-monorepo/solidity"
    fi
    
    # Obter bytecode do TransparentUpgradeableProxy
    if [ ! -d "$SOLIDITY_DIR" ]; then
        print_error "Diretório do monorepo não encontrado: $SOLIDITY_DIR"
        exit 1
    fi
    
    PROXY_BYTECODE_FILE=$(find "$SOLIDITY_DIR/out" -name "TransparentUpgradeableProxy.json" -not -path "*/ITransparentUpgradeableProxy.json" 2>/dev/null | head -1)
    
    if [ -z "$PROXY_BYTECODE_FILE" ] || [ ! -f "$PROXY_BYTECODE_FILE" ]; then
        print_warning "Bytecode do proxy não encontrado. Tentando compilar..."
        cd "$SOLIDITY_DIR"
        forge build dependencies/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol --skip test 2>&1 | tail -5
        
        # Tentar encontrar novamente após compilação
        PROXY_BYTECODE_FILE=$(find "$SOLIDITY_DIR/out" -name "TransparentUpgradeableProxy.json" -not -path "*/ITransparentUpgradeableProxy.json" 2>/dev/null | head -1)
        
        if [ -z "$PROXY_BYTECODE_FILE" ] || [ ! -f "$PROXY_BYTECODE_FILE" ]; then
            print_error "Não foi possível obter bytecode do TransparentUpgradeableProxy"
            print_info "Verifique se o contrato foi compilado: cd $SOLIDITY_DIR && forge build"
            exit 1
        fi
    fi
    
    print_success "Bytecode encontrado em: $PROXY_BYTECODE_FILE"
    
    PROXY_BYTECODE=$(jq -r '.bytecode.object' "$PROXY_BYTECODE_FILE" 2>/dev/null)
    
    if [ -z "$PROXY_BYTECODE" ] || [ "$PROXY_BYTECODE" = "null" ]; then
        print_error "Não foi possível extrair bytecode do proxy"
        exit 1
    fi
    
    print_success "Bytecode do proxy obtido"
    print_info "Criando novo proxy IGP..."
    print_value "Implementation: $IGP_IMPLEMENTATION"
    print_value "Admin: $PROXY_ADMIN"
    echo ""
    
    # Preparar dados de inicialização: initialize(owner, beneficiary)
    INITIALIZE_SIG="initialize(address,address)"
    INITIALIZE_CALLDATA=$(cast calldata "$INITIALIZE_SIG" "$OWNER_ADDRESS" "$OWNER_ADDRESS")
    
    # Constructor do TransparentUpgradeableProxy: constructor(address _logic, address admin_, bytes memory _data)
    # O cast send --create aceita os parâmetros do constructor diretamente
    # Combinar bytecode + constructor calldata
    CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,bytes)" "$IGP_IMPLEMENTATION" "$PROXY_ADMIN" "$INITIALIZE_CALLDATA")
    FULL_BYTECODE="${PROXY_BYTECODE}${CONSTRUCTOR_ARGS#0x}"
    
    print_info "Deployando novo proxy IGP..."
    DEPLOY_OUTPUT=$(cast send --rpc-url "$BSC_RPC" $SIGNER_ARG \
        --create "$FULL_BYTECODE" \
        --json 2>&1)
    
    if echo "$DEPLOY_OUTPUT" | grep -qi "error\|failed"; then
        print_error "Erro ao deployar proxy"
        echo "$DEPLOY_OUTPUT"
        exit 1
    fi
    
    # Extrair endereço do proxy deployado
    NEW_IGP_ADDRESS=$(echo "$DEPLOY_OUTPUT" | jq -r '.contractAddress' 2>/dev/null || \
                      echo "$DEPLOY_OUTPUT" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
    
    if [ -z "$NEW_IGP_ADDRESS" ] || [ "$NEW_IGP_ADDRESS" = "null" ]; then
        print_error "Não foi possível obter endereço do proxy deployado"
        echo "$DEPLOY_OUTPUT"
        exit 1
    fi
    
    print_success "Novo proxy IGP criado com sucesso!"
    print_success "Novo IGP Address: $NEW_IGP_ADDRESS"
    echo ""
    
    # Verificar se foi inicializado corretamente
    print_info "Verificando inicialização do proxy..."
    PROXY_OWNER=$(cast call "$NEW_IGP_ADDRESS" "owner()(address)" --rpc-url "$BSC_RPC" 2>/dev/null || echo "")
    
    if [ "$PROXY_OWNER" = "$OWNER_ADDRESS" ]; then
        print_success "Proxy inicializado corretamente! Owner: $PROXY_OWNER"
    else
        print_warning "Owner não corresponde. Verificando..."
        print_value "Esperado: $OWNER_ADDRESS"
        print_value "Obtido: $PROXY_OWNER"
    fi
    echo ""
fi

# ============================================================================
# PASSO 2: Configurar Gas Oracle no IGP
# ============================================================================
print_section "PASSO 2: CONFIGURAR GAS ORACLE PARA TERRA CLASSIC"

print_info "Configurando Gas Oracle para Terra Classic (Domain $TERRA_DOMAIN)..."
print_value "IGP: $NEW_IGP_ADDRESS"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Gas Overhead: $GAS_OVERHEAD"
echo ""

# Configurar destino Gas Config no IGP
# setDestinationGasConfigs((uint32,(address,uint96))[])
print_info "Configurando destino Gas Config no IGP..."
print_info "Usando StorageGasOracle padrão: $STORAGE_GAS_ORACLE"

SET_GAS_CONFIG_CALLDATA=$(cast calldata "setDestinationGasConfigs((uint32,(address,uint96))[])" "[($TERRA_DOMAIN,($STORAGE_GAS_ORACLE,$GAS_OVERHEAD))]")

SET_GAS_CONFIG_OUTPUT=$(cast send "$NEW_IGP_ADDRESS" \
    --rpc-url "$BSC_RPC" \
    $SIGNER_ARG \
    "$SET_GAS_CONFIG_CALLDATA" \
    --json 2>&1)

if echo "$SET_GAS_CONFIG_OUTPUT" | grep -qi "error\|failed\|revert"; then
    print_error "Erro ao configurar Gas Config no IGP"
    echo "$SET_GAS_CONFIG_OUTPUT"
    print_warning "Continuando mesmo assim..."
else
    print_success "Gas Config configurado no IGP com sucesso!"
fi
echo ""

# Configurar token_exchange_rate e gas_price no StorageGasOracle
# Nota: Isso só funciona se você for o owner do StorageGasOracle
print_info "Tentando configurar token_exchange_rate e gas_price no StorageGasOracle..."
STORAGE_ORACLE_OWNER=$(cast call "$STORAGE_GAS_ORACLE" "owner()(address)" --rpc-url "$BSC_RPC" 2>/dev/null || echo "")

if [ "$STORAGE_ORACLE_OWNER" = "$OWNER_ADDRESS" ]; then
    print_info "Você é o owner do StorageGasOracle. Configurando valores..."
    
    SET_REMOTE_GAS_DATA_CALLDATA=$(cast calldata "setRemoteGasData((uint32,uint128,uint128))" "($TERRA_DOMAIN,$TOKEN_EXCHANGE_RATE,$GAS_PRICE)")
    
    SET_REMOTE_GAS_OUTPUT=$(cast send "$STORAGE_GAS_ORACLE" \
        --rpc-url "$BSC_RPC" \
        $SIGNER_ARG \
        "$SET_REMOTE_GAS_DATA_CALLDATA" \
        --json 2>&1)
    
    if echo "$SET_REMOTE_GAS_OUTPUT" | grep -qi "error\|failed\|revert"; then
        print_warning "Não foi possível configurar StorageGasOracle"
        echo "$SET_REMOTE_GAS_OUTPUT"
    else
        print_success "StorageGasOracle configurado com sucesso!"
    fi
else
    print_warning "Você não é o owner do StorageGasOracle padrão ($STORAGE_ORACLE_OWNER)"
    print_info "Para configurar token_exchange_rate e gas_price, você precisa:"
    print_value "1. Ser o owner do StorageGasOracle, ou"
    print_value "2. Criar seu próprio Gas Oracle contract, ou"
    print_value "3. Usar o Hyperlane CLI para configurar"
fi
echo ""

# ============================================================================
# PASSO 3: Associar IGP ao Warp Route (se necessário)
# ============================================================================
if [ "$SKIP_ASSOCIATION" != "true" ]; then
    print_section "PASSO 3: ASSOCIAR IGP AO WARP ROUTE"
    
    print_info "Associando IGP ao Warp Route..."
    print_value "Warp Route: $WARP_ROUTE_BSC"
    print_value "IGP: $NEW_IGP_ADDRESS"
    echo ""
    
    # Verificar se o owner do Warp Route é o mesmo que está executando
    WARP_OWNER=$(cast call "$WARP_ROUTE_BSC" \
        "owner()(address)" \
        --rpc-url "$BSC_RPC" 2>/dev/null)
    
    if [ ! -z "$WARP_OWNER" ] && [ "$WARP_OWNER" != "$OWNER_ADDRESS" ]; then
        print_warning "⚠️  O owner do Warp Route ($WARP_OWNER) é diferente do seu endereço ($OWNER_ADDRESS)"
        print_warning "Você pode não ter permissão para associar o IGP"
        if [ -z "$AUTO_CONFIRM" ]; then
            read -p "Deseja continuar mesmo assim? (s/N): " CONTINUE_ANYWAY
            if [[ ! "$CONTINUE_ANYWAY" =~ ^[Ss]$ ]]; then
                print_info "Operação cancelada."
                exit 0
            fi
        fi
    fi
    
    # O IGP é configurado como hook no Warp Route usando setHook(address)
    # Esta é a mesma lógica usada em Solana
    print_info "Associando IGP ao Warp Route via setHook(address)..."
    print_info "Nota: Em Solana, o comando é: cargo run token igp set <IGP_PROGRAM_ID> igp <NEW_IGP_ACCOUNT>"
    print_info "Em BSC, usamos: setHook(address) - mesma lógica!"
    echo ""
    
    SET_HOOK_CALLDATA=$(cast calldata "setHook(address)" "$NEW_IGP_ADDRESS")
    
    SET_HOOK_OUTPUT=$(cast send "$WARP_ROUTE_BSC" \
        --rpc-url "$BSC_RPC" \
        $SIGNER_ARG \
        "$SET_HOOK_CALLDATA" \
        --json 2>&1)
    
    if echo "$SET_HOOK_OUTPUT" | grep -qi "error\|failed\|revert"; then
        print_error "Erro ao associar IGP ao Warp Route"
        echo "$SET_HOOK_OUTPUT"
        print_warning "O IGP foi criado/configurado, mas não foi associado ao Warp Route"
        print_info "Você pode tentar associar manualmente depois usando:"
        print_value "cast send $WARP_ROUTE_BSC \"setHook(address)\" $NEW_IGP_ADDRESS --rpc-url $BSC_RPC $SIGNER_ARG"
        exit 1
    fi
    
    print_success "IGP associado ao Warp Route com sucesso!"
    
    # Verificar se o hook foi configurado corretamente
    CURRENT_HOOK=$(cast call "$WARP_ROUTE_BSC" "hook()(address)" --rpc-url "$BSC_RPC" 2>/dev/null || echo "")
    
    if [ "$CURRENT_HOOK" = "$NEW_IGP_ADDRESS" ]; then
        print_success "Hook verificado: $CURRENT_HOOK"
    else
        print_warning "Hook não corresponde. Verificando..."
        print_value "Esperado: $NEW_IGP_ADDRESS"
        print_value "Obtido: $CURRENT_HOOK"
    fi
    echo ""
fi

# ============================================================================
# RESUMO FINAL
# ============================================================================
print_header "✅ PROCESSO CONCLUÍDO COM SUCESSO!"

print_success "IGP Address: $NEW_IGP_ADDRESS"
if [ "$SKIP_DEPLOY" != "true" ]; then
    print_success "Implementation: $IGP_IMPLEMENTATION"
    print_success "Owner: $OWNER_ADDRESS"
fi
if [ "$SKIP_ASSOCIATION" != "true" ]; then
    print_success "IGP associado ao Warp Route: $WARP_ROUTE_BSC"
    CURRENT_HOOK=$(cast call "$WARP_ROUTE_BSC" "hook()(address)" --rpc-url "$BSC_RPC" 2>/dev/null || echo "")
    if [ ! -z "$CURRENT_HOOK" ]; then
        print_success "Hook verificado: $CURRENT_HOOK"
    fi
fi
print_success "Gas Oracle configurado para Terra Classic (Domain $TERRA_DOMAIN)"
echo ""

print_info "Configurações do Gas Oracle:"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Gas Overhead: $GAS_OVERHEAD"
print_value "StorageGasOracle: $STORAGE_GAS_ORACLE"
echo ""

STORAGE_ORACLE_OWNER=$(cast call "$STORAGE_GAS_ORACLE" "owner()(address)" --rpc-url "$BSC_RPC" 2>/dev/null || echo "")
if [ "$STORAGE_ORACLE_OWNER" != "$OWNER_ADDRESS" ]; then
    print_warning "⚠️  StorageGasOracle:"
    print_value "O StorageGasOracle padrão ($STORAGE_GAS_ORACLE) não é seu (owner: $STORAGE_ORACLE_OWNER)"
    print_value "Para configurar token_exchange_rate e gas_price, você precisa:"
    print_value "1. Ser o owner do StorageGasOracle, ou"
    print_value "2. Criar seu próprio Gas Oracle contract, ou"
    print_value "3. Usar o Hyperlane CLI para configurar"
    echo ""
fi

print_info "Próximos passos:"
print_value "1. Verifique se o Gas Oracle está configurado corretamente"
print_value "2. Teste uma transferência BSC -> Terra Classic"
print_value "3. Verifique se o gas está sendo pago corretamente"
print_value "4. Ajuste os valores do Gas Oracle se necessário"
echo ""

print_success "🎉 Tudo pronto! O Warp Route agora está usando o IGP configurado!"
