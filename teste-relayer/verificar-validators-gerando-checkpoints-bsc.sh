#!/bin/bash

# ============================================================================
# Script: Verificar Validators Gerando Checkpoints no BSC
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

print_header "VERIFICAR VALIDATORS GERANDO CHECKPOINTS NO BSC"

print_info "ValidatorAnnounce BSC: $VALIDATOR_ANNOUNCE_BSC"
print_info "RPC: $BSC_RPC"
echo ""

# ============================================================================
# PASSO 1: Obter Lista de Validators Anunciados
# ============================================================================

print_section "PASSO 1: OBTER VALIDATORS ANUNCIADOS NO BSC"

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
    echo "Resposta raw: $ANNOUNCED_VALIDATORS_RAW"
    exit 1
fi

# Converter para array - cast retorna em formato de lista Python, extrair endereços
VALIDATORS_ARRAY=()
# Extrair endereços do formato [0x..., 0x..., ...]
echo "$ANNOUNCED_VALIDATORS" | grep -oE "0x[a-fA-F0-9]{40}" | while read -r addr; do
    VALIDATORS_ARRAY+=("$addr")
done

# Alternativa: processar diretamente
VALIDATORS_ARRAY=($(echo "$ANNOUNCED_VALIDATORS" | grep -oE "0x[a-fA-F0-9]{40}"))

print_success "✅ Encontrados ${#VALIDATORS_ARRAY[@]} validators anunciados"
echo ""

# ============================================================================
# PASSO 2: Obter Storage Locations dos Validators
# ============================================================================

print_section "PASSO 2: OBTER STORAGE LOCATIONS (BUCKETS S3)"

declare -A STORAGE_LOCATIONS
declare -A VALIDATOR_NAMES

for VALIDATOR in "${VALIDATORS_ARRAY[@]}"; do
    print_info "Consultando storage location para: $VALIDATOR"
    
    STORAGE_RESPONSE=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedStorageLocations(address)" \
        "$VALIDATOR" \
        --rpc-url "$BSC_RPC" 2>&1)
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert"; then
        print_warning "  ⚠️  Erro ao consultar storage location"
        STORAGE_LOCATIONS["$VALIDATOR"]="ERRO"
    else
        # Tentar decodificar como string[]
        STORAGE_DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address)(string[])" "$STORAGE_RESPONSE" 2>/dev/null || echo "")
        
        if [ ! -z "$STORAGE_DECODED" ] && [ "$STORAGE_DECODED" != "()" ]; then
            # Extrair primeira storage location (geralmente há apenas uma)
            STORAGE=$(echo "$STORAGE_DECODED" | grep -oE "s3://[^ ]+" | head -1 || echo "")
            
            if [ ! -z "$STORAGE" ]; then
                STORAGE_LOCATIONS["$VALIDATOR"]="$STORAGE"
                print_success "  ✅ Storage: $STORAGE"
            else
                print_warning "  ⚠️  Storage location não encontrada ou formato inválido"
                echo "    Resposta: $STORAGE_DECODED"
                STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
            fi
        else
            print_warning "  ⚠️  Storage location vazia"
            STORAGE_LOCATIONS["$VALIDATOR"]="VAZIO"
        fi
    fi
    
    echo ""
done

# ============================================================================
# PASSO 3: Verificar Checkpoints Recentes no S3
# ============================================================================

print_section "PASSO 3: VERIFICAR CHECKPOINTS RECENTES NO S3"

if ! command -v aws &> /dev/null; then
    print_warning "⚠️  AWS CLI não está instalado. Pulando verificação de S3."
