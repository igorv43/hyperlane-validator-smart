#!/bin/bash

# ============================================================================
# Script: Diagnosticar Problema do Relayer - BSC -> Terra Classic
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

CONTAINER_NAME="hpl-relayer-testnet-local"
COMPOSE_FILE="teste-relayer/docker-compose-relayer-only.yml"

# ============================================================================
# INÍCIO
# ============================================================================

print_header "DIAGNÓSTICO: PROBLEMA RELAYER BSC -> TERRA CLASSIC"

# ============================================================================
# PASSO 1: Verificar se Relayer está Rodando
# ============================================================================

print_section "PASSO 1: VERIFICAR SE RELAYER ESTÁ RODANDO"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_success "✅ Relayer está rodando: $CONTAINER_NAME"
    CONTAINER_STATUS=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")
    print_value "Status: $CONTAINER_STATUS"
else
    print_error "❌ Relayer não está rodando!"
    print_info "Execute: cd teste-relayer && docker compose -f docker-compose-relayer-only.yml up -d relayer"
    exit 1
fi

echo ""

# ============================================================================
# PASSO 2: Verificar Logs de Erros
# ============================================================================

print_section "PASSO 2: VERIFICAR ERROS NOS LOGS"

print_info "Procurando por erros relacionados a checkpoints, validators e S3..."

ERRORS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "error|fail|warn" | grep -iE "checkpoint|validator|s3|bucket|quorum|insufficient|not found" | tail -20 || echo "")

if [ ! -z "$ERRORS" ]; then
    print_error "❌ Erros encontrados:"
    echo ""
    echo "$ERRORS"
else
    print_success "✅ Nenhum erro explícito encontrado nos logs"
fi

echo ""

# ============================================================================
# PASSO 3: Verificar Mensagem Sequence 12768
# ============================================================================

print_section "PASSO 3: VERIFICAR MENSAGEM SEQUENCE $SEQUENCE"

print_info "Procurando por logs relacionados à sequence $SEQUENCE..."

SEQUENCE_LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "$SEQUENCE" | tail -10 || echo "")

if [ ! -z "$SEQUENCE_LOGS" ]; then
    print_success "✅ Mensagem sequence $SEQUENCE encontrada nos logs:"
    echo ""
    echo "$SEQUENCE_LOGS" | head -5
else
    print_warning "⚠️  Mensagem sequence $SEQUENCE não encontrada nos logs recentes"
fi

echo ""

# ============================================================================
# PASSO 4: Verificar Pool Size
# ============================================================================

print_section "PASSO 4: VERIFICAR POOL SIZE"

print_info "Verificando pool size (últimas 20 ocorrências)..."

POOL_LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "pool_size" | tail -20 || echo "")

if [ ! -z "$POOL_LOGS" ]; then
    POOL_SIZE=$(echo "$POOL_LOGS" | tail -1 | grep -oE "pool_size[^,]*" | grep -oE "[0-9]+" || echo "0")
    print_info "Pool size atual: $POOL_SIZE"
    
    if [ "$POOL_SIZE" = "0" ]; then
        print_warning "⚠️  Pool size está em 0 - mensagens não estão sendo processadas"
    else
        print_success "✅ Pool size: $POOL_SIZE - mensagens estão no pool"
    fi
    
    echo ""
    echo "Últimas ocorrências:"
    echo "$POOL_LOGS" | tail -5
else
    print_warning "⚠️  Nenhum log de pool_size encontrado"
fi

echo ""

# ============================================================================
# PASSO 5: Verificar Tentativas de Ler Checkpoints
# ============================================================================

print_section "PASSO 5: VERIFICAR TENTATIVAS DE LER CHECKPOINTS"

print_info "Procurando por tentativas de ler checkpoints do S3..."

CHECKPOINT_LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "checkpoint|s3|bucket|validator.*announce|storage.*location" | tail -30 || echo "")

if [ ! -z "$CHECKPOINT_LOGS" ]; then
    print_info "Logs relacionados a checkpoints encontrados:"
    echo ""
    echo "$CHECKPOINT_LOGS" | head -10
else
    print_warning "⚠️  Nenhuma tentativa de ler checkpoints encontrada nos logs"
    print_info "Isso pode indicar que o relayer não está tentando ler checkpoints"
fi

echo ""

# ============================================================================
# PASSO 6: Verificar Descoberta de Validators
# ============================================================================

print_section "PASSO 6: VERIFICAR DESCOBERTA DE VALIDATORS"

print_info "Procurando por logs de descoberta de validators..."

VALIDATOR_LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "discover.*validator|found.*validator|validator.*announce|announce.*validator" | tail -20 || echo "")

