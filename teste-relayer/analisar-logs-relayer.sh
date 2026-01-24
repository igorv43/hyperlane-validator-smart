#!/bin/bash

# ============================================================================
# Script: Analisar Logs do Relayer para BSC -> Terra Classic
# ============================================================================
# Este script analisa os logs do relayer procurando por erros relacionados a:
# - Checkpoints
# - Validators
# - S3
# - Validação de mensagens
# - Sequence 12768 (mensagem específica)
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

CONTAINER_NAME="hpl-relayer-testnet"
SEQUENCE="12768"

# ============================================================================
# INÍCIO
# ============================================================================

print_header "ANALISAR LOGS DO RELAYER - BSC -> TERRA CLASSIC"

# Verificar se container existe
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_warning "⚠️  Container $CONTAINER_NAME não encontrado localmente!"
    print_info "O container pode estar rodando no Easypanel."
    echo ""
    print_info "Para analisar logs do Easypanel, você pode:"
    print_value "1. Copiar os logs do Easypanel e salvar em um arquivo"
    print_value "2. Executar este script com: ./analisar-logs-relayer.sh <arquivo_log>"
    echo ""
    print_info "Ou executar os comandos manualmente no Easypanel:"
    print_value "  grep -i '12768' nos logs"
    print_value "  grep -i 'checkpoint\|s3\|bucket' nos logs"
    print_value "  grep -i 'validator\|announce' nos logs"
    echo ""
    
    # Se um arquivo foi fornecido como argumento, usar ele
    if [ $# -gt 0 ] && [ -f "$1" ]; then
        LOG_FILE="$1"
        print_info "Usando arquivo de log: $LOG_FILE"
        USE_FILE=true
    else
        print_error "❌ Nenhum arquivo de log fornecido e container não encontrado"
        exit 1
    fi
else
    USE_FILE=false
fi

print_info "Container: $CONTAINER_NAME"
print_info "Analisando logs (últimas 5000 linhas)..."
echo ""

# ============================================================================
# 1. MENSAGEM ESPECÍFICA (SEQUENCE 12768)
# ============================================================================

print_section "1. MENSAGEM SEQUENCE 12768"

print_info "Procurando logs relacionados à sequence 12768..."

if [ "$USE_FILE" = true ]; then
    SEQUENCE_LOGS=$(grep -i "12768" "$LOG_FILE" || echo "")
else
    SEQUENCE_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -i "12768" || echo "")
fi

if [ ! -z "$SEQUENCE_LOGS" ]; then
    print_success "✅ Logs encontrados para sequence 12768:"
    echo ""
    echo "$SEQUENCE_LOGS" | tail -20
else
    print_warning "⚠️  Nenhum log encontrado para sequence 12768"
fi

echo ""

# ============================================================================
# 2. ERROS RELACIONADOS A CHECKPOINTS
# ============================================================================

print_section "2. ERROS RELACIONADOS A CHECKPOINTS"

print_info "Procurando erros relacionados a checkpoints..."

if [ "$USE_FILE" = true ]; then
    CHECKPOINT_ERRORS=$(grep -iE "checkpoint|s3|bucket" "$LOG_FILE" | grep -iE "error|fail|warn" || echo "")
else
    CHECKPOINT_ERRORS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "checkpoint|s3|bucket" | grep -iE "error|fail|warn" || echo "")
fi

if [ ! -z "$CHECKPOINT_ERRORS" ]; then
    print_error "❌ Erros encontrados relacionados a checkpoints:"
    echo ""
    echo "$CHECKPOINT_ERRORS" | tail -30
else
    print_success "✅ Nenhum erro relacionado a checkpoints encontrado"
fi

echo ""

# ============================================================================
# 3. ERROS RELACIONADOS A VALIDATORS
# ============================================================================

print_section "3. ERROS RELACIONADOS A VALIDATORS"

print_info "Procurando erros relacionados a validators..."

if [ "$USE_FILE" = true ]; then
    VALIDATOR_ERRORS=$(grep -iE "validator|announce" "$LOG_FILE" | grep -iE "error|fail|warn|not found" || echo "")
else
    VALIDATOR_ERRORS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "validator|announce" | grep -iE "error|fail|warn|not found" || echo "")
fi

if [ ! -z "$VALIDATOR_ERRORS" ]; then
    print_error "❌ Erros encontrados relacionados a validators:"
    echo ""
    echo "$VALIDATOR_ERRORS" | tail -30
else
    print_success "✅ Nenhum erro relacionado a validators encontrado"
fi

echo ""

