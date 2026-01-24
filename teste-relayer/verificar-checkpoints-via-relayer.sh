#!/bin/bash

# ============================================================================
# Script: Verificar Checkpoints via Relayer (Abordagem Alternativa)
# ============================================================================
# Como não temos acesso aos buckets S3 dos validators, vamos verificar:
# 1. Se o relayer consegue descobrir os checkpoints automaticamente
# 2. Se há erros nos logs do relayer sobre checkpoints
# 3. Se o relayer está tentando processar a mensagem
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

SEQUENCE="12768"
DOMAIN_ORIGIN="97"  # BSC Testnet
DOMAIN_DEST="1325"  # Terra Classic Testnet

# Tentar descobrir container do relayer
RELAYER_CONTAINERS=(
    "hpl-relayer-testnet"
    "hpl-relayer"
    "relayer"
)

RELAYER_CONTAINER=""
RELAYER_API=""

# ============================================================================
# INÍCIO
# ============================================================================

print_header "VERIFICAR CHECKPOINTS VIA RELAYER"

print_info "Como não temos acesso aos buckets S3 dos validators, vamos verificar"
print_info "se o relayer consegue descobrir e ler os checkpoints automaticamente."
echo ""

# ============================================================================
# PASSO 1: Descobrir Container do Relayer
# ============================================================================

print_section "PASSO 1: DESCOBRIR CONTAINER DO RELAYER"

for CONTAINER in "${RELAYER_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
        RELAYER_CONTAINER="$CONTAINER"
        print_success "✅ Container encontrado: $RELAYER_CONTAINER"
        
        # Tentar descobrir porta da API
        PORT=$(docker port "$RELAYER_CONTAINER" 2>/dev/null | grep "9090" | cut -d: -f2 | head -1 || echo "")
        if [ ! -z "$PORT" ]; then
            RELAYER_API="http://localhost:${PORT}"
            print_success "✅ API do relayer: $RELAYER_API"
        else
            print_warning "⚠️  Não foi possível descobrir porta da API"
        fi
        break
    fi
done

