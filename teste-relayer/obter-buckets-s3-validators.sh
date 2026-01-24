#!/bin/bash

# ============================================================================
# Script: Obter Buckets S3 dos Validators do ValidatorAnnounce
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

BSC_VALIDATOR_ANNOUNCE="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Validators do ISM (obtidos anteriormente)
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

# ============================================================================
# INÍCIO
# ============================================================================

print_header "OBTER BUCKETS S3 DOS VALIDATORS DO VALIDATORANNOUNCE"

print_info "Consultando ValidatorAnnounce do BSC para obter storage locations (buckets S3)"
print_value "Contrato: $BSC_VALIDATOR_ANNOUNCE"
print_value "RPC: $BSC_RPC"
echo ""

# ============================================================================
# PASSO 1: Obter Lista de Validators Anunciados
# ============================================================================

print_section "PASSO 1: OBTER LISTA DE VALIDATORS ANUNCIADOS"

print_info "Consultando getAnnouncedValidators()..."

ANNOUNCED_VALIDATORS_RAW=$(cast call "$BSC_VALIDATOR_ANNOUNCE" "getAnnouncedValidators()" --rpc-url "$BSC_RPC" 2>&1)

if echo "$ANNOUNCED_VALIDATORS_RAW" | grep -qi "error"; then
    print_error "❌ Erro ao consultar validators anunciados:"
    echo "$ANNOUNCED_VALIDATORS_RAW"
    exit 1
fi

# Decodificar resposta usando o mesmo método do script anterior
print_info "Decodificando resposta ABI..."

# Extrair endereços da resposta ABI (mesmo método do verificar-validators-anunciados-bsc.sh)
ANNOUNCED_VALIDATORS=$(echo "$ANNOUNCED_VALIDATORS_RAW" | sed 's/^0x//' | fold -w 64 | tail -n +3 | sed 's/.*\(.\{40\}\)$/0x\1/' | sort -u)

if [ -z "$ANNOUNCED_VALIDATORS" ]; then
    print_warning "⚠️  Nenhum validator encontrado na resposta"
    print_info "Tentando método alternativo de decodificação..."
    
    # Tentar decodificação direta
    ANNOUNCED_VALIDATORS=$(cast --abi-decode "getAnnouncedValidators()(address[])" "$ANNOUNCED_VALIDATORS_RAW" 2>/dev/null || echo "")
    
    if [ -z "$ANNOUNCED_VALIDATORS" ]; then
        print_error "❌ Não foi possível decodificar lista de validators"
        print_info "Resposta raw: $ANNOUNCED_VALIDATORS_RAW"
        print_info "Tentando obter de eventos do ValidatorAnnounce..."
        
        # Obter de eventos como fallback
        EVENTS=$(cast logs --from-block latest-100000 \
                    --address "$BSC_VALIDATOR_ANNOUNCE" \
                    --rpc-url "$BSC_RPC" 2>&1 | grep -oE "0x[0-9a-fA-F]{40}" | sort -u || echo "")
        
        if [ ! -z "$EVENTS" ]; then
            ANNOUNCED_VALIDATORS="$EVENTS"
            print_success "✅ Validators obtidos de eventos"
        fi
    fi
fi

