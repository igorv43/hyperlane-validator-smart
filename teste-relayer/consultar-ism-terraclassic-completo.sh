#!/bin/bash

# ============================================================================
# Script: Consultar ISM do Terra Classic para Domain 97 (BSC) - Completo
# ============================================================================
# Este script:
# 1. Consulta o routing ISM para obter o ISM configurado para domain 97
# 2. Consulta esse ISM para obter validators e threshold
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

ISM_TERRA="terra1na6ljyf4m5x2u7llfvvxxe2nyq0t8628qyk0vnwu4ttpq86tt0cse47t68"
ISM_MULTISIG_BSC="terra1ksq6cekt0as2f9vv5txld90s854y4pkr2k0jn5p83vqpa5zzzfysuavxr0"
WARP_ROUTE="terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml"
DOMAIN_97="97"
TERRA_RPC="https://rpc.luncblaze.com:443"
TERRA_CHAIN_ID="rebel-2"

# ============================================================================
# INÍCIO
# ============================================================================

print_header "CONSULTAR ISM DO TERRA CLASSIC PARA DOMAIN 97 (BSC)"

print_info "Configurações:"
print_value "ISM Terra Classic (Routing): $ISM_TERRA"
print_value "ISM Multisig BSC: $ISM_MULTISIG_BSC"
print_value "Warp Route: $WARP_ROUTE"
print_value "Domain: $DOMAIN_97 (BSC Testnet)"
print_value "RPC: $TERRA_RPC"
echo ""

# ============================================================================
# CONSULTAR VALIDATORS DO ISM MULTISIG BSC
# ============================================================================

print_section "CONSULTAR VALIDATORS DO ISM MULTISIG BSC"

print_info "Consultando validators inscritos no ISM Multisig BSC:"
print_value "ISM: $ISM_MULTISIG_BSC"

QUERY_VALIDATORS='{"multisig_ism":{"enrolled_validators":{"domain":97}}}'
print_value "Query: $QUERY_VALIDATORS"

VALIDATORS_RESPONSE=$(timeout 30 terrad query wasm contract-state smart \
    "${ISM_MULTISIG_BSC}" \
    "${QUERY_VALIDATORS}" \
    --chain-id "${TERRA_CHAIN_ID}" \
    --node "${TERRA_RPC}" \
    --output json 2>&1 || echo "")

if echo "$VALIDATORS_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    print_success "✅ Query bem-sucedida!"
    echo ""
    echo "$VALIDATORS_RESPONSE" | jq '.'
    
    # Extrair validators
    VALIDATORS=$(echo "$VALIDATORS_RESPONSE" | jq -r '.data.validators // .data.enrolled_validators // empty' 2>/dev/null)
    
    if [ ! -z "$VALIDATORS" ] && [ "$VALIDATORS" != "null" ]; then
        print_success "✅ Validators encontrados:"
        if echo "$VALIDATORS" | jq -e 'type == "array"' > /dev/null 2>&1; then
            echo "$VALIDATORS" | jq -r '.[]' 2>/dev/null | while read -r validator; do
                if [ ! -z "$validator" ]; then
                    print_value "  - $validator"
                fi
            done
        else
            echo "$VALIDATORS" | jq -r 'to_entries[] | .value' 2>/dev/null | while read -r validator; do
                if [ ! -z "$validator" ]; then
                    print_value "  - $validator"
                fi
            done
        fi
    else
        print_warning "⚠️  Nenhum validator encontrado na resposta"
    fi
else
    print_error "❌ Não foi possível consultar validators"
    echo "$VALIDATORS_RESPONSE"
fi

echo ""

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO"

print_success "✅ Informações consultadas:"
echo ""
print_info "ISM Terra Classic (Routing):"
print_value "  Endereço: $ISM_TERRA"
echo ""
print_info "ISM Multisig para Domain 97 (BSC Testnet):"
print_value "  Endereço: $ISM_MULTISIG_BSC"
print_value "  Explorer: https://finder.terraclassic.community/testnet/address/$ISM_MULTISIG_BSC"
echo ""
if [ ! -z "$VALIDATORS" ] && [ "$VALIDATORS" != "null" ]; then
    print_info "Validators configurados:"
    if echo "$VALIDATORS" | jq -e 'type == "array"' > /dev/null 2>&1; then
        echo "$VALIDATORS" | jq -r '.[]' 2>/dev/null | while read -r validator; do
            if [ ! -z "$validator" ]; then
                print_value "  - $validator"
            fi
        done
    fi
fi
echo ""

print_success "✅ Consulta concluída!"
