#!/bin/bash

# ============================================================================
# Script: Executar Relayer Localmente e Analisar Checkpoints
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

print_info() { echo -e "${BLUE}ℹ️${NC}  $1"; }
print_success() { echo -e "${GREEN}✅${NC}  $1"; }
print_error() { echo -e "${RED}❌${NC}  $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC}  $1"; }

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-relayer-only.yml"
CONTAINER_NAME="hpl-relayer-testnet-local"

# ============================================================================
# INÍCIO
# ============================================================================

print_header "EXECUTAR RELAYER LOCALMENTE E ANALISAR CHECKPOINTS"

# Verificar se Docker está rodando
print_info "Verificando se Docker está rodando..."
if ! docker ps > /dev/null 2>&1; then
    print_error "❌ Docker daemon não está rodando!"
    echo ""
    print_info "Por favor, inicie o Docker Desktop e tente novamente."
    print_info "Ou execute: sudo service docker start"
    exit 1
fi

print_success "✅ Docker está rodando"
echo ""

# Parar e remover container antigo
print_info "Parando e removendo container antigo (se existir)..."
cd "$SCRIPT_DIR"
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
print_success "✅ Containers antigos removidos"
echo ""

# Iniciar relayer
print_info "Iniciando relayer..."
docker compose -f "$COMPOSE_FILE" up -d relayer

# Aguardar container iniciar
print_info "Aguardando container iniciar..."
sleep 5

# Verificar status
print_info "Verificando status do container..."
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_success "✅ Container está rodando: $CONTAINER_NAME"
else
    print_error "❌ Container não está rodando!"
    print_info "Verificando logs para erros..."
    docker compose -f "$COMPOSE_FILE" logs relayer | tail -50
    exit 1
fi

echo ""

# Mostrar logs iniciais
print_info "Logs iniciais do relayer:"
echo ""
docker compose -f "$COMPOSE_FILE" logs --tail 50 relayer

echo ""
print_success "✅ Relayer iniciado com sucesso!"
echo ""

# Instruções
print_info "Para ver logs em tempo real:"
print_warning "  docker compose -f $COMPOSE_FILE logs -f relayer"
echo ""

print_info "Para parar o relayer:"
print_warning "  docker compose -f $COMPOSE_FILE down"
echo ""

print_info "Para analisar checkpoints, execute:"
print_warning "  cd $SCRIPT_DIR/.."
print_warning "  ./verificar-checkpoints-via-relayer.sh"
echo ""

print_success "✅ Script concluído!"
