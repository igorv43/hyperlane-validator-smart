#!/bin/bash

# ============================================================================
# Script: Verificar Checkpoints e Quorum para Mensagem BSC -> Terra Classic
# ============================================================================
# Este script:
# 1. Consulta validators do ISM
# 2. Para cada validator, obtém o bucket S3 do ValidatorAnnounce
# 3. Verifica se há checkpoints no S3 para a mensagem
# 4. Verifica se há quorum suficiente (threshold: 2 de 3)
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

ISM_MULTISIG_BSC="terra1ksq6cekt0as2f9vv5txld90s854y4pkr2k0jn5p83vqpa5zzzfysuavxr0"
VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"
TERRA_RPC="https://rpc.luncblaze.com:443"
TERRA_CHAIN_ID="rebel-2"
SEQUENCE="12768"  # Mensagem específica
DOMAIN_ORIGIN="97"  # BSC Testnet
DOMAIN_DEST="1325"  # Terra Classic Testnet

# Verificar se ferramentas estão disponíveis
if ! command -v cast &> /dev/null; then
    print_error "cast não está instalado. Instale Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

if ! command -v terrad &> /dev/null; then
    print_error "terrad não está instalado"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_warning "⚠️  AWS CLI não está instalado. Não será possível verificar checkpoints no S3 diretamente."
    AWS_AVAILABLE=false
else
    AWS_AVAILABLE=true
fi

# ============================================================================
# INÍCIO
# ============================================================================

print_header "VERIFICAR CHECKPOINTS E QUORUM - BSC -> TERRA CLASSIC"

print_info "Configurações:"
print_value "Sequence: $SEQUENCE"
print_value "Domain Origin: $DOMAIN_ORIGIN (BSC Testnet)"
print_value "Domain Dest: $DOMAIN_DEST (Terra Classic Testnet)"
print_value "ISM Multisig BSC: $ISM_MULTISIG_BSC"
echo ""

# ============================================================================
# PASSO 1: Obter Validators e Threshold do ISM
# ============================================================================

print_section "PASSO 1: OBTER VALIDATORS E THRESHOLD DO ISM"

print_info "Consultando ISM Multisig BSC para obter validators e threshold..."

QUERY_VALIDATORS='{"multisig_ism":{"enrolled_validators":{"domain":97}}}'

ISM_RESPONSE=$(timeout 30 terrad query wasm contract-state smart \
    "${ISM_MULTISIG_BSC}" \
    "${QUERY_VALIDATORS}" \
    --chain-id "${TERRA_CHAIN_ID}" \
    --node "${TERRA_RPC}" \
    --output json 2>&1 || echo "")

if ! echo "$ISM_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    print_error "❌ Erro ao consultar ISM"
    echo "$ISM_RESPONSE"
    exit 1
fi

VALIDATORS_JSON=$(echo "$ISM_RESPONSE" | jq -r '.data.validators' 2>/dev/null)
THRESHOLD=$(echo "$ISM_RESPONSE" | jq -r '.data.threshold' 2>/dev/null)

if [ -z "$VALIDATORS_JSON" ] || [ "$VALIDATORS_JSON" = "null" ]; then
    print_error "❌ Não foi possível obter validators do ISM"
    exit 1
fi

# Converter JSON array para array bash
VALIDATORS=($(echo "$VALIDATORS_JSON" | jq -r '.[]' 2>/dev/null))

print_success "✅ Validators encontrados: ${#VALIDATORS[@]}"
print_success "✅ Threshold: $THRESHOLD de ${#VALIDATORS[@]}"

echo ""
print_info "Validators:"
for i in "${!VALIDATORS[@]}"; do
    VALIDATOR="${VALIDATORS[$i]}"
    # Converter de hex para endereço com 0x
    if [[ ! "$VALIDATOR" =~ ^0x ]]; then
        VALIDATOR="0x$VALIDATOR"
    fi
    VALIDATORS[$i]="$VALIDATOR"
    print_value "$((i+1)). $VALIDATOR"
done

echo ""

# ============================================================================
# PASSO 2: Obter Storage Locations dos Validators
# ============================================================================

print_section "PASSO 2: OBTER STORAGE LOCATIONS DOS VALIDATORS"

declare -A VALIDATOR_BUCKETS
declare -A VALIDATOR_STORAGE

print_info "Consultando eventos do ValidatorAnnounce para obter storage locations..."

# Consultar eventos de anúncio do ValidatorAnnounce
# O evento ValidatorAnnounce contém a storage location
# Vamos consultar os eventos mais recentes

