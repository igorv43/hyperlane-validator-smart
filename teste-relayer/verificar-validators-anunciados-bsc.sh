#!/bin/bash

# ============================================================================
# Script: Verificar se Validators estão Anunciados no ValidatorAnnounce BSC
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}ℹ️${NC}  $1"; }
print_success() { echo -e "${GREEN}✅${NC}  $1"; }
print_error() { echo -e "${RED}❌${NC}  $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC}  $1"; }
print_value() { echo -e "  ${YELLOW}$1${NC}"; }

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Validators do ISM
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

# ============================================================================
# INÍCIO
# ============================================================================

print_header "VERIFICAR VALIDATORS ANUNCIADOS NO VALIDATORANNOUNCE BSC"

print_info "Configurações:"
print_value "ValidatorAnnounce BSC: $VALIDATOR_ANNOUNCE_BSC"
print_value "RPC: $BSC_RPC"
echo ""

# ============================================================================
# PASSO 1: Obter lista de validators anunciados
# ============================================================================

print_section "PASSO 1: OBTER LISTA DE VALIDATORS ANUNCIADOS"

print_info "Consultando ValidatorAnnounce para obter lista de validators..."

# Consultar getAnnouncedValidators()
ANNOUNCED_RESPONSE=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedValidators()" \
    --rpc-url "$BSC_RPC" 2>&1 || echo "")

if [ -z "$ANNOUNCED_RESPONSE" ] || echo "$ANNOUNCED_RESPONSE" | grep -qi "error"; then
    print_error "❌ Erro ao consultar ValidatorAnnounce"
    echo "$ANNOUNCED_RESPONSE"
    exit 1
fi

# Decodificar a resposta (array de endereços)
# A resposta vem em formato ABI-encoded: offset (32 bytes) + length (32 bytes) + addresses (64 bytes cada)
print_info "Decodificando resposta ABI..."

# Extrair endereços da resposta ABI
# Formato: cada endereço está em um bloco de 64 bytes (32 bytes padding + 20 bytes address)
# Remover 0x, dividir em blocos de 64 caracteres hex, pegar últimos 40 caracteres de cada bloco
ANNOUNCED_VALIDATORS=$(echo "$ANNOUNCED_RESPONSE" | sed 's/^0x//' | fold -w 64 | tail -n +3 | sed 's/.*\(.\{40\}\)$/0x\1/' | sort -u)

if [ -z "$ANNOUNCED_VALIDATORS" ]; then
    print_warning "⚠️  Nenhum validator encontrado na resposta"
    print_info "Resposta bruta: $ANNOUNCED_RESPONSE"
else
    ANNOUNCED_COUNT=$(echo "$ANNOUNCED_VALIDATORS" | wc -l)
    print_success "✅ Encontrados $ANNOUNCED_COUNT validators anunciados"
fi

echo ""

# ============================================================================
# PASSO 2: Verificar cada validator do ISM
# ============================================================================

print_section "PASSO 2: VERIFICAR VALIDATORS DO ISM"

print_info "Verificando se validators do ISM estão anunciados..."
echo ""

FOUND_COUNT=0
NOT_FOUND_COUNT=0

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    # Normalizar endereço (lowercase)
    VALIDATOR_LOWER=$(echo "$VALIDATOR" | tr '[:upper:]' '[:lower:]')
    
    # Verificar se está na lista
    if echo "$ANNOUNCED_VALIDATORS" | grep -qi "$VALIDATOR_LOWER"; then
        print_success "✅ $VALIDATOR - ANUNCIADO"
        FOUND_COUNT=$((FOUND_COUNT + 1))
        
        # Consultar informações do anúncio
        print_info "   Consultando informações do anúncio..."
        ANNOUNCE_INFO=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
            "getAnnouncedStorageLocations(address)" \
            "$VALIDATOR" \
            --rpc-url "$BSC_RPC" 2>&1 || echo "")
        
        if echo "$ANNOUNCE_INFO" | grep -qi "error"; then
            print_warning "   ⚠️  Não foi possível obter informações do anúncio"
        else
            # Tentar extrair storage location
            STORAGE=$(echo "$ANNOUNCE_INFO" | grep -oE "s3://[^ ]+" || echo "")
            if [ ! -z "$STORAGE" ]; then
                print_value "   Storage: $STORAGE"
            fi
        fi
    else
        print_error "❌ $VALIDATOR - NÃO ANUNCIADO"
        NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
    fi
    echo ""
done

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO"

print_info "Validators do ISM: ${#VALIDATORS_ISM[@]}"
print_success "✅ Anunciados: $FOUND_COUNT"
print_error "❌ Não anunciados: $NOT_FOUND_COUNT"
echo ""

if [ $NOT_FOUND_COUNT -gt 0 ]; then
    print_warning "⚠️  ATENÇÃO: $NOT_FOUND_COUNT validator(s) não estão anunciados!"
    print_info "Para que o relayer processe mensagens BSC -> Terra Classic,"
    print_info "todos os validators precisam estar anunciados no ValidatorAnnounce do BSC."
    echo ""
    print_info "Cada validator precisa chamar:"
    print_value "  cast send $VALIDATOR_ANNOUNCE_BSC \\"
    print_value "    \"announce(string,string)\" \\"
    print_value "    \"s3://bucket-name\" \\"
    print_value "    \"0xsignature\" \\"
    print_value "    --rpc-url $BSC_RPC \\"
    print_value "    --private-key 0x..."
else
    print_success "✅ Todos os validators estão anunciados!"
fi

echo ""

# ============================================================================
# LISTA COMPLETA DE VALIDATORS ANUNCIADOS
# ============================================================================

if [ ! -z "$ANNOUNCED_VALIDATORS" ]; then
    print_section "LISTA COMPLETA DE VALIDATORS ANUNCIADOS"
    
    echo "$ANNOUNCED_VALIDATORS" | while read -r validator; do
        if [ ! -z "$validator" ]; then
            print_value "  - $validator"
        fi
    done
    echo ""
fi

print_success "✅ Verificação concluída!"
