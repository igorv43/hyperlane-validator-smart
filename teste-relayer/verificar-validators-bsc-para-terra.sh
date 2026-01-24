#!/bin/bash

# ============================================================================
# Script: Verificar Validators do BSC para Mensagens BSC -> Terra Classic
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

# Validators do ISM (configurados no Terra Classic para validar mensagens do BSC)
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

# ============================================================================
# INÍCIO
# ============================================================================

print_header "VERIFICAR VALIDATORS DO BSC PARA MENSAGENS BSC -> TERRA CLASSIC"

print_info "Para mensagens BSC -> Terra Classic:"
print_value "  • Relayer consulta ValidatorAnnounce do BSC (origem)"
print_value "  • Validators do BSC geram checkpoints"
print_value "  • Relayer lê checkpoints do S3 dos validators do BSC"
print_value "  • Relayer valida usando ISM do Terra Classic (destino)"
echo ""

# ============================================================================
# PASSO 1: Verificar se Validators Estão Anunciados no BSC
# ============================================================================

print_section "PASSO 1: VALIDATORS ANUNCIADOS NO BSC"

print_info "Consultando ValidatorAnnounce do BSC..."

ANNOUNCED_VALIDATORS_RAW=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedValidators()" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$ANNOUNCED_VALIDATORS_RAW" | grep -qi "error"; then
    print_error "❌ Erro ao consultar validators anunciados"
    exit 1
fi

ALL_VALIDATORS=($(cast --abi-decode "getAnnouncedValidators()(address[])" "$ANNOUNCED_VALIDATORS_RAW" 2>/dev/null | grep -oE "0x[a-fA-F0-9]{40}"))

print_success "✅ Total de validators anunciados no BSC: ${#ALL_VALIDATORS[@]}"
echo ""

# Verificar validators do ISM
print_info "Verificando validators do ISM no BSC ValidatorAnnounce..."
echo ""

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    VALIDATOR_LOWER=$(echo "$VALIDATOR" | tr '[:upper:]' '[:lower:]')
    IS_ANNOUNCED=false
    
    for ANNOUNCED in "${ALL_VALIDATORS[@]}"; do
        ANNOUNCED_LOWER=$(echo "$ANNOUNCED" | tr '[:upper:]' '[:lower:]')
        if [ "$ANNOUNCED_LOWER" == "$VALIDATOR_LOWER" ]; then
            IS_ANNOUNCED=true
            break
        fi
    done
    
    if [ "$IS_ANNOUNCED" = true ]; then
        print_success "✅ $VALIDATOR - Anunciado no BSC"
    else
        print_error "❌ $VALIDATOR - NÃO anunciado no BSC"
    fi
done

echo ""

# ============================================================================
# PASSO 2: Verificar Storage Locations no BSC
# ============================================================================

print_section "PASSO 2: STORAGE LOCATIONS NO BSC VALIDATORANNOUNCE"

print_info "Consultando storage locations dos validators do ISM no BSC..."
echo ""

echo "{"
echo "  \"validatorAnnounce\": \"$VALIDATOR_ANNOUNCE_BSC\","
echo "  \"rpc\": \"$BSC_RPC\","
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"note\": \"Para mensagens BSC -> Terra Classic, relayer consulta ValidatorAnnounce do BSC\","
echo "  \"data\": {"
echo "    \"storage_locations\": ["

FIRST=true
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
    
    echo "      ["
    echo "        \"$VALIDATOR_CLEAN\","
    echo "        ["
    
    # Consultar storage location no BSC
    STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedStorageLocations(address)" \
        "$VALIDATOR" \
        --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        # Array vazio se não encontrar
        print_warning "  ⚠️  $VALIDATOR - Sem storage location anunciada no BSC"
    else
        # Tentar decodificar
        STORAGE_DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address)(string[])" "$STORAGE_RESPONSE" 2>/dev/null || echo "")
        
        if [ ! -z "$STORAGE_DECODED" ] && [ "$STORAGE_DECODED" != "()" ]; then
            STORAGE_S3=$(echo "$STORAGE_DECODED" | grep -oE "s3://[^ ]+" || echo "")
            
            if [ ! -z "$STORAGE_S3" ]; then
                echo "          \"$STORAGE_S3\""
                print_success "  ✅ $VALIDATOR - Storage location: $STORAGE_S3"
            else
                print_warning "  ⚠️  $VALIDATOR - Storage location vazia"
            fi
        else
            print_warning "  ⚠️  $VALIDATOR - Não foi possível decodificar storage location"
        fi
    fi
    
    echo "        ]"
    echo -n "      ]"
done

echo ""
echo "    ]"
echo "  }"
echo "}"