for VALIDATOR in "${VALIDATORS[@]}"; do
    print_info "Consultando eventos para: $VALIDATOR"
    
    # Consultar eventos ValidatorAnnounce para este validator
    # O evento pode ter o nome "ValidatorAnnounce" ou similar
    EVENTS=$(cast logs \
        --from-block 0 \
        --address "$VALIDATOR_ANNOUNCE_BSC" \
        --rpc-url "$BSC_RPC" \
        "ValidatorAnnounce(address,string,string)" \
        "$VALIDATOR" 2>&1 | tail -20 || echo "")
    
    if echo "$EVENTS" | grep -qi "error\|not found"; then
        print_warning "⚠️  Não foi possível consultar eventos para $VALIDATOR"
        print_info "Tentando método alternativo: consultar eventos recentes..."
        
        # Tentar consultar eventos recentes do ValidatorAnnounce
        RECENT_EVENTS=$(cast logs \
            --from-block latest-1000 \
            --address "$VALIDATOR_ANNOUNCE_BSC" \
            --rpc-url "$BSC_RPC" 2>&1 | grep -i "$VALIDATOR" | tail -5 || echo "")
        
        if [ ! -z "$RECENT_EVENTS" ]; then
            print_info "Eventos encontrados (últimos 1000 blocos):"
            echo "$RECENT_EVENTS"
        fi
    fi
    
    # Por enquanto, vamos tentar descobrir o bucket de outras formas
    # O formato típico é: hyperlane-validator-signatures-{validator_address_short}-{domain}
    VALIDATOR_SHORT=$(echo "$VALIDATOR" | sed 's/^0x//' | head -c 16)
    POSSIBLE_BUCKETS=(
        "hyperlane-validator-signatures-${VALIDATOR_SHORT}-${DOMAIN_ORIGIN}"
        "hyperlane-validator-signatures-${VALIDATOR_SHORT}"
        "hyperlane-validator-${VALIDATOR_SHORT}-${DOMAIN_ORIGIN}"
    )
    
    print_info "Buckets possíveis para $VALIDATOR:"
    for BUCKET in "${POSSIBLE_BUCKETS[@]}"; do
        print_value "   - $BUCKET"
    done
    
    VALIDATOR_STORAGE["$VALIDATOR"]=""
    VALIDATOR_BUCKETS["$VALIDATOR"]=""
    echo ""
done

# ============================================================================
# PASSO 3: Verificar Checkpoints no S3
# ============================================================================

print_section "PASSO 3: VERIFICAR CHECKPOINTS NO S3"

if [ "$AWS_AVAILABLE" = false ]; then
    print_warning "⚠️  AWS CLI não disponível. Pulando verificação de checkpoints no S3."
    print_info "Para verificar checkpoints manualmente:"
    print_value "  aws s3 ls s3://BUCKET_NAME/ --recursive | grep '${SEQUENCE}'"
    
    # Mesmo sem AWS CLI, vamos marcar como não verificado
    for VALIDATOR in "${VALIDATORS[@]}"; do
        VALIDATOR_CHECKPOINTS["$VALIDATOR"]="not_checked"
    done
else
    CHECKPOINTS_FOUND=0
    declare -A VALIDATOR_CHECKPOINTS
    
    for VALIDATOR in "${VALIDATORS[@]}"; do
        BUCKET="${VALIDATOR_BUCKETS[$VALIDATOR]}"
        
        # Se não temos o bucket do ValidatorAnnounce, tentar buckets possíveis
        if [ -z "$BUCKET" ]; then
            print_warning "⚠️  $VALIDATOR - Bucket S3 não encontrado no ValidatorAnnounce"
            print_info "Tentando descobrir bucket testando formatos comuns..."
            
            VALIDATOR_SHORT=$(echo "$VALIDATOR" | sed 's/^0x//' | head -c 16)
            POSSIBLE_BUCKETS=(
                "hyperlane-validator-signatures-${VALIDATOR_SHORT}-${DOMAIN_ORIGIN}"
                "hyperlane-validator-signatures-${VALIDATOR_SHORT}"
                "hyperlane-validator-${VALIDATOR_SHORT}-${DOMAIN_ORIGIN}"
            )
            
            CHECKPOINT_FOUND=false
            for TEST_BUCKET in "${POSSIBLE_BUCKETS[@]}"; do
                print_value "   Testando: $TEST_BUCKET"
                
                # Verificar se bucket existe e tem checkpoints
                if aws s3 ls "s3://${TEST_BUCKET}/" 2>/dev/null | head -1 > /dev/null; then
                    CHECKPOINT_FILES=$(aws s3 ls "s3://${TEST_BUCKET}/" --recursive 2>/dev/null | grep -i "${SEQUENCE}" || echo "")
                    
                    if [ ! -z "$CHECKPOINT_FILES" ]; then
                        print_success "✅ Bucket encontrado: $TEST_BUCKET"
                        print_success "✅ Checkpoints encontrados para sequence $SEQUENCE"
                        VALIDATOR_BUCKETS["$VALIDATOR"]="$TEST_BUCKET"
                        VALIDATOR_CHECKPOINTS["$VALIDATOR"]="found"
                        CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
                        CHECKPOINT_FOUND=true
                        break
                    fi
                fi
            done
            
            if [ "$CHECKPOINT_FOUND" = false ]; then
                print_error "❌ Nenhum checkpoint encontrado para $VALIDATOR"
                VALIDATOR_CHECKPOINTS["$VALIDATOR"]="not_found"
            fi
        else
            print_info "Verificando checkpoints no bucket: $BUCKET"
            print_value "Validator: $VALIDATOR"
            
            # Procurar checkpoints para a mensagem
            CHECKPOINT_FILES=$(aws s3 ls "s3://${BUCKET}/" --recursive 2>/dev/null | grep -i "${SEQUENCE}" || echo "")
            
            if [ ! -z "$CHECKPOINT_FILES" ]; then
                CHECKPOINT_COUNT=$(echo "$CHECKPOINT_FILES" | wc -l)
                print_success "✅ Checkpoints encontrados: $CHECKPOINT_COUNT"
                VALIDATOR_CHECKPOINTS["$VALIDATOR"]="found"
                CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
                
                # Mostrar alguns arquivos encontrados
                echo "$CHECKPOINT_FILES" | head -5 | while read -r line; do
                    print_value "   - $line"
                done
            else
                print_error "❌ Nenhum checkpoint encontrado para sequence $SEQUENCE"
                VALIDATOR_CHECKPOINTS["$VALIDATOR"]="not_found"
            fi
        fi
        echo ""
    done
