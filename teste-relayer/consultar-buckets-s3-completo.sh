#!/bin/bash

# ============================================================================
# Script: Consultar Buckets S3 dos Validators - Abordagem Completa
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

# ValidatorAnnounce Terra Classic
VALIDATOR_ANNOUNCE_TERRA_HEX="0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"
VALIDATOR_ANNOUNCE_TERRA="terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5"
TERRA_RPC="https://rpc.luncblaze.com:443"
TERRA_CHAIN_ID="rebel-2"

# ValidatorAnnounce BSC
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

print_header "CONSULTAR BUCKETS S3 DOS VALIDATORS - ABORDAGEM COMPLETA"

# ============================================================================
# PASSO 1: Consultar ValidatorAnnounce do Terra Classic
# ============================================================================

print_section "PASSO 1: CONSULTAR VALIDATORANNOUNCE DO TERRA CLASSIC"

print_info "Endereço: $VALIDATOR_ANNOUNCE_TERRA"
print_info "RPC: $TERRA_RPC"
echo ""

# Query 1: get_announced_validators (nome correto)
print_info "1. Consultando get_announced_validators..."
QUERY1='{"get_announced_validators": {}}'
RESPONSE1=$(timeout 15 terrad query wasm contract-state smart \
    "$VALIDATOR_ANNOUNCE_TERRA" \
    "$QUERY1" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1 || echo "TIMEOUT_OR_ERROR")

if echo "$RESPONSE1" | grep -qi "error\|timeout\|TIMEOUT"; then
    print_error "❌ Erro ao consultar announced_validators"
    echo "$RESPONSE1" | head -5
else
    print_success "✅ Resposta obtida"
    echo "$RESPONSE1" | jq '.' 2>/dev/null || echo "$RESPONSE1"
fi

echo ""

# Query 2: get_announce_storage_locations (formato Terra Classic)
print_info "2. Consultando get_announce_storage_locations (formato Terra Classic)..."

# Consultar storage locations para validators do ISM no formato Terra Classic
# Formato esperado: {"get_announce_storage_locations": {"validators": ["validator_sem_0x"]}}

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo ""
print_info "Consultando storage locations para validators do ISM..."
echo ""

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
    print_info "  Validator: $VALIDATOR_CLEAN"
    
    QUERY2="{\"get_announce_storage_locations\": {\"validators\": [\"$VALIDATOR_CLEAN\"]}}"
    RESPONSE2=$(timeout 15 terrad query wasm contract-state smart \
        "$VALIDATOR_ANNOUNCE_TERRA" \
        "$QUERY2" \
        --chain-id "$TERRA_CHAIN_ID" \
        --node "$TERRA_RPC" \
        --output json 2>&1 || echo "TIMEOUT_OR_ERROR")
    
    if echo "$RESPONSE2" | grep -qi "error\|timeout\|TIMEOUT"; then
        print_warning "    ⚠️  Erro ao consultar"
    else
        print_success "    ✅ Resposta obtida:"
        echo "$RESPONSE2" | jq '.' 2>/dev/null || echo "$RESPONSE2"
    fi
    echo ""
done

echo ""

# Query 3: announced_storage_location (individual para cada validator)
print_section "PASSO 2: CONSULTAR STORAGE LOCATIONS INDIVIDUAIS"

declare -A STORAGE_LOCATIONS

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    print_info "Consultando storage location para: $VALIDATOR"
    
    # Remover 0x do validator para a query
    VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
    QUERY3="{\"get_announce_storage_locations\": {\"validators\": [\"$VALIDATOR_CLEAN\"]}}"
    RESPONSE3=$(timeout 15 terrad query wasm contract-state smart \
        "$VALIDATOR_ANNOUNCE_TERRA" \
        "$QUERY3" \
        --chain-id "$TERRA_CHAIN_ID" \
        --node "$TERRA_RPC" \
        --output json 2>&1 || echo "TIMEOUT_OR_ERROR")
    
    if echo "$RESPONSE3" | grep -qi "error\|timeout\|TIMEOUT"; then
        print_warning "  ⚠️  Erro ou timeout"
        STORAGE_LOCATIONS["$VALIDATOR"]="ERRO"
    else
        STORAGE=$(echo "$RESPONSE3" | jq -r '.data.storage_location // .data // empty' 2>/dev/null || echo "")
        
        if [ ! -z "$STORAGE" ] && [ "$STORAGE" != "null" ] && [ "$STORAGE" != "TIMEOUT_OR_ERROR" ]; then
            STORAGE_LOCATIONS["$VALIDATOR"]="$STORAGE"
            print_success "  ✅ Storage location: $STORAGE"
        else
            print_warning "  ⚠️  Storage location não encontrada"
            STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
        fi
    fi
    
    echo ""
done

# ============================================================================
# PASSO 3: Verificar Checkpoints no S3 (se encontrados)
# ============================================================================

print_section "PASSO 3: VERIFICAR CHECKPOINTS NO S3"

SEQUENCE="12768"
CHECKPOINTS_FOUND=0

if command -v aws &> /dev/null; then
    print_info "AWS CLI disponível. Verificando checkpoints..."
    echo ""
    
    for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
        STORAGE="${STORAGE_LOCATIONS[$VALIDATOR]}"
        
        if [ "$STORAGE" == "ERRO" ] || [ "$STORAGE" == "NÃO ENCONTRADO" ]; then
            print_warning "⚠️  $VALIDATOR - Storage location não disponível"
            continue
        fi
        
        if [[ "$STORAGE" == s3://* ]]; then
            # Extrair bucket e prefixo
            if [[ "$STORAGE" =~ s3://([^/]+)(/.*)? ]]; then
                BUCKET="${BASH_REMATCH[1]}"
                PREFIX="${BASH_REMATCH[2]:1}"
                
                print_info "Verificando checkpoints em: $STORAGE"
                
                # Tentar diferentes padrões
                PATTERNS=(
                    "checkpoint_${SEQUENCE}_*.json"
                    "checkpoint_${SEQUENCE}.json"
                )
                
                FOUND=false
                for PATTERN in "${PATTERNS[@]}"; do
                    if [ ! -z "$PREFIX" ]; then
                        S3_PATH="s3://${BUCKET}/${PREFIX}/${PATTERN}"
                    else
                        S3_PATH="s3://${BUCKET}/${PATTERN}"
                    fi
                    
                    if aws s3 ls "$S3_PATH" --recursive 2>/dev/null | head -1 | grep -q .; then
                        print_success "  ✅ Checkpoint encontrado: $S3_PATH"
                        CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
                        FOUND=true
                        break
                    fi
                done
                
                if [ "$FOUND" = false ]; then
                    print_warning "  ⚠️  Checkpoint não encontrado para sequence $SEQUENCE"
                fi
            fi
        fi
        
        echo ""
    done
else
    print_warning "⚠️  AWS CLI não está instalado"
fi

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO FINAL"

print_info "Storage locations encontradas:"
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

if [ "$CHECKPOINTS_FOUND" -gt 0 ]; then
    print_success "✅ Checkpoints encontrados: $CHECKPOINTS_FOUND de ${#VALIDATORS_ISM[@]} validators"
else
    print_warning "⚠️  Nenhum checkpoint encontrado para sequence $SEQUENCE"
fi

echo ""
print_success "✅ Análise concluída!"