else
    print_info "Verificando checkpoints dos últimos 7 dias..."
    echo ""
    
    # Obter bloco atual do BSC para calcular range de sequences
    CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "0")
    print_info "Bloco atual do BSC: $CURRENT_BLOCK"
    echo ""
    
    CHECKPOINTS_FOUND=0
    
    for VALIDATOR in "${VALIDATORS_ARRAY[@]}"; do
        STORAGE="${STORAGE_LOCATIONS[$VALIDATOR]}"
        
        if [ "$STORAGE" == "ERRO" ] || [ "$STORAGE" == "NÃO ENCONTRADO" ] || [ "$STORAGE" == "VAZIO" ]; then
            continue
        fi
        
        if [[ "$STORAGE" == s3://* ]]; then
            # Extrair bucket e prefixo
            if [[ "$STORAGE" =~ s3://([^/]+)(/.*)? ]]; then
                BUCKET="${BASH_REMATCH[1]}"
                PREFIX="${BASH_REMATCH[2]:1}"
                
                print_info "Verificando checkpoints em: $STORAGE"
                
                # Listar arquivos recentes (últimos 7 dias)
                if [ ! -z "$PREFIX" ]; then
                    S3_PATH="s3://${BUCKET}/${PREFIX}/"
                else
                    S3_PATH="s3://${BUCKET}/"
                fi
                
                # Listar arquivos modificados nos últimos 7 dias
                RECENT_FILES=$(aws s3 ls "$S3_PATH" --recursive 2>/dev/null | \
                    awk -v date="$(date -d '7 days ago' -u +%Y-%m-%d)" '$1 >= date {print $4}' | \
                    head -10 || echo "")
                
                if [ ! -z "$RECENT_FILES" ]; then
                    FILE_COUNT=$(echo "$RECENT_FILES" | wc -l)
                    print_success "  ✅ Encontrados $FILE_COUNT arquivos recentes"
                    
                    # Mostrar alguns exemplos
                    echo "$RECENT_FILES" | head -3 | while read file; do
                        print_value "    - $file"
                    done
                    
                    CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
                else
                    print_warning "  ⚠️  Nenhum arquivo recente encontrado"
                fi
            fi
        fi
        
        echo ""
    done
    
    if [ "$CHECKPOINTS_FOUND" -gt 0 ]; then
        print_success "✅ $CHECKPOINTS_FOUND validators com checkpoints recentes"
    else
        print_warning "⚠️  Nenhum validator com checkpoints recentes encontrado"
    fi
fi

# ============================================================================
# PASSO 4: Focar nos Validators do ISM
# ============================================================================

print_section "PASSO 4: VALIDATORS DO ISM"

print_info "Verificando validators do ISM especificamente..."
echo ""

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    echo -e "${CYAN}Validator:${NC} $VALIDATOR"
    
    # Verificar se está na lista de anunciados
    IS_ANNOUNCED=false
    for ANNOUNCED in "${VALIDATORS_ARRAY[@]}"; do
        if [ "$ANNOUNCED" == "$VALIDATOR" ]; then
            IS_ANNOUNCED=true
            break
        fi
    done
    
    if [ "$IS_ANNOUNCED" = true ]; then
        print_success "  ✅ Anunciado no BSC ValidatorAnnounce"
        
        STORAGE="${STORAGE_LOCATIONS[$VALIDATOR]}"
        if [ ! -z "$STORAGE" ] && [ "$STORAGE" != "ERRO" ] && [ "$STORAGE" != "NÃO ENCONTRADO" ] && [ "$STORAGE" != "VAZIO" ]; then
            print_success "  ✅ Storage Location: $STORAGE"
        else
            print_warning "  ⚠️  Storage Location: ${STORAGE:-NÃO ENCONTRADO}"
        fi
    else
        print_error "  ❌ NÃO está anunciado no BSC ValidatorAnnounce"
    fi
    
    echo ""
done

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO FINAL"

print_info "Total de validators anunciados no BSC: ${#VALIDATORS_ARRAY[@]}"
print_info "Validators com storage locations: $(for v in "${!STORAGE_LOCATIONS[@]}"; do [ "${STORAGE_LOCATIONS[$v]}" != "ERRO" ] && [ "${STORAGE_LOCATIONS[$v]}" != "NÃO ENCONTRADO" ] && [ "${STORAGE_LOCATIONS[$v]}" != "VAZIO" ] && echo "$v"; done | wc -l)"

echo ""
print_success "✅ Análise concluída!"

