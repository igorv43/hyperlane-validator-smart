#!/bin/bash

# ============================================================================
# Script: Deployar Factory e Criar MessageIdMultisigIsm no Sepolia
# ============================================================================
# Este script deploya a StaticMessageIdMultisigIsmFactory no Sepolia
# e cria um MessageIdMultisigIsm, seguindo a mesma lógica do Solana.
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅${NC}  $1"; }
print_error() { echo -e "${RED}❌${NC}  $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC}  $1"; }
print_value() { echo -e "  ${YELLOW}$1${NC}"; }

# Configurações
SEPOLIA_RPC="https://1rpc.io/sepolia"
TERRA_VALIDATOR="0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0"
THRESHOLD=1
WARP_ROUTE_SEPOLIA="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"

# Verificar PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ]; then
    print_error "Variável PRIVATE_KEY não definida"
    exit 1
fi

print_header "DEPLOYAR FACTORY E CRIAR MESSAGEIDMULTISIGISM NO SEPOLIA"

print_info "Este script irá:"
print_value "1. Deployar StaticMessageIdMultisigIsmFactory no Sepolia"
print_value "2. Criar MessageIdMultisigIsm usando a factory"
print_value "3. Atualizar Warp Route para usar o novo ISM"
echo ""

read -p "Deseja continuar? (sim/não): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss][Ii][Mm]$ ]]; then
    print_info "Operação cancelada"
    exit 0
fi
echo ""

# Verificar se estamos no diretório correto
SOLIDITY_DIR="$HOME/hyperlane-monorepo/solidity"
if [ ! -d "$SOLIDITY_DIR" ]; then
    print_error "Diretório solidity não encontrado: $SOLIDITY_DIR"
    exit 1
fi

print_info "Diretório solidity: $SOLIDITY_DIR"
print_info "Compilando contratos..."
cd "$SOLIDITY_DIR"

# Compilar contratos
if command -v forge &> /dev/null; then
    print_info "Usando forge para compilar..."
    forge build --contracts contracts/isms/multisig/StaticMultisigIsm.sol 2>&1 | grep -v "warning:" | tail -10 || echo "Compilação em andamento..."
else
    print_error "forge não está instalado"
    exit 1
fi

echo ""
print_info "Deployando StaticMessageIdMultisigIsmFactory..."
FACTORY_DEPLOY=$(forge create \
    contracts/isms/multisig/StaticMultisigIsm.sol:StaticMessageIdMultisigIsmFactory \
    --rpc-url "$SEPOLIA_RPC" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    2>&1 || echo "ERROR")

if echo "$FACTORY_DEPLOY" | grep -qi "error\|ERROR"; then
    print_error "Erro ao deployar factory:"
    echo "$FACTORY_DEPLOY"
    exit 1
fi

FACTORY_ADDRESS=$(echo "$FACTORY_DEPLOY" | grep -oE "Deployed to: 0x[0-9a-f]{40}" | grep -oE "0x[0-9a-f]{40}" || echo "")
if [ -z "$FACTORY_ADDRESS" ]; then
    print_error "Não foi possível extrair o endereço da factory"
    echo "$FACTORY_DEPLOY"
    exit 1
fi

print_success "✅ Factory deployada: $FACTORY_ADDRESS"
echo ""

# Agora usar a factory para criar o ISM
print_info "Criando MessageIdMultisigIsm usando a factory..."
DEPLOY_CALLDATA=$(cast calldata "deploy(address[],uint8)" "[$TERRA_VALIDATOR]" "$THRESHOLD" 2>&1 || echo "")

if [ ! -z "$DEPLOY_CALLDATA" ]; then
    print_info "Enviando transação para criar ISM..."
    DEPLOY_RESULT=$(cast send "$FACTORY_ADDRESS" "$DEPLOY_CALLDATA" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$SEPOLIA_RPC" \
        2>&1 || echo "ERROR")
    
    if echo "$DEPLOY_RESULT" | grep -qi "error\|ERROR"; then
        print_error "Erro ao criar ISM:"
        echo "$DEPLOY_RESULT"
        exit 1
    fi
    
    # Calcular endereço do ISM
    NEW_ISM_ADDRESS=$(cast call "$FACTORY_ADDRESS" "getAddress(address[],uint8)" "[$TERRA_VALIDATOR]" "$THRESHOLD" --rpc-url "$SEPOLIA_RPC" 2>&1 | grep -oE "0x[0-9a-f]{40}" | head -1 || echo "")
    
    if [ ! -z "$NEW_ISM_ADDRESS" ]; then
        print_success "✅ ISM criado: $NEW_ISM_ADDRESS"
        
        # Atualizar Warp Route
        print_info "Atualizando Warp Route..."
        SET_ISM_CALLDATA=$(cast calldata "setInterchainSecurityModule(address)" "$NEW_ISM_ADDRESS" 2>&1 || echo "")
        
        if [ ! -z "$SET_ISM_CALLDATA" ]; then
            UPDATE_RESULT=$(cast send "$WARP_ROUTE_SEPOLIA" "$SET_ISM_CALLDATA" \
                --private-key "$PRIVATE_KEY" \
                --rpc-url "$SEPOLIA_RPC" \
                2>&1 || echo "ERROR")
            
            if echo "$UPDATE_RESULT" | grep -qi "error\|ERROR"; then
                print_error "Erro ao atualizar Warp Route:"
                echo "$UPDATE_RESULT"
                exit 1
            fi
            
            print_success "✅ Warp Route atualizado!"
            echo ""
            print_success "✅ Configuração concluída!"
            print_value "Factory: $FACTORY_ADDRESS"
            print_value "ISM: $NEW_ISM_ADDRESS"
            print_value "Warp Route: $WARP_ROUTE_SEPOLIA"
        fi
    fi
fi