fi

# ============================================================================
# PASSO 4: Verificar Quorum
# ============================================================================

print_section "PASSO 4: VERIFICAR QUORUM"

print_info "Threshold necessário: $THRESHOLD de ${#VALIDATORS[@]} validators"
echo ""

CHECKPOINTS_AVAILABLE=0
VALIDATORS_WITH_CHECKPOINTS=()

for VALIDATOR in "${VALIDATORS[@]}"; do
    STATUS="${VALIDATOR_CHECKPOINTS[$VALIDATOR]:-unknown}"
    
    case "$STATUS" in
        "found")
            print_success "✅ $VALIDATOR - Checkpoint encontrado"
            CHECKPOINTS_AVAILABLE=$((CHECKPOINTS_AVAILABLE + 1))
            VALIDATORS_WITH_CHECKPOINTS+=("$VALIDATOR")
            ;;
        "not_found")
            print_error "❌ $VALIDATOR - Checkpoint não encontrado"
            ;;
        "no_bucket")
            print_warning "⚠️  $VALIDATOR - Sem bucket S3 configurado"
            ;;
        *)
            print_warning "⚠️  $VALIDATOR - Status desconhecido"
            ;;
    esac
done

echo ""
print_info "Resumo do Quorum:"
print_value "Checkpoints disponíveis: $CHECKPOINTS_AVAILABLE de ${#VALIDATORS[@]}"
print_value "Threshold necessário: $THRESHOLD"

if [ $CHECKPOINTS_AVAILABLE -ge $THRESHOLD ]; then
    print_success "✅ QUORUM SUFICIENTE! ($CHECKPOINTS_AVAILABLE >= $THRESHOLD)"
else
    print_error "❌ QUORUM INSUFICIENTE! ($CHECKPOINTS_AVAILABLE < $THRESHOLD)"
    print_warning "⚠️  O relayer não conseguirá validar a mensagem sem quorum suficiente!"
fi

echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_section "RESUMO FINAL"

print_info "Configuração do ISM:"
print_value "Validators: ${#VALIDATORS[@]}"
print_value "Threshold: $THRESHOLD"
echo ""

print_info "Status dos Checkpoints:"
for VALIDATOR in "${VALIDATORS[@]}"; do
    STATUS="${VALIDATOR_CHECKPOINTS[$VALIDATOR]:-unknown}"
    BUCKET="${VALIDATOR_BUCKETS[$VALIDATOR]}"
    STORAGE="${VALIDATOR_STORAGE[$VALIDATOR]}"
    
    case "$STATUS" in
        "found")
            print_success "✅ $VALIDATOR"
            print_value "   Bucket: $BUCKET"
            print_value "   Storage: $STORAGE"
            ;;
        "not_found")
            print_error "❌ $VALIDATOR - Checkpoint não encontrado"
            if [ ! -z "$BUCKET" ]; then
                print_value "   Bucket: $BUCKET"
            fi
            ;;
        "no_bucket")
            print_warning "⚠️  $VALIDATOR - Sem bucket S3"
            ;;
        *)
            print_warning "⚠️  $VALIDATOR - Não verificado"
            ;;
    esac
    echo ""
done

print_info "Quorum:"
if [ $CHECKPOINTS_AVAILABLE -ge $THRESHOLD ]; then
    print_success "✅ Suficiente ($CHECKPOINTS_AVAILABLE >= $THRESHOLD)"
else
    print_error "❌ Insuficiente ($CHECKPOINTS_AVAILABLE < $THRESHOLD)"
fi

echo ""

print_success "✅ Verificação concluída!"
