#!/bin/bash

# ============================================================================
# Script: Consultar ISM do Warp Route BSC
# ============================================================================
# Este script consulta um Warp Route BSC e exibe informações sobre o ISM
# associado, incluindo validators e threshold.
#
# Uso: ./consultar-warp-ism-bsc.sh <warp_route_address>
# Exemplo: ./consultar-warp-ism-bsc.sh 0x2144be4477202ba2d50c9a8be3181241878cf7d8
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

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
# VALIDAÇÃO DE PARÂMETROS
# ============================================================================

if [ $# -eq 0 ]; then
    print_error "Erro: Endereço do Warp Route não fornecido"
    echo ""
    echo "Uso: $0 <warp_route_address>"
    echo ""
    echo "Exemplo:"
    echo "  $0 0x2144be4477202ba2d50c9a8be3181241878cf7d8"
    echo ""
    exit 1
fi

WARP_ROUTE_BSC="$1"

# Validar formato do endereço
if [[ ! "$WARP_ROUTE_BSC" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    print_error "Erro: Endereço inválido. Deve ser um endereço hexadecimal de 40 caracteres com prefixo 0x"
    exit 1
fi

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

BSC_RPC="https://bsc-testnet.publicnode.com"
TERRA_DOMAIN=1325

# Verificar se cast está disponível
if ! command -v cast &> /dev/null; then
    print_error "cast não está instalado ou não está no PATH"
    print_info "Instale Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# ============================================================================
# INÍCIO DO SCRIPT
# ============================================================================

print_header "CONSULTAR ISM DO WARP ROUTE BSC"

print_info "Configurações:"
print_value "Warp Route BSC: $WARP_ROUTE_BSC"
print_value "RPC: $BSC_RPC"
echo ""

# ============================================================================
# 1. CONSULTAR ISM DO WARP ROUTE
# ============================================================================

print_section "1. CONSULTAR ISM DO WARP ROUTE"

print_info "Consultando ISM do Warp Route..."
ISM_QUERY=$(cast call "$WARP_ROUTE_BSC" "interchainSecurityModule()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

if echo "$ISM_QUERY" | grep -qiE "0x[0-9a-f]+"; then
    ISM_RAW=$(echo "$ISM_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
    if [ ! -z "$ISM_RAW" ]; then
        ISM_CLEAN=$(echo "$ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
        while [ ${#ISM_CLEAN} -lt 40 ]; do
            ISM_CLEAN="0$ISM_CLEAN"
        done
        WARP_ISM="0x$ISM_CLEAN"
        print_success "✅ ISM encontrado: $WARP_ISM"
        print_value "Explorer: https://testnet.bscscan.com/address/$WARP_ISM"
    else
        print_error "❌ Não foi possível extrair o endereço do ISM."
        exit 1
    fi
else
    print_error "❌ ISM não encontrado ou erro na consulta."
    echo "$ISM_QUERY"
    exit 1
fi
echo ""

# ============================================================================
# 2. CONSULTAR TIPO DO ISM
# ============================================================================

print_section "2. TIPO DO ISM"

print_info "Consultando tipo do ISM..."
ISM_TYPE=$(cast call "$WARP_ISM" "moduleType()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

ISM_TYPE_DEC=""
ISM_TYPE_NAME=""

if echo "$ISM_TYPE" | grep -qiE "^0x[0-9a-f]+$|^[0-9]+$"; then
    ISM_TYPE_RAW=$(echo "$ISM_TYPE" | grep -oE "^0x[0-9a-f]+$|^[0-9]+$" | head -1 || echo "")
    if [ ! -z "$ISM_TYPE_RAW" ]; then
        if [[ "$ISM_TYPE_RAW" =~ ^0x ]]; then
            ISM_TYPE_DEC=$(cast --to-dec "$ISM_TYPE_RAW" 2>/dev/null || echo "$ISM_TYPE_RAW")
        else
            ISM_TYPE_DEC="$ISM_TYPE_RAW"
        fi
        
        case "$ISM_TYPE_DEC" in
            0) ISM_TYPE_NAME="UNUSED" ;;
            1) ISM_TYPE_NAME="ROUTING" ;;
            2) ISM_TYPE_NAME="AGGREGATION" ;;
            3) ISM_TYPE_NAME="LEGACY_MULTISIG" ;;
            4) ISM_TYPE_NAME="MERKLE_ROOT_MULTISIG" ;;
            5) ISM_TYPE_NAME="MESSAGE_ID_MULTISIG" ;;
            6) ISM_TYPE_NAME="NULL" ;;
            7) ISM_TYPE_NAME="CCIP_READ" ;;
            8) ISM_TYPE_NAME="ARB_L2_TO_L1" ;;
            9) ISM_TYPE_NAME="WEIGHTED_MERKLE_ROOT_MULTISIG" ;;
            10) ISM_TYPE_NAME="WEIGHTED_MESSAGE_ID_MULTISIG" ;;
            11) ISM_TYPE_NAME="OP_L2_TO_L1" ;;
            12) ISM_TYPE_NAME="POLYMER" ;;
            *) ISM_TYPE_NAME="UNKNOWN ($ISM_TYPE_DEC)" ;;
        esac
        
        print_success "✅ Tipo do ISM: $ISM_TYPE_NAME (Type $ISM_TYPE_DEC)"
    fi
