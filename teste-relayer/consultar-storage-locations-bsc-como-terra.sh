#!/bin/bash

# ============================================================================
# Script: Consultar Storage Locations no BSC usando a mesma lógica do Terra Classic
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

print_header "CONSULTAR STORAGE LOCATIONS NO BSC (MESMA LÓGICA DO TERRA CLASSIC)"

print_info "ValidatorAnnounce BSC: $VALIDATOR_ANNOUNCE_BSC"
print_info "RPC: $BSC_RPC"
echo ""

# ============================================================================
# PASSO 1: Obter Lista de Validators Anunciados
# ============================================================================

print_section "PASSO 1: OBTER VALIDATORS ANUNCIADOS"

print_info "Consultando getAnnouncedValidators()..."

ANNOUNCED_VALIDATORS_RAW=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedValidators()" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$ANNOUNCED_VALIDATORS_RAW" | grep -qi "error"; then
    print_error "❌ Erro ao consultar validators anunciados"
    echo "$ANNOUNCED_VALIDATORS_RAW"
    exit 1
fi

# Decodificar lista de validators
ANNOUNCED_VALIDATORS=$(cast --abi-decode "getAnnouncedValidators()(address[])" "$ANNOUNCED_VALIDATORS_RAW" 2>/dev/null || echo "")

if [ -z "$ANNOUNCED_VALIDATORS" ]; then
    print_error "❌ Não foi possível decodificar validators"
    exit 1
fi

# Converter para array
ALL_VALIDATORS=($(echo "$ANNOUNCED_VALIDATORS" | grep -oE "0x[a-fA-F0-9]{40}"))

print_success "✅ Total de validators anunciados: ${#ALL_VALIDATORS[@]}"
echo ""

# ============================================================================
# PASSO 2: Consultar Storage Locations usando a mesma lógica do Terra Classic
# ============================================================================

print_section "PASSO 2: CONSULTAR STORAGE LOCATIONS (LÓGICA TERRA CLASSIC)"

echo "{"
echo "  \"validatorAnnounce\": \"$VALIDATOR_ANNOUNCE_BSC\","
echo "  \"rpc\": \"$BSC_RPC\","
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"method\": \"getAnnounceStorageLocations (como Terra Classic)\","
echo "  \"data\": {"
echo "    \"storage_locations\": ["

# Processar validators do ISM
FIRST=true
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    print_info "Consultando storage location para: $VALIDATOR"
    
    # Remover 0x para a query (como no Terra Classic)
    VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
    
    # No BSC, a função equivalente seria getAnnounceStorageLocations(address[] memory validators)
    # Mas vamos tentar com um único validator de cada vez
    # A função no BSC pode ser diferente - vamos tentar várias variações
    
    # Tentativa 1: getAnnounceStorageLocations(address[])
    STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnounceStorageLocations(address[])" \
        "[$VALIDATOR]" \
        --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    
    # Tentativa 2: Se falhar, tentar getAnnouncedStorageLocations(address)
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
            "getAnnouncedStorageLocations(address)" \
            "$VALIDATOR" \
            --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    fi
    
    echo "      ["
    echo "        \"$VALIDATOR_CLEAN\","
    echo "        ["
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        print_warning "  ⚠️  Erro ao consultar storage location"
        echo "      ]"
    else
        # Tentar decodificar como string[]
        STORAGE_DECODED=$(cast --abi-decode "getAnnounceStorageLocations(address[])(tuple(address,string[])[])" "$STORAGE_RESPONSE" 2>/dev/null || \
            cast --abi-decode "getAnnouncedStorageLocations(address)(string[])" "$STORAGE_RESPONSE" 2>/dev/null || echo "")
        
        if [ ! -z "$STORAGE_DECODED" ] && [ "$STORAGE_DECODED" != "()" ]; then
            # Extrair storage locations (s3://...)
            STORAGE_S3=$(echo "$STORAGE_DECODED" | grep -oE "s3://[^ ]+" || echo "")
            
            if [ ! -z "$STORAGE_S3" ]; then
                # Converter para array JSON
                FIRST_STORAGE=true
                echo "$STORAGE_S3" | while read -r storage; do
                    if [ "$FIRST_STORAGE" = false ]; then
                        echo ","
                    fi
                    FIRST_STORAGE=false
                    echo -n "          \"$storage\""
                done
                echo ""
                print_success "  ✅ Storage location encontrada: $STORAGE_S3"
            else
                print_warning "  ⚠️  Storage location não encontrada na resposta"
            fi
        else
            print_warning "  ⚠️  Não foi possível decodificar storage location"
        fi
        echo "      ]"
    fi
    
    echo -n "      ]"
done

echo ""
echo "    ]"
echo "  }"
echo "}"