# ============================================================================
# 4. MENSAGENS SOBRE VALIDAÇÃO
# ============================================================================

print_section "4. MENSAGENS SOBRE VALIDAÇÃO"

print_info "Procurando mensagens sobre validação de mensagens..."

if [ "$USE_FILE" = true ]; then
    VALIDATION_LOGS=$(grep -iE "verify|validate|signature|proof" "$LOG_FILE" | grep -iE "error|fail|warn" || echo "")
else
    VALIDATION_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "verify|validate|signature|proof" | grep -iE "error|fail|warn" || echo "")
fi

if [ ! -z "$VALIDATION_LOGS" ]; then
    print_error "❌ Erros encontrados relacionados a validação:"
    echo ""
    echo "$VALIDATION_LOGS" | tail -30
else
    print_success "✅ Nenhum erro relacionado a validação encontrado"
fi

echo ""

# ============================================================================
# 5. POOL SIZE E PROCESSAMENTO
# ============================================================================

print_section "5. POOL SIZE E PROCESSAMENTO DE MENSAGENS"

print_info "Verificando pool size e processamento..."

if [ "$USE_FILE" = true ]; then
    POOL_LOGS=$(grep -iE "pool_size|finality.*pool|processing.*message" "$LOG_FILE" | tail -20 || echo "")
else
    POOL_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "pool_size|finality.*pool|processing.*message" | tail -20 || echo "")
fi

if [ ! -z "$POOL_LOGS" ]; then
    print_info "Logs de pool e processamento:"
    echo ""
    echo "$POOL_LOGS"
else
    print_warning "⚠️  Nenhum log de pool encontrado"
fi

echo ""

# ============================================================================
# 6. DESCOBERTA DE VALIDATORS
# ============================================================================

print_section "6. DESCOBERTA DE VALIDATORS"

print_info "Procurando logs sobre descoberta de validators..."

if [ "$USE_FILE" = true ]; then
    DISCOVERY_LOGS=$(grep -iE "discover|found.*validator|announce.*validator" "$LOG_FILE" || echo "")
else
    DISCOVERY_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "discover|found.*validator|announce.*validator" || echo "")
fi

if [ ! -z "$DISCOVERY_LOGS" ]; then
    print_info "Logs de descoberta de validators:"
    echo ""
    echo "$DISCOVERY_LOGS" | tail -20
else
    print_warning "⚠️  Nenhum log de descoberta de validators encontrado"
fi

echo ""

# ============================================================================
# 7. LEITURA DE CHECKPOINTS DO S3
# ============================================================================

print_section "7. LEITURA DE CHECKPOINTS DO S3"

print_info "Procurando logs sobre leitura de checkpoints do S3..."

if [ "$USE_FILE" = true ]; then
    S3_LOGS=$(grep -iE "s3|bucket|checkpoint.*read|fetch.*checkpoint" "$LOG_FILE" || echo "")
else
    S3_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "s3|bucket|checkpoint.*read|fetch.*checkpoint" || echo "")
fi

if [ ! -z "$S3_LOGS" ]; then
    print_info "Logs de leitura de checkpoints:"
    echo ""
    echo "$S3_LOGS" | tail -30
else
    print_warning "⚠️  Nenhum log de leitura de checkpoints encontrado"
fi

echo ""

# ============================================================================
# 8. ERROS GERAIS
# ============================================================================

print_section "8. ERROS GERAIS (ÚLTIMOS 50)"

print_info "Últimos 50 erros encontrados nos logs..."

if [ "$USE_FILE" = true ]; then
    ALL_ERRORS=$(grep -iE "error|fail|panic|exception" "$LOG_FILE" | tail -50 || echo "")
else
    ALL_ERRORS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "error|fail|panic|exception" | tail -50 || echo "")
fi

if [ ! -z "$ALL_ERRORS" ]; then
    print_error "Erros encontrados:"
    echo ""
    echo "$ALL_ERRORS"
else
    print_success "✅ Nenhum erro encontrado nos logs recentes"
fi

echo ""

# ============================================================================
# RESUMO
# ============================================================================

print_section "RESUMO DA ANÁLISE"

print_info "Análise concluída. Verifique as seções acima para detalhes."
echo ""
print_info "Para ver logs em tempo real:"
print_value "  docker logs -f $CONTAINER_NAME"
echo ""
print_info "Para ver logs completos:"
print_value "  docker logs $CONTAINER_NAME 2>&1 | grep -i 'checkpoint\|validator\|12768'"
echo ""

print_success "✅ Análise concluída!"