if [ ! -z "$VALIDATOR_LOGS" ]; then
    print_success "✅ Logs de descoberta de validators encontrados:"
    echo ""
    echo "$VALIDATOR_LOGS" | head -5
else
    print_warning "⚠️  Nenhum log de descoberta de validators encontrado"
    print_info "O relayer pode não estar consultando o ValidatorAnnounce"
fi

echo ""

# ============================================================================
# PASSO 7: Verificar Validação de Mensagens
# ============================================================================

print_section "PASSO 7: VERIFICAR VALIDAÇÃO DE MENSAGENS"

print_info "Procurando por logs de validação de mensagens..."

VALIDATION_LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "verify.*message|validate.*message|message.*verify|message.*validate|signature.*verify|proof.*verify|quorum" | tail -20 || echo "")

if [ ! -z "$VALIDATION_LOGS" ]; then
    print_info "Logs de validação encontrados:"
    echo ""
    echo "$VALIDATION_LOGS" | head -5
else
    print_warning "⚠️  Nenhum log de validação encontrado"
    print_info "O relayer pode não estar tentando validar mensagens"
fi

echo ""

# ============================================================================
# PASSO 8: Verificar Configuração do Relayer
# ============================================================================

print_section "PASSO 8: VERIFICAR CONFIGURAÇÃO DO RELAYER"

print_info "Verificando se o relayer está configurado para ler checkpoints do S3..."

CONFIG_CHECK=$(docker exec "$CONTAINER_NAME" cat /etc/hyperlane/relayer.testnet.json 2>/dev/null | grep -iE "allowLocalCheckpointSyncers|checkpoint" || echo "")

if [ ! -z "$CONFIG_CHECK" ]; then
    print_info "Configuração encontrada:"
    echo "$CONFIG_CHECK"
    
    if echo "$CONFIG_CHECK" | grep -qi "allowLocalCheckpointSyncers.*false"; then
        print_success "✅ Relayer configurado para ler checkpoints do S3 (allowLocalCheckpointSyncers: false)"
    else
        print_warning "⚠️  allowLocalCheckpointSyncers pode estar em true"
    fi
else
    print_warning "⚠️  Não foi possível verificar a configuração"
fi

echo ""

# ============================================================================
# RESUMO E DIAGNÓSTICO
# ============================================================================

print_section "RESUMO E DIAGNÓSTICO"

print_info "Análise dos logs do relayer:"
echo ""

# Contar ocorrências
ERROR_COUNT=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "error|fail" | wc -l)
CHECKPOINT_MENTIONS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "checkpoint" | wc -l)
VALIDATOR_MENTIONS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "validator" | wc -l)
POOL_SIZE_ZERO=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "pool_size.*0" | wc -l)

print_value "Total de erros: $ERROR_COUNT"
print_value "Menções a checkpoints: $CHECKPOINT_MENTIONS"
print_value "Menções a validators: $VALIDATOR_MENTIONS"
print_value "Ocorrências de pool_size: 0: $POOL_SIZE_ZERO"

echo ""

# Diagnóstico
print_info "🔍 DIAGNÓSTICO:"

if [ "$POOL_SIZE_ZERO" -gt 10 ]; then
    print_warning "⚠️  PROBLEMA IDENTIFICADO: Pool size está consistentemente em 0"
    echo ""
    print_info "Possíveis causas:"
    print_value "1. Checkpoints não estão disponíveis no S3"
    print_value "2. Relayer não consegue descobrir validators do ValidatorAnnounce"
    print_value "3. Quorum insuficiente (menos de 2 de 3 checkpoints disponíveis)"
    print_value "4. Erro ao ler checkpoints do S3 (credenciais AWS, permissões, etc.)"
    echo ""
    print_info "✅ SOLUÇÕES:"
    print_value "1. Verificar se validators estão gerando checkpoints para BSC"
    print_value "2. Verificar se checkpoints estão no S3 e acessíveis"
    print_value "3. Verificar se relayer tem credenciais AWS configuradas"
    print_value "4. Verificar se validators estão anunciados no ValidatorAnnounce do BSC"
    print_value "5. Verificar logs mais detalhados: docker logs -f $CONTAINER_NAME"
fi

if [ "$CHECKPOINT_MENTIONS" -eq 0 ]; then
    print_warning "⚠️  ATENÇÃO: Nenhuma menção a checkpoints nos logs"
    print_info "O relayer pode não estar tentando ler checkpoints"
fi

if [ "$VALIDATOR_MENTIONS" -eq 0 ]; then
    print_warning "⚠️  ATENÇÃO: Nenhuma menção a validators nos logs"
    print_info "O relayer pode não estar consultando o ValidatorAnnounce"
fi

echo ""
print_success "✅ Diagnóstico concluído!"