if [ -z "$RELAYER_CONTAINER" ]; then
    print_warning "⚠️  Container do relayer não encontrado localmente"
    print_info "O relayer pode estar rodando no Easypanel"
    print_info "Você pode fornecer os logs do relayer para análise"
    echo ""
    print_info "Para usar com logs do Easypanel:"
    print_value "  1. Copie os logs do relayer do Easypanel"
    print_value "  2. Salve em um arquivo: relayer-logs.txt"
    print_value "  3. Execute: ./verificar-checkpoints-via-relayer.sh relayer-logs.txt"
    echo ""
    
    # Verificar se um arquivo foi fornecido
    if [ $# -gt 0 ] && [ -f "$1" ]; then
        LOG_FILE="$1"
        print_info "Usando arquivo de log: $LOG_FILE"
        USE_FILE=true
    else
        USE_FILE=false
        print_error "❌ Nenhum arquivo de log fornecido"
        exit 1
    fi
else
    USE_FILE=false
fi

# ============================================================================
# PASSO 2: Verificar Logs do Relayer sobre Checkpoints
# ============================================================================

print_section "PASSO 2: VERIFICAR LOGS SOBRE CHECKPOINTS"

if [ "$USE_FILE" = true ]; then
    print_info "Analisando arquivo de log: $LOG_FILE"
    LOGS=$(cat "$LOG_FILE")
else
    print_info "Analisando logs do container: $RELAYER_CONTAINER"
    LOGS=$(docker logs --tail 10000 "$RELAYER_CONTAINER" 2>&1)
fi

# Procurar por erros relacionados a checkpoints
print_info "Procurando por erros relacionados a checkpoints..."

CHECKPOINT_ERRORS=$(echo "$LOGS" | grep -iE "checkpoint.*error|error.*checkpoint|checkpoint.*fail|fail.*checkpoint|checkpoint.*not found|unable.*checkpoint" || echo "")

if [ ! -z "$CHECKPOINT_ERRORS" ]; then
    print_error "❌ Erros encontrados relacionados a checkpoints:"
    echo ""
    echo "$CHECKPOINT_ERRORS" | tail -20
else
    print_success "✅ Nenhum erro explícito sobre checkpoints encontrado"
fi

echo ""

# Procurar por tentativas de ler checkpoints
print_info "Procurando por tentativas de ler checkpoints..."

CHECKPOINT_READS=$(echo "$LOGS" | grep -iE "read.*checkpoint|fetch.*checkpoint|load.*checkpoint|checkpoint.*read|checkpoint.*fetch|s3.*checkpoint" || echo "")

if [ ! -z "$CHECKPOINT_READS" ]; then
    print_info "Tentativas de ler checkpoints encontradas:"
    echo ""
    echo "$CHECKPOINT_READS" | tail -20
else
    print_warning "⚠️  Nenhuma tentativa de ler checkpoints encontrada nos logs"
fi

echo ""

# Procurar por descoberta de validators
print_info "Procurando por descoberta de validators..."

VALIDATOR_DISCOVERY=$(echo "$LOGS" | grep -iE "discover.*validator|found.*validator|validator.*announce|announce.*validator" || echo "")

if [ ! -z "$VALIDATOR_DISCOVERY" ]; then
    print_info "Logs de descoberta de validators:"
    echo ""
    echo "$VALIDATOR_DISCOVERY" | tail -20
else
    print_warning "⚠️  Nenhum log de descoberta de validators encontrado"
fi

echo ""

# ============================================================================
# PASSO 3: Verificar Mensagem Específica (Sequence 12768)
# ============================================================================

print_section "PASSO 3: VERIFICAR MENSAGEM SEQUENCE $SEQUENCE"

print_info "Procurando logs relacionados à sequence $SEQUENCE..."

SEQUENCE_LOGS=$(echo "$LOGS" | grep -i "$SEQUENCE" || echo "")

if [ ! -z "$SEQUENCE_LOGS" ]; then
    print_success "✅ Logs encontrados para sequence $SEQUENCE:"
    echo ""
    echo "$SEQUENCE_LOGS" | tail -30
else
    print_warning "⚠️  Nenhum log encontrado para sequence $SEQUENCE"
fi

echo ""

# ============================================================================
# PASSO 4: Verificar Pool Size e Processamento
# ============================================================================

print_section "PASSO 4: VERIFICAR POOL SIZE E PROCESSAMENTO"

print_info "Verificando pool size e processamento de mensagens..."

POOL_LOGS=$(echo "$LOGS" | grep -iE "pool_size|finality.*pool|processing.*message" | tail -20 || echo "")

if [ ! -z "$POOL_LOGS" ]; then
    print_info "Logs de pool e processamento:"
    echo ""
    echo "$POOL_LOGS"
    
    # Verificar se pool_size está em 0
    POOL_SIZE_ZERO=$(echo "$POOL_LOGS" | grep -i "pool_size.*0" || echo "")
    if [ ! -z "$POOL_SIZE_ZERO" ]; then
        print_warning "⚠️  Pool size está em 0 - mensagens não estão sendo processadas"
    fi
else
    print_warning "⚠️  Nenhum log de pool encontrado"
fi

echo ""

# ============================================================================
# PASSO 5: Verificar Validação de Mensagens
# ============================================================================

print_section "PASSO 5: VERIFICAR VALIDAÇÃO DE MENSAGENS"

print_info "Procurando por logs de validação de mensagens..."

VALIDATION_LOGS=$(echo "$LOGS" | grep -iE "verify.*message|validate.*message|message.*verify|message.*validate|signature.*verify|proof.*verify" | tail -20 || echo "")

if [ ! -z "$VALIDATION_LOGS" ]; then
    print_info "Logs de validação:"
    echo ""
    echo "$VALIDATION_LOGS"
else
    print_warning "⚠️  Nenhum log de validação encontrado"
fi

echo ""

# ============================================================================
# RESUMO E CONCLUSÃO
# ============================================================================

print_section "RESUMO E CONCLUSÃO"

print_info "Análise dos logs do relayer:"
echo ""

# Contar ocorrências
ERROR_COUNT=$(echo "$LOGS" | grep -iE "error|fail" | wc -l)
CHECKPOINT_MENTIONS=$(echo "$LOGS" | grep -i "checkpoint" | wc -l)
VALIDATOR_MENTIONS=$(echo "$LOGS" | grep -i "validator" | wc -l)

print_value "Erros encontrados: $ERROR_COUNT"
print_value "Menções a checkpoints: $CHECKPOINT_MENTIONS"
print_value "Menções a validators: $VALIDATOR_MENTIONS"
echo ""

# Conclusão
if [ ! -z "$CHECKPOINT_ERRORS" ]; then
    print_error "❌ PROBLEMA: Erros relacionados a checkpoints encontrados"
    print_info "O relayer está tendo problemas para ler checkpoints"
elif [ -z "$CHECKPOINT_READS" ]; then
    print_warning "⚠️  ATENÇÃO: Nenhuma tentativa de ler checkpoints encontrada"
    print_info "O relayer pode não estar tentando ler checkpoints"
elif [ ! -z "$POOL_SIZE_ZERO" ]; then
    print_warning "⚠️  ATENÇÃO: Pool size está em 0"
    print_info "Mensagens não estão sendo processadas"
else
    print_success "✅ Não foram encontrados problemas óbvios nos logs"
    print_info "O relayer pode estar funcionando corretamente"
fi

echo ""
print_info "Próximos passos:"
print_value "1. Verificar se há validators do BSC rodando e gerando checkpoints"
print_value "2. Verificar se os checkpoints estão sendo salvos no S3"
print_value "3. Verificar se o relayer tem acesso de leitura aos buckets S3"
print_value "4. Verificar logs mais detalhados do relayer no Easypanel"

echo ""
print_success "✅ Análise concluída!"
