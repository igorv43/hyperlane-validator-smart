#!/bin/bash

# ============================================================================
# Script: Obter Buckets S3 dos Validators via Eventos do ValidatorAnnounce
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

# Validators do ISM
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

# ============================================================================
# INÍCIO
# ============================================================================

print_header "OBTER BUCKETS S3 DOS VALIDATORS VIA EVENTOS"

print_info "Consultando eventos do ValidatorAnnounce para obter storage locations"
print_value "Contrato: $BSC_VALIDATOR_ANNOUNCE"
print_value "RPC: $BSC_RPC"
echo ""

# ============================================================================
# PASSO 1: Obter Eventos do ValidatorAnnounce
# ============================================================================

print_section "PASSO 1: OBTER EVENTOS DO VALIDATORANNOUNCE"

print_info "Consultando eventos recentes do ValidatorAnnounce (últimos 100k blocos)..."

# Obter número do bloco atual
CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "86186000")
FROM_BLOCK=$((CURRENT_BLOCK - 10000))  # Reduzir para 10k blocos para evitar erro do RPC
if [ "$FROM_BLOCK" -lt 0 ]; then
    FROM_BLOCK=0
fi

print_info "Consultando eventos do bloco $FROM_BLOCK até $CURRENT_BLOCK (últimos 10k blocos)"

# Obter eventos do ValidatorAnnounce
# O evento ValidatorAnnounce tem a assinatura: ValidatorAnnounce(address indexed validator, string storageLocation, string signature)
EVENTS_RAW=$(cast logs --from-block "$FROM_BLOCK" \
                --address "$BSC_VALIDATOR_ANNOUNCE" \
                --rpc-url "$BSC_RPC" 2>&1 || echo "")

if [ -z "$EVENTS_RAW" ] || echo "$EVENTS_RAW" | grep -qi "error"; then
    print_error "❌ Erro ao consultar eventos"
    echo "$EVENTS_RAW"
    exit 1
fi

print_success "✅ Eventos obtidos"
echo ""

# ============================================================================
# PASSO 2: Extrair Storage Locations dos Validators do ISM
# ============================================================================

print_section "PASSO 2: EXTRAIR STORAGE LOCATIONS DOS VALIDATORS DO ISM"

declare -A STORAGE_LOCATIONS
declare -A BUCKET_NAMES
declare -A BUCKET_PREFIXES

