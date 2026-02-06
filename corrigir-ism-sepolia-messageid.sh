#!/bin/bash

# ============================================================================
# Script: Corrigir ISM do Sepolia - Usar MessageIdMultisigIsm como Solana
# ============================================================================
# Este script corrige o ISM do Warp Route do Sepolia para usar
# MessageIdMultisigIsm (tipo 5) em vez de DomainRoutingISM (tipo 1),
# seguindo a mesma lógica do Solana.
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC}  $1"
}

print_error() {
    echo -e "${RED}❌${NC}  $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC}  $1"
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

SEPOLIA_RPC="https://1rpc.io/sepolia"
SEPOLIA_DOMAIN=11155111
TERRA_DOMAIN=1325

# Warp Route Sepolia
WARP_ROUTE_SEPOLIA="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"

# ISM Factory (StaticMessageIdMultisigIsmFactory)
# Do arquivo agent-config.docker-testnet.json
ISM_FACTORY="0x0D96aF0c01c4bbbadaaF989Eb489c8783F35B763"

# Validator e threshold (mesmo do Solana)
TERRA_VALIDATOR="0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0"
THRESHOLD=1

# Verificar se cast está disponível
if ! command -v cast &> /dev/null; then
    print_error "cast não está instalado ou não está no PATH"
    print_info "Instale Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# Verificar se PRIVATE_KEY está definida
if [ -z "$PRIVATE_KEY" ]; then
    print_error "Variável PRIVATE_KEY não definida"
    echo ""
    echo "Defina antes de executar:"
    echo "  export PRIVATE_KEY=0xYOUR_PRIVATE_KEY"
    echo ""
    echo "Ou use:"
    echo "  PRIVATE_KEY=0xYOUR_PRIVATE_KEY $0"
    echo ""
    exit 1
fi

print_header "CORRIGIR ISM DO SEPOLIA - MESSAGEIDMULTISIGISM"

print_info "Configurações:"
print_value "Warp Route Sepolia: $WARP_ROUTE_SEPOLIA"
print_value "ISM Factory: $ISM_FACTORY"
print_value "Domain: $TERRA_DOMAIN (Terra Classic)"
print_value "Validator: $TERRA_VALIDATOR"
print_value "Threshold: $THRESHOLD"
echo ""

# ============================================================================
# VERIFICAR ISM ATUAL
# ============================================================================

print_info "Verificando ISM atual do Warp Route..."
CURRENT_ISM=$(cast call "$WARP_ROUTE_SEPOLIA" "interchainSecurityModule()" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")

if echo "$CURRENT_ISM" | grep -qiE "0x[0-9a-f]{40}"; then
    CURRENT_ISM_CLEAN=$(echo "$CURRENT_ISM" | grep -oE "0x[0-9a-f]+" | head -1 | sed 's/^0x//' | sed 's/^0*//')
    while [ ${#CURRENT_ISM_CLEAN} -lt 40 ]; do
        CURRENT_ISM_CLEAN="0$CURRENT_ISM_CLEAN"
    done
    CURRENT_ISM="0x$CURRENT_ISM_CLEAN"
    print_info "ISM atual: $CURRENT_ISM"
    
    # Verificar tipo do ISM atual
    ISM_TYPE=$(cast call "$CURRENT_ISM" "moduleType()" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
    ISM_TYPE_DEC=$(cast --to-dec "$ISM_TYPE" 2>/dev/null || echo "$ISM_TYPE")
    
    case "$ISM_TYPE_DEC" in
        "1")
            print_warning "⚠️  ISM atual é DomainRoutingISM (tipo 1)"
            print_info "Isso está ERRADO! Deveria ser MessageIdMultisigIsm (tipo 5)"
            ;;
        "5")
            print_success "✅ ISM atual já é MessageIdMultisigIsm (tipo 5)"
            print_info "Verificando se está configurado corretamente..."
            ;;
        *)
            print_warning "⚠️  Tipo desconhecido: $ISM_TYPE_DEC"
            ;;
    esac
else
    print_warning "⚠️  Não foi possível consultar ISM atual"
fi
echo ""

# ============================================================================
# CRIAR NOVO ISM MESSAGEIDMULTISIG
# ============================================================================

print_info "Criando novo MessageIdMultisigIsm..."
print_info "Factory: $ISM_FACTORY"
print_value "Validators: [$TERRA_VALIDATOR]"
print_value "Threshold: $THRESHOLD"
print_info "Nota: O ISM criado será genérico (não vinculado a um domain específico)"
print_info "O domain será usado quando o relayer consultar o ISM"
echo ""

# Verificar se o ISM já existe (Create2 determinístico)
print_info "Verificando se o ISM já existe (Create2 determinístico)..."
GET_ADDRESS_PRE_CHECK=$(cast call "$ISM_FACTORY" "getAddress(address[],uint8)" "[$TERRA_VALIDATOR]" "$THRESHOLD" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
    ISM_EXISTS=false
    NEW_ISM_ADDRESS=""
    
    if echo "$GET_ADDRESS_PRE_CHECK" | grep -qiE "0x[0-9a-f]+"; then
    PRE_CHECK_ADDRESS_RAW=$(echo "$GET_ADDRESS_PRE_CHECK" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
    if [ ! -z "$PRE_CHECK_ADDRESS_RAW" ]; then
        PRE_CHECK_ADDRESS_CLEAN=$(echo "$PRE_CHECK_ADDRESS_RAW" | sed 's/^0x//' | sed 's/^0*//')
        while [ ${#PRE_CHECK_ADDRESS_CLEAN} -lt 40 ]; do
            PRE_CHECK_ADDRESS_CLEAN="0$PRE_CHECK_ADDRESS_CLEAN"
        done
        PRE_CHECK_ADDRESS="0x$PRE_CHECK_ADDRESS_CLEAN"
        
        PRE_CHECK_CODE=$(cast code "$PRE_CHECK_ADDRESS" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
        if echo "$PRE_CHECK_CODE" | grep -qiE "^0x[0-9a-f]+" && [ "$PRE_CHECK_CODE" != "0x" ]; then
            ISM_EXISTS=true
            NEW_ISM_ADDRESS="$PRE_CHECK_ADDRESS"
            print_success "✅ ISM já existe na blockchain: $NEW_ISM_ADDRESS"
            print_value "Explorer: https://sepolia.etherscan.io/address/$NEW_ISM_ADDRESS"
            print_info "A factory reutilizará este ISM (Create2 determinístico)"
        else
            print_info "ISM ainda não existe. Será criado na transação..."
            print_value "Endereço calculado: $PRE_CHECK_ADDRESS"
            NEW_ISM_ADDRESS="$PRE_CHECK_ADDRESS"
        fi
    fi
    fi
fi

# Se não temos factory, não podemos criar novo ISM
if [ -z "$NEW_ISM_ADDRESS" ] && [ "$ISM_EXISTS" != "true" ]; then
    print_error "❌ Não é possível criar novo ISM sem a factory"
    print_info "Você precisa deployar a factory primeiro ou fornecer um ISM existente"
    echo ""
    read -p "Digite o endereço de um ISM MessageIdMultisigIsm existente (ou Enter para cancelar): " NEW_ISM_ADDRESS
    if [ -z "$NEW_ISM_ADDRESS" ]; then
        print_info "Operação cancelada"
        exit 0
    fi
    # Validar formato
    if [[ ! "$NEW_ISM_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        print_error "Endereço inválido!"
        exit 1
    fi
    # Verificar se é MessageIdMultisigIsm
    EXISTING_ISM_TYPE=$(cast call "$NEW_ISM_ADDRESS" "moduleType()" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
    EXISTING_ISM_TYPE_DEC=$(cast --to-dec "$EXISTING_ISM_TYPE" 2>/dev/null || echo "$EXISTING_ISM_TYPE")
    if [ "$EXISTING_ISM_TYPE_DEC" != "5" ]; then
        print_error "❌ O ISM fornecido não é MessageIdMultisigIsm (tipo: $EXISTING_ISM_TYPE_DEC)"
        exit 1
    fi
    print_success "✅ ISM existente validado: $NEW_ISM_ADDRESS"
    ISM_EXISTS=true
fi

# Preparar calldata para criar ISM (se necessário)
if [ "$ISM_EXISTS" = false ] && [ ! -z "$ISM_FACTORY" ] && echo "$FACTORY_CODE" | grep -qiE "^0x[0-9a-f]+"; then
print_info "Preparando calldata para criar novo ISM..."
DEPLOY_CALLDATA=$(cast calldata "deploy(address[],uint8)" "[$TERRA_VALIDATOR]" "$THRESHOLD" 2>&1 || echo "")

if [ ! -z "$DEPLOY_CALLDATA" ] && echo "$DEPLOY_CALLDATA" | grep -qiE "^0x[0-9a-f]+"; then
    print_success "✅ Calldata preparado"
else
    print_error "❌ Erro ao preparar calldata"
    exit 1
fi
echo ""

# Confirmar
print_warning "⚠️  ATENÇÃO: Esta operação irá:"
print_value "1. Criar um novo MessageIdMultisigIsm no Sepolia (se não existir)"
print_value "2. Atualizar o Warp Route para usar o novo ISM"
echo ""
print_info "Nova configuração:"
print_value "Domain: $TERRA_DOMAIN (Terra Classic)"
print_value "Validator: $TERRA_VALIDATOR"
print_value "Threshold: $THRESHOLD"
echo ""

read -p "Deseja continuar? (sim/não): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Ss][Ii][Mm]$ ]]; then
    print_info "Operação cancelada pelo usuário"
    exit 0
fi
echo ""

# Executar transação para criar ISM (se não existir e factory existe)
if [ "$ISM_EXISTS" = false ] && [ ! -z "$ISM_FACTORY" ] && echo "$FACTORY_CODE" | grep -qiE "^0x[0-9a-f]+"; then
    print_info "Enviando transação para criar novo ISM..."
    print_value "Factory: $ISM_FACTORY"
    print_value "RPC: $SEPOLIA_RPC"
    echo ""
    
    DEPLOY_RESULT=$(cast send "$ISM_FACTORY" "$DEPLOY_CALLDATA" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$SEPOLIA_RPC" \
        2>&1 || echo "ERROR")
    
    if echo "$DEPLOY_RESULT" | grep -qi "error\|ERROR\|reverted\|failed"; then
        print_error "❌ Erro ao criar ISM:"
        echo "$DEPLOY_RESULT"
        exit 1
    fi
    
    # Extrair hash da transação
    TX_HASH=$(echo "$DEPLOY_RESULT" | grep -oE "0x[0-9a-f]{64}" | head -1 || echo "")
    
    if [ ! -z "$TX_HASH" ]; then
        print_success "✅ Transação enviada com sucesso!"
        print_value "Tx Hash: $TX_HASH"
        print_value "Explorer: https://sepolia.etherscan.io/tx/$TX_HASH"
        echo ""
        
        print_info "Aguardando confirmação da transação..."
        sleep 5
        
        # Verificar se o ISM foi criado
        if [ ! -z "$NEW_ISM_ADDRESS" ]; then
            ISM_CODE=$(cast code "$NEW_ISM_ADDRESS" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
            if echo "$ISM_CODE" | grep -qiE "^0x[0-9a-f]+" && [ "$ISM_CODE" != "0x" ]; then
                print_success "✅ ISM criado: $NEW_ISM_ADDRESS"
            else
                print_warning "⚠️  ISM ainda não está disponível. Pode levar alguns blocos."
                print_info "Endereço calculado: $NEW_ISM_ADDRESS"
            fi
        fi
    else
        print_error "❌ Não foi possível extrair o hash da transação"
        echo "$DEPLOY_RESULT"
        exit 1
    fi
fi

# Se ainda não temos o endereço, calcular usando getAddress
if [ -z "$NEW_ISM_ADDRESS" ]; then
    print_info "Calculando endereço do ISM usando getAddress da factory..."
    GET_ADDRESS_RESULT=$(cast call "$ISM_FACTORY" "getAddress(address[],uint8)" "[$TERRA_VALIDATOR]" "$THRESHOLD" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
    
    if echo "$GET_ADDRESS_RESULT" | grep -qiE "0x[0-9a-f]+"; then
        GET_ADDRESS_RAW=$(echo "$GET_ADDRESS_RESULT" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
        if [ ! -z "$GET_ADDRESS_RAW" ]; then
            GET_ADDRESS_CLEAN=$(echo "$GET_ADDRESS_RAW" | sed 's/^0x//' | sed 's/^0*//')
            while [ ${#GET_ADDRESS_CLEAN} -lt 40 ]; do
                GET_ADDRESS_CLEAN="0$GET_ADDRESS_CLEAN"
            done
            NEW_ISM_ADDRESS="0x$GET_ADDRESS_CLEAN"
            print_success "✅ Endereço do ISM: $NEW_ISM_ADDRESS"
        fi
    fi
fi

if [ -z "$NEW_ISM_ADDRESS" ]; then
    print_error "❌ Não foi possível obter o endereço do novo ISM"
    exit 1
fi

echo ""

# ============================================================================
# VERIFICAR TIPO DO NOVO ISM
# ============================================================================

print_info "Verificando tipo do novo ISM..."
NEW_ISM_TYPE=$(cast call "$NEW_ISM_ADDRESS" "moduleType()" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
NEW_ISM_TYPE_DEC=$(cast --to-dec "$NEW_ISM_TYPE" 2>/dev/null || echo "$NEW_ISM_TYPE")

if [ "$NEW_ISM_TYPE_DEC" = "5" ]; then
    print_success "✅ ISM é MessageIdMultisigIsm (tipo 5) - CORRETO!"
else
    print_warning "⚠️  Tipo do ISM: $NEW_ISM_TYPE_DEC (esperado: 5)"
fi
echo ""

# ============================================================================
# ATUALIZAR WARP ROUTE
# ============================================================================

print_info "Atualizando Warp Route para usar o novo ISM..."
print_value "Warp Route: $WARP_ROUTE_SEPOLIA"
print_value "Novo ISM: $NEW_ISM_ADDRESS"
echo ""

# Preparar calldata para atualizar ISM
SET_ISM_CALLDATA=$(cast calldata "setInterchainSecurityModule(address)" "$NEW_ISM_ADDRESS" 2>&1 || echo "")

if [ ! -z "$SET_ISM_CALLDATA" ] && echo "$SET_ISM_CALLDATA" | grep -qiE "^0x[0-9a-f]+"; then
    print_success "✅ Calldata preparado"
else
    print_error "❌ Erro ao preparar calldata para atualizar ISM"
    exit 1
fi
echo ""

# Executar transação para atualizar Warp Route
print_info "Enviando transação para atualizar Warp Route..."
UPDATE_RESULT=$(cast send "$WARP_ROUTE_SEPOLIA" "$SET_ISM_CALLDATA" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$SEPOLIA_RPC" \
    2>&1 || echo "ERROR")

if echo "$UPDATE_RESULT" | grep -qi "error\|ERROR\|reverted\|failed"; then
    print_error "❌ Erro ao atualizar Warp Route:"
    echo "$UPDATE_RESULT"
    exit 1
fi

# Extrair hash
TX_HASH=$(echo "$UPDATE_RESULT" | grep -oE "0x[0-9a-f]{64}" | head -1 || echo "")
if [ ! -z "$TX_HASH" ]; then
    print_success "✅ Transação enviada com sucesso!"
    print_value "Tx Hash: $TX_HASH"
    print_value "Explorer: https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
    
    print_info "Aguardando confirmação..."
    sleep 5
    
    # Verificar novo ISM
    NEW_ISM_CHECK=$(cast call "$WARP_ROUTE_SEPOLIA" "interchainSecurityModule()" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
    if echo "$NEW_ISM_CHECK" | grep -qiE "0x[0-9a-f]+"; then
        ISM_RAW=$(echo "$NEW_ISM_CHECK" | grep -oE "0x[0-9a-f]+" | head -1)
        ISM_CLEAN=$(echo "$ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
        while [ ${#ISM_CLEAN} -lt 40 ]; do
            ISM_CLEAN="0$ISM_CLEAN"
        done
        CURRENT_ISM="0x$ISM_CLEAN"
        
        NEW_ISM_LOWER=$(echo "$NEW_ISM_ADDRESS" | tr '[:upper:]' '[:lower:]')
        CURRENT_ISM_LOWER=$(echo "$CURRENT_ISM" | tr '[:upper:]' '[:lower:]')
        
        if [ "$NEW_ISM_LOWER" = "$CURRENT_ISM_LOWER" ]; then
            print_success "✅ Warp Route atualizado com sucesso!"
            print_value "Novo ISM: $CURRENT_ISM"
            
            # Verificar tipo do ISM atualizado
            FINAL_ISM_TYPE=$(cast call "$CURRENT_ISM" "moduleType()" --rpc-url "$SEPOLIA_RPC" 2>&1 || echo "")
            FINAL_ISM_TYPE_DEC=$(cast --to-dec "$FINAL_ISM_TYPE" 2>/dev/null || echo "$FINAL_ISM_TYPE")
            
            if [ "$FINAL_ISM_TYPE_DEC" = "5" ]; then
                print_success "✅ ISM é MessageIdMultisigIsm (tipo 5) - CORRETO!"
                echo ""
                print_success "✅ Configuração concluída com sucesso!"
                print_info "O Sepolia agora está configurado igual ao Solana:"
                print_value "  - ISM: MessageIdMultisigIsm (tipo 5)"
                print_value "  - Validator: $TERRA_VALIDATOR"
                print_value "  - Threshold: $THRESHOLD"
                print_value "  - Domain: $TERRA_DOMAIN (Terra Classic)"
            else
                print_warning "⚠️  Tipo do ISM: $FINAL_ISM_TYPE_DEC (esperado: 5)"
            fi
        else
            print_warning "⚠️  ISM diferente do esperado"
            print_value "Esperado: $NEW_ISM_ADDRESS"
            print_value "Encontrado: $CURRENT_ISM"
        fi
    fi
else
    print_error "Não foi possível obter o hash da transação"
    exit 1
fi

echo ""
print_success "✅ Operação concluída!"
