#!/bin/bash

# ============================================================================
# Script: Consultar ValidatorAnnounce do Terra Classic para Obter Buckets S3
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

# ValidatorAnnounce do Terra Classic (precisamos descobrir o endereço)
# Tentando o endereço do exemplo fornecido
VALIDATOR_ANNOUNCE_TERRA="terra1e604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"
TERRA_RPC="https://rpc.luncblaze.com:443"
TERRA_CHAIN_ID="rebel-2"

# Validators do ISM (convertendo para formato Terra se necessário)
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

# ============================================================================
# INÍCIO
# ============================================================================

print_header "CONSULTAR VALIDATORANNOUNCE DO TERRA CLASSIC"

print_info "Consultando ValidatorAnnounce do Terra Classic para obter buckets S3"
print_value "Contrato: $VALIDATOR_ANNOUNCE_TERRA"
print_value "RPC: $TERRA_RPC"
echo ""

# ============================================================================
# PASSO 1: Consultar Todos os Validators Anunciados
# ============================================================================

print_section "PASSO 1: CONSULTAR TODOS OS VALIDATORS ANUNCIADOS"

print_info "Consultando announced_validators..."

QUERY_VALIDATORS='{"announced_validators": {}}'

VALIDATORS_RESPONSE=$(terrad query wasm contract-state smart \
    "$VALIDATOR_ANNOUNCE_TERRA" \
    "$QUERY_VALIDATORS" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1)

if echo "$VALIDATORS_RESPONSE" | grep -qi "error"; then
    print_error "❌ Erro ao consultar validators anunciados:"
    echo "$VALIDATORS_RESPONSE"
    exit 1
fi

print_success "✅ Resposta obtida"
echo "$VALIDATORS_RESPONSE" | jq '.' 2>/dev/null || echo "$VALIDATORS_RESPONSE"
echo ""

# ============================================================================
# PASSO 2: Consultar Storage Locations dos Validators do ISM
# ============================================================================

print_section "PASSO 2: CONSULTAR STORAGE LOCATIONS DOS VALIDATORS DO ISM"

declare -A STORAGE_LOCATIONS

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    print_info "Consultando storage location para: $VALIDATOR"
    
    QUERY_STORAGE='{"announced_storage_location": {"validator": "'"$VALIDATOR"'"}}'
    
    STORAGE_RESPONSE=$(terrad query wasm contract-state smart \
        "$VALIDATOR_ANNOUNCE_TERRA" \
        "$QUERY_STORAGE" \
        --chain-id "$TERRA_CHAIN_ID" \
        --node "$TERRA_RPC" \
        --output json 2>&1)
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error"; then
        print_warning "⚠️  Erro ao consultar storage location:"
        echo "$STORAGE_RESPONSE" | head -3
        STORAGE_LOCATIONS["$VALIDATOR"]="ERRO"
    else
        # Extrair storage location da resposta
        STORAGE=$(echo "$STORAGE_RESPONSE" | jq -r '.data.storage_location // .data // empty' 2>/dev/null || echo "")
        
        if [ ! -z "$STORAGE" ] && [ "$STORAGE" != "null" ]; then
            STORAGE_LOCATIONS["$VALIDATOR"]="$STORAGE"
            print_success "  ✅ Storage location: $STORAGE"
        else
            print_warning "  ⚠️  Storage location não encontrada"
            echo "$STORAGE_RESPONSE" | jq '.' 2>/dev/null || echo "$STORAGE_RESPONSE"
            STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
        fi
    fi
    
    echo ""
done

# ============================================================================
# PASSO 3: Consultar Todas as Storage Locations
# ============================================================================

print_section "PASSO 3: CONSULTAR TODAS AS STORAGE LOCATIONS"

print_info "Consultando announced_storage_locations..."

QUERY_ALL_STORAGE='{"announced_storage_locations": {}}'

ALL_STORAGE_RESPONSE=$(terrad query wasm contract-state smart \
    "$VALIDATOR_ANNOUNCE_TERRA" \
    "$QUERY_ALL_STORAGE" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1)

if echo "$ALL_STORAGE_RESPONSE" | grep -qi "error"; then
    print_warning "⚠️  Erro ao consultar todas as storage locations:"
    echo "$ALL_STORAGE_RESPONSE" | head -5
else
    print_success "✅ Resposta obtida"
    echo "$ALL_STORAGE_RESPONSE" | jq '.' 2>/dev/null || echo "$ALL_STORAGE_RESPONSE"
fi

echo ""

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO"

print_info "Storage locations dos validators do ISM:"
echo ""

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    STORAGE="${STORAGE_LOCATIONS[$VALIDATOR]}"
    echo -e "${CYAN}Validator:${NC} $VALIDATOR"
    if [ "$STORAGE" != "ERRO" ] && [ "$STORAGE" != "NÃO ENCONTRADO" ]; then
        print_success "  ✅ Storage Location: $STORAGE"
    else
        print_warning "  ⚠️  Storage Location: $STORAGE"
    fi
    echo ""
done

print_success "✅ Script concluído!"