for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    print_info "Procurando storage location para: $VALIDATOR"
    
    # Procurar eventos relacionados a este validator
    VALIDATOR_EVENTS=$(echo "$EVENTS_RAW" | grep -i "$VALIDATOR" || echo "")
    
    if [ -z "$VALIDATOR_EVENTS" ]; then
        print_warning "⚠️  Nenhum evento encontrado para $VALIDATOR"
        STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
        continue
    fi
    
    # Tentar extrair storage location (s3://...) dos eventos
    # Os eventos podem ter o storage location em diferentes formatos
    STORAGE=$(echo "$VALIDATOR_EVENTS" | grep -oE "s3://[^ ]+" | head -1 || echo "")
    
    if [ -z "$STORAGE" ]; then
        # Tentar extrair de dados hexadecimais decodificados
        # O storage location pode estar em formato ABI-encoded
        print_info "  Tentando decodificar de dados hexadecimais..."
        
        # Procurar por padrões que possam indicar S3 bucket
        HEX_DATA=$(echo "$VALIDATOR_EVENTS" | grep -oE "0x[0-9a-f]+" | head -5 || echo "")
        
        if [ ! -z "$HEX_DATA" ]; then
            # Tentar decodificar como string
            for HEX in $HEX_DATA; do
                DECODED=$(cast --to-ascii "$HEX" 2>/dev/null | grep -oE "s3://[^ ]+" || echo "")
                if [ ! -z "$DECODED" ]; then
                    STORAGE="$DECODED"
                    break
                fi
            done
        fi
    fi
    
    if [ ! -z "$STORAGE" ] && [[ "$STORAGE" == s3://* ]]; then
        STORAGE_LOCATIONS["$VALIDATOR"]="$STORAGE"
        print_success "  ✅ Storage location encontrada: $STORAGE"
        
        # Extrair bucket e prefixo
        if [[ "$STORAGE" =~ s3://([^/]+)(/.*)? ]]; then
            BUCKET="${BASH_REMATCH[1]}"
            PREFIX="${BASH_REMATCH[2]:1}"  # Remove leading /
            BUCKET_NAMES["$VALIDATOR"]="$BUCKET"
            if [ ! -z "$PREFIX" ]; then
                BUCKET_PREFIXES["$VALIDATOR"]="$PREFIX"
            fi
            print_value "    Bucket: $BUCKET"
            if [ ! -z "$PREFIX" ]; then
                print_value "    Prefix: $PREFIX"
            fi
        fi
    else
        print_warning "  ⚠️  Storage location não encontrada nos eventos"
        STORAGE_LOCATIONS["$VALIDATOR"]="NÃO ENCONTRADO"
        print_info "  Eventos encontrados (primeiras linhas):"
        echo "$VALIDATOR_EVENTS" | head -3 | sed 's/^/    /'
    fi
    
    echo ""
done

# ============================================================================
# PASSO 3: Verificar Checkpoints no S3
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
        
        if [ "$STORAGE" == "NÃO ENCONTRADO" ]; then
            print_warning "⚠️  $VALIDATOR - Storage location não disponível"
            continue
        fi
        
        print_info "Verificando checkpoints para $VALIDATOR"
        print_value "  Bucket: $BUCKET"
        if [ ! -z "$PREFIX" ]; then
            print_value "  Prefix: $PREFIX"
        fi
        
        # Tentar diferentes formatos de nome de checkpoint
        CHECKPOINT_PATTERNS=(
            "checkpoint_${SEQUENCE}_*.json"
            "checkpoint_${SEQUENCE}.json"
            "${SEQUENCE}_*.json"
            "checkpoint_*.json"
        )
        
        FOUND=false
        for PATTERN in "${CHECKPOINT_PATTERNS[@]}"; do
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
            print_info "  Listando arquivos no bucket (primeiros 10):"
            if [ ! -z "$PREFIX" ]; then
                aws s3 ls "s3://${BUCKET}/${PREFIX}/" 2>/dev/null | head -10 || print_warning "    Não foi possível listar"
            else
                aws s3 ls "s3://${BUCKET}/" 2>/dev/null | head -10 || print_warning "    Não foi possível listar"
            fi
        fi
        
        echo ""
    done
else
    print_warning "⚠️  AWS CLI não está instalado"
    print_info "Instale AWS CLI para verificar checkpoints no S3"
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
    if [ "$STORAGE" != "NÃO ENCONTRADO" ]; then
        print_success "  ✅ Storage Location: $STORAGE"
        if [ ! -z "$BUCKET" ]; then
            print_value "  Bucket S3: $BUCKET"
        fi
    else
        print_warning "  ⚠️  Storage Location: NÃO ENCONTRADO"
        print_info "  O validator pode não ter anunciado ou os eventos não estão disponíveis"
    fi
    echo ""
done

if [ "$CHECKPOINTS_FOUND" -gt 0 ]; then
    print_success "✅ Checkpoints encontrados: $CHECKPOINTS_FOUND de ${#VALIDATORS_ISM[@]} validators"
else
    print_warning "⚠️  Nenhum checkpoint encontrado para sequence $SEQUENCE"
    print_info "Possíveis causas:"
    print_value "1. Validators não estão gerando checkpoints para BSC"
    print_value "2. Checkpoints estão em formato diferente"
    print_value "3. Buckets S3 não são acessíveis ou não existem"
fi

echo ""
print_success "✅ Script concluído!"