# Converter para array
VALIDATORS_ARRAY=()
while IFS= read -r line; do
    if [[ "$line" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        VALIDATORS_ARRAY+=("$line")
    fi
done <<< "$ANNOUNCED_VALIDATORS"

print_success "✅ Total de validators anunciados: ${#VALIDATORS_ARRAY[@]}"
echo ""

# ============================================================================
# PASSO 2: Obter Storage Locations dos Validators do ISM
# ============================================================================

print_section "PASSO 2: OBTER STORAGE LOCATIONS DOS VALIDATORS DO ISM"

declare -A STORAGE_LOCATIONS
declare -A BUCKET_NAMES
declare -A BUCKET_PREFIXES

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    print_info "Consultando storage location para: $VALIDATOR"
    
    # Verificar se validator está anunciado
    IS_ANNOUNCED=false
    for ANNOUNCED in "${VALIDATORS_ARRAY[@]}"; do
        if [[ "${VALIDATOR,,}" == "${ANNOUNCED,,}" ]]; then
            IS_ANNOUNCED=true
            break
        fi
    done
    
    if [ "$IS_ANNOUNCED" = false ]; then
        print_warning "⚠️  Validator $VALIDATOR não está anunciado no ValidatorAnnounce"
        STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ANUNCIADO"
        continue
    fi
    
    # Tentar diferentes métodos para obter storage location
    
    # Método 1: getAnnouncedStorageLocations(address)
    print_info "  Tentando getAnnouncedStorageLocations(address)..."
    STORAGE_RESPONSE=$(cast call "$BSC_VALIDATOR_ANNOUNCE" \
                            "getAnnouncedStorageLocations(address)" \
                            "$VALIDATOR" \
                            --rpc-url "$BSC_RPC" 2>&1)
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert"; then
        print_warning "  ⚠️  getAnnouncedStorageLocations falhou"
        
        # Método 2: Tentar eventos do ValidatorAnnounce
        print_info "  Tentando obter de eventos do ValidatorAnnounce..."
        
        # Procurar eventos recentes
        EVENTS=$(cast logs --from-block latest-100000 \
                    --address "$BSC_VALIDATOR_ANNOUNCE" \
                    --rpc-url "$BSC_RPC" 2>&1 | grep -i "$VALIDATOR" | head -5 || echo "")
        
        if [ ! -z "$EVENTS" ]; then
            print_info "  Eventos encontrados para $VALIDATOR"
            # Tentar extrair storage location dos eventos
            STORAGE_FROM_EVENT=$(echo "$EVENTS" | grep -oE "s3://[^ ]+" | head -1 || echo "")
            if [ ! -z "$STORAGE_FROM_EVENT" ]; then
                STORAGE_LOCATIONS["$VALIDATOR"]="$STORAGE_FROM_EVENT"
                print_success "  ✅ Storage location encontrada em eventos: $STORAGE_FROM_EVENT"
            else
                STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
                print_warning "  ⚠️  Storage location não encontrada em eventos"
            fi
        else
            STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
            print_warning "  ⚠️  Nenhum evento encontrado para $VALIDATOR"
        fi
    else
        # Decodificar storage location
        STORAGE=$(cast --abi-decode "getAnnouncedStorageLocations(address)(string)" "$STORAGE_RESPONSE" 2>/dev/null || echo "")
        
        if [ ! -z "$STORAGE" ] && [[ "$STORAGE" == s3://* ]]; then
            STORAGE_LOCATIONS["$VALIDATOR"]="$STORAGE"
            print_success "  ✅ Storage location: $STORAGE"
            
            # Extrair bucket e prefixo
            if [[ "$STORAGE" =~ s3://([^/]+)(/.*)? ]]; then
                BUCKET="${BASH_REMATCH[1]}"
                PREFIX="${BASH_REMATCH[2]:1}"  # Remove leading /
                BUCKET_NAMES["$VALIDATOR"]="$BUCKET"
                BUCKET_PREFIXES["$VALIDATOR"]="$PREFIX"
                print_value "    Bucket: $BUCKET"
                if [ ! -z "$PREFIX" ]; then
                    print_value "    Prefix: $PREFIX"
                fi
            fi
        else
            STORAGE_LOCATIONS["$VALIDATOR"]="INVÁLIDO"
            print_warning "  ⚠️  Storage location inválida ou não é S3: $STORAGE"
        fi
    fi
    
    echo ""
done

# ============================================================================
# PASSO 3: Verificar Checkpoints no S3 (se AWS CLI estiver disponível)
# ============================================================================

print_section "PASSO 3: VERIFICAR CHECKPOINTS NO S3"

SEQUENCE="12768"
CHECKPOINTS_FOUND=0

if command -v aws &> /dev/null; then
    print_info "AWS CLI disponível. Verificando checkpoints no S3..."
    echo ""
    
    for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
        STORAGE="${STORAGE_LOCATIONS[$VALIDATOR]}"
        BUCKET="${BUCKET_NAMES[$VALIDATOR]}"
        PREFIX="${BUCKET_PREFIXES[$VALIDATOR]}"
        
        if [ "$STORAGE" == "NÃO ANUNCIADO" ] || [ "$STORAGE" == "NÃO ENCONTRADO" ] || [ "$STORAGE" == "INVÁLIDO" ]; then
            print_warning "⚠️  $VALIDATOR - Storage location não disponível: $STORAGE"
            continue
        fi
        
        print_info "Verificando checkpoints para $VALIDATOR em s3://$BUCKET/${PREFIX:+$PREFIX/}"
        
        # Tentar diferentes formatos de nome de checkpoint
        CHECKPOINT_PATTERNS=(
            "checkpoint_${SEQUENCE}_*.json"
            "checkpoint_${SEQUENCE}.json"
            "${SEQUENCE}_*.json"
            "checkpoint_*.json"
        )
        
        FOUND=false
        for PATTERN in "${CHECKPOINT_PATTERNS[@]}"; do
            S3_PATH="s3://${BUCKET}/${PREFIX:+$PREFIX/}${PATTERN}"
            
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
        
        echo ""
    done
else
    print_warning "⚠️  AWS CLI não está instalado"
    print_info "Instale AWS CLI para verificar checkpoints no S3:"
    print_value "  https://aws.amazon.com/cli/"
    echo ""
    print_info "Storage locations encontradas:"
    for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
        print_value "  $VALIDATOR: ${STORAGE_LOCATIONS[$VALIDATOR]}"
    done
fi

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO"

print_info "Validators do ISM e seus buckets S3:"
echo ""

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    STORAGE="${STORAGE_LOCATIONS[$VALIDATOR]}"
    BUCKET="${BUCKET_NAMES[$VALIDATOR]}"
    
    echo -e "${CYAN}Validator:${NC} $VALIDATOR"
    print_value "  Storage Location: $STORAGE"
    if [ ! -z "$BUCKET" ]; then
        print_value "  Bucket S3: $BUCKET"
    fi
    echo ""
done

if [ "$CHECKPOINTS_FOUND" -gt 0 ]; then
    print_success "✅ Checkpoints encontrados: $CHECKPOINTS_FOUND de ${#VALIDATORS_ISM[@]} validators"
else
    print_warning "⚠️  Nenhum checkpoint encontrado para sequence $SEQUENCE"
fi

echo ""
print_success "✅ Script concluído!"
