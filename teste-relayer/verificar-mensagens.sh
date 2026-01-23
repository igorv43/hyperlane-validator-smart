#!/bin/bash

# Script para verificar se mensagens foram enviadas do Terra Classic para BSC

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         VERIFICAÇÃO: MENSAGENS TERRA CLASSIC → BSC                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

CONTAINER_NAME="hpl-relayer-testnet-local"

print_header

# 1. Verificar se container está rodando
print_section "1. Status do Container"
if docker ps | grep -q "$CONTAINER_NAME"; then
    print_success "Container está rodando"
    docker ps | grep "$CONTAINER_NAME"
else
    print_error "Container não está rodando"
    exit 1
fi

# 2. Verificar pool de mensagens
print_section "2. Pool de Mensagens (prontas para enviar)"
POOL_LOGS=$(docker logs --tail 2000 "$CONTAINER_NAME" 2>&1 | grep -i "pool_size\|finality.*pool" | tail -n 10)
if [ -n "$POOL_LOGS" ]; then
    echo "$POOL_LOGS"
    POOL_SIZE=$(echo "$POOL_LOGS" | grep -o "pool_size: [0-9]*" | tail -n 1 | grep -o "[0-9]*" || echo "0")
    if [ -n "$POOL_SIZE" ] && [ "$POOL_SIZE" != "0" ]; then
        print_success "Há $POOL_SIZE mensagem(ns) no pool"
    else
        print_warning "Pool está vazio (size: 0) - pode ser normal se não houver mensagens novas"
    fi
else
    print_warning "Não foi possível encontrar logs do pool"
fi

# 3. Verificar mensagens processadas
print_section "3. Mensagens Processadas"
MSG_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -iE "processing.*message|message.*1325|message.*97|retry.*message|deliver.*message" | tail -n 20)
if [ -n "$MSG_LOGS" ]; then
    print_success "Encontrados logs de processamento de mensagens:"
    echo "$MSG_LOGS"
else
    print_warning "Nenhum log de processamento de mensagens encontrado"
fi

# 4. Verificar sequências de mensagens
print_section "4. Sequências de Mensagens Detectadas"
SEQ_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -E "sequence.*[0-9]+|num_logs.*[1-9]" | tail -n 20)
if [ -n "$SEQ_LOGS" ]; then
    print_success "Encontradas sequências de mensagens:"
    echo "$SEQ_LOGS" | head -n 10
else
    print_warning "Nenhuma sequência de mensagens detectada"
fi

# 5. Verificar checkpoints lidos
print_section "5. Checkpoints Lidos do S3"
CP_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -i "checkpoint\|s3.*read\|reading.*checkpoint" | tail -n 20)
if [ -n "$CP_LOGS" ]; then
    print_success "Encontrados logs de leitura de checkpoints:"
    echo "$CP_LOGS" | head -n 10
else
    print_warning "Nenhum log de leitura de checkpoints encontrado"
fi

# 6. Verificar validators descobertos
print_section "6. Validators Descobertos"
VAL_LOGS=$(docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -i "discovering.*validator\|found.*validator\|validator.*announce" | tail -n 20)
if [ -n "$VAL_LOGS" ]; then
    print_success "Encontrados logs de descoberta de validators:"
    echo "$VAL_LOGS" | head -n 10
else
    print_warning "Nenhum log de descoberta de validators encontrado"
fi

# 7. Verificar sincronização do Terra Classic
print_section "7. Sincronização do Terra Classic"
SYNC_LOGS=$(docker logs --tail 2000 "$CONTAINER_NAME" 2>&1 | grep -i "terraclassictestnet.*1325" | grep -i "synced\|found.*log" | tail -n 10)
if [ -n "$SYNC_LOGS" ]; then
    print_success "Terra Classic está sincronizando:"
    echo "$SYNC_LOGS" | head -n 5
else
    print_warning "Não foi possível verificar sincronização do Terra Classic"
fi

# 8. Resumo
print_section "8. Resumo"
echo ""
echo "Status da verificação:"
echo ""

# Contar mensagens no pool
POOL_COUNT=$(docker logs --tail 2000 "$CONTAINER_NAME" 2>&1 | grep -o "pool_size: [0-9]*" | tail -n 1 | grep -o "[0-9]*" || echo "0")
if [ "$POOL_COUNT" != "0" ] && [ -n "$POOL_COUNT" ]; then
    print_success "Pool de mensagens: $POOL_COUNT mensagem(ns) prontas para enviar"
else
    print_warning "Pool de mensagens: vazio (0 mensagens)"
fi

# Verificar se há logs de processamento
if docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -qiE "processing.*message|retry.*message|deliver.*message"; then
    print_success "Há evidências de mensagens sendo processadas"
else
    print_warning "Nenhuma evidência de mensagens sendo processadas"
fi

# Verificar se há checkpoints
if docker logs --tail 5000 "$CONTAINER_NAME" 2>&1 | grep -qi "checkpoint"; then
    print_success "Há evidências de checkpoints sendo lidos"
else
    print_warning "Nenhuma evidência de checkpoints sendo lidos"
fi

echo ""
print_info "Para ver logs em tempo real:"
echo "  docker logs -f $CONTAINER_NAME | grep -i 'message\|pool\|checkpoint'"
echo ""