else
    print_warning "⚠️  Não foi possível consultar o tipo do ISM"
fi
echo ""

# ============================================================================
# 3. CONSULTAR VALIDATORS E THRESHOLD
# ============================================================================

print_section "3. VALIDATORS E THRESHOLD"

print_info "Consultando validators e threshold do ISM..."
VALIDATORS_AND_THRESHOLD=$(cast call "$WARP_ISM" "validatorsAndThreshold(bytes)" "0x" --rpc-url "$BSC_RPC" 2>&1 || echo "")

VALIDATORS_LIST=""
THRESHOLD_VALUE=""

if echo "$VALIDATORS_AND_THRESHOLD" | grep -qiE "0x[0-9a-f]+"; then
    # Extrair validators - o formato ABI retorna: offset_array, threshold, length_array, validators...
    # Os validators aparecem como valores de 64 bytes, onde os últimos 40 bytes são o endereço
    print_success "✅ Validators encontrados:"
    
    # Criar arquivo temporário para armazenar validators
    TMP_VALIDATORS=$(mktemp)
    
    # Extrair validator - o resultado é uma string contínua
    # O endereço está nos últimos 40 caracteres hex da string (após remover 0x)
    VALIDATOR_HEX=$(echo "$VALIDATORS_AND_THRESHOLD" | sed 's/^0x//' | tr -d '\n' | tr -d ' ')
    if [ ! -z "$VALIDATOR_HEX" ] && [ ${#VALIDATOR_HEX} -ge 40 ]; then
        # Pegar os últimos 40 caracteres hex
        VALIDATOR_RAW=$(echo -n "$VALIDATOR_HEX" | tail -c 40)
        
        if [ ! -z "$VALIDATOR_RAW" ] && [ ${#VALIDATOR_RAW} -eq 40 ]; then
            # Normalizar o endereço (remover zeros à esquerda e garantir 40 caracteres)
            VALIDATOR_CLEAN=$(echo "$VALIDATOR_RAW" | sed 's/^0*//')
            while [ ${#VALIDATOR_CLEAN} -lt 40 ]; do
                VALIDATOR_CLEAN="0$VALIDATOR_CLEAN"
            done
            VALIDATOR="0x$VALIDATOR_CLEAN"
            
            if [ "$VALIDATOR" != "0x0000000000000000000000000000000000000000" ]; then
                print_value "  - $VALIDATOR"
                echo "$VALIDATOR" >> "$TMP_VALIDATORS"
            fi
        fi
    fi
    
    # Ler validators do arquivo temporário
    if [ -s "$TMP_VALIDATORS" ]; then
        VALIDATORS_LIST=$(cat "$TMP_VALIDATORS" | tr '\n' ' ')
    fi
    rm -f "$TMP_VALIDATORS"
    
    # Extrair threshold - o formato ABI: offset (64 bytes), threshold (32 bytes), length (32 bytes), validators...
    # O threshold está nos bytes 64-95 (segundo valor de 32 bytes)
    if [ ! -z "$VALIDATOR_HEX" ] && [ ${#VALIDATOR_HEX} -ge 128 ]; then
        # Pegar o segundo valor de 64 caracteres hex (bytes 64-127)
        THRESHOLD_HEX=$(echo -n "$VALIDATOR_HEX" | head -c 128 | tail -c 64)
        if [ ! -z "$THRESHOLD_HEX" ]; then
            THRESHOLD_DEC=$(cast --to-dec "0x$THRESHOLD_HEX" 2>/dev/null || echo "")
            # Threshold é uint8, então deve ser entre 0 e 255
            if [ ! -z "$THRESHOLD_DEC" ] && [ "$THRESHOLD_DEC" -ge 0 ] && [ "$THRESHOLD_DEC" -le 255 ]; then
                THRESHOLD_VALUE="$THRESHOLD_DEC"
                print_success "✅ Threshold: $THRESHOLD_VALUE"
            fi
        fi
    fi
    
    if [ -z "$THRESHOLD_VALUE" ]; then
        print_warning "⚠️  Threshold não encontrado automaticamente"
    fi
else
    print_warning "⚠️  Validators e threshold não encontrados ou função não disponível"
fi
echo ""

# ============================================================================
# 4. RESUMO FINAL
# ============================================================================

print_section "RESUMO"

print_success "✅ Informações do Warp Route e ISM:"
echo ""
print_info "Warp Route:"
print_value "  Endereço: $WARP_ROUTE_BSC"
print_value "  Explorer: https://testnet.bscscan.com/address/$WARP_ROUTE_BSC"
echo ""
print_info "ISM (Interchain Security Module):"
print_value "  Endereço: $WARP_ISM"
if [ ! -z "$ISM_TYPE_NAME" ]; then
    print_value "  Tipo: $ISM_TYPE_NAME (Type $ISM_TYPE_DEC)"
fi
print_value "  Explorer: https://testnet.bscscan.com/address/$WARP_ISM"
echo ""
print_info "Configuração:"
print_value "  Domain: $TERRA_DOMAIN (Terra Classic)"
if [ -s "$TMP_VALIDATORS" ] 2>/dev/null; then
    print_value "  Validators:"
    while read -r validator; do
        if [ ! -z "$validator" ]; then
            print_value "    - $validator"
        fi
    done < "$TMP_VALIDATORS"
elif [ ! -z "$VALIDATORS_LIST" ]; then
    print_value "  Validators:"
    echo "$VALIDATORS_LIST" | tr ' ' '\n' | while read -r validator; do
        if [ ! -z "$validator" ]; then
            print_value "    - $validator"
        fi
    done
fi
if [ ! -z "$THRESHOLD_VALUE" ]; then
    print_value "  Threshold: $THRESHOLD_VALUE"
fi
echo ""

# ============================================================================
# 5. FORMATO YAML
# ============================================================================

print_section "CONFIGURAÇÃO EM FORMATO YAML"

echo "Warp Route: $WARP_ROUTE_BSC"
echo "Novo ISM: $WARP_ISM"
echo "Explorer ISM: https://testnet.bscscan.com/address/$WARP_ISM"
echo "Domain: $TERRA_DOMAIN (Terra Classic)"
if [ ! -z "$VALIDATORS_LIST" ]; then
    echo "Validators:"
    echo "$VALIDATORS_LIST" | tr ' ' '\n' | while read -r validator; do
        if [ ! -z "$validator" ]; then
            echo "  - $validator"
        fi
    done
fi
if [ ! -z "$THRESHOLD_VALUE" ]; then
    echo "Threshold: $THRESHOLD_VALUE"
fi
echo ""

print_success "✅ Consulta concluída!"
