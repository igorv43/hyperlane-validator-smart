#!/bin/bash

# ============================================================================
# Script: Diagnóstico Completo do Relayer - BSC -> Terra Classic
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

RELAYER_CONTAINER="hpl-relayer-testnet-local"
SEQUENCE="12768"  # Mensagem que deveria ter sido processada

# ============================================================================
# INÍCIO
# ============================================================================

print_header "DIAGNÓSTICO COMPLETO: RELAYER BSC -> TERRA CLASSIC"

# ============================================================================
# PASSO 1: Verificar Status do Container
# ============================================================================

print_section "PASSO 1: STATUS DO CONTAINER"

if docker ps -f name="$RELAYER_CONTAINER" --format "{{.Names}}" | grep -q "$RELAYER_CONTAINER"; then
    print_success "✅ Container está rodando: $RELAYER_CONTAINER"
    
    # Obter informações do container
    CONTAINER_STATUS=$(docker ps -f name="$RELAYER_CONTAINER" --format "{{.Status}}")
    print_value "Status: $CONTAINER_STATUS"
    
    # Verificar há quanto tempo está rodando
    UPTIME=$(docker ps -f name="$RELAYER_CONTAINER" --format "{{.Status}}" | grep -oE "Up [0-9]+" || echo "Desconhecido")
    print_value "Uptime: $UPTIME"
else
    print_error "❌ Container não está rodando: $RELAYER_CONTAINER"
    
    # Verificar se existe mas está parado
    if docker ps -a -f name="$RELAYER_CONTAINER" --format "{{.Names}}" | grep -q "$RELAYER_CONTAINER"; then
        print_warning "⚠️  Container existe mas está parado"
        print_info "Para iniciar: cd teste-relayer && docker compose -f docker-compose-relayer-only.yml up -d"
    else
        print_error "❌ Container não existe"
    fi
    exit 1
fi

echo ""

# ============================================================================
# PASSO 2: Verificar Logs Recentes
# ============================================================================

print_section "PASSO 2: LOGS RECENTES DO RELAYER"

print_info "Obtendo últimos 100 linhas de logs..."
RELAYER_LOGS=$(docker logs "$RELAYER_CONTAINER" --tail 100 2>&1)

if [ -z "$RELAYER_LOGS" ]; then
    print_error "❌ Nenhum log encontrado"
else
    print_success "✅ Logs obtidos"
    
    # Verificar se há erros críticos
    ERROR_COUNT=$(echo "$RELAYER_LOGS" | grep -iE "error|fatal|panic" | grep -v "level=error" | wc -l)
    if [ "$ERROR_COUNT" -gt 0 ]; then
        print_warning "⚠️  Encontrados $ERROR_COUNT erros nos logs recentes"
        echo ""
        echo "$RELAYER_LOGS" | grep -iE "error|fatal|panic" | grep -v "level=error" | head -10
    else
        print_success "✅ Nenhum erro crítico encontrado nos logs recentes"
    fi
fi

echo ""

# ============================================================================
# PASSO 3: Verificar Sincronização das Chains
# ============================================================================

print_section "PASSO 3: SINCRONIZAÇÃO DAS CHAINS"

print_info "Verificando sincronização BSC e Terra Classic..."

# Verificar logs de sincronização
BSC_SYNC=$(echo "$RELAYER_LOGS" | grep -i "bsctestnet\|bsc" | grep -iE "synced|sync|index" | tail -5)
TERRA_SYNC=$(echo "$RELAYER_LOGS" | grep -i "terraclassic\|terra" | grep -iE "synced|sync|index" | tail -5)

if [ ! -z "$BSC_SYNC" ]; then
    print_success "✅ Logs de sincronização BSC encontrados:"
    echo "$BSC_SYNC"
else
    print_warning "⚠️  Nenhum log de sincronização BSC encontrado"
fi

echo ""

if [ ! -z "$TERRA_SYNC" ]; then
    print_success "✅ Logs de sincronização Terra Classic encontrados:"
    echo "$TERRA_SYNC"
else
    print_warning "⚠️  Nenhum log de sincronização Terra Classic encontrado"
fi

echo ""

# ============================================================================
# PASSO 4: Verificar Detecção de Mensagens
# ============================================================================

print_section "PASSO 4: DETECÇÃO DE MENSAGENS"

print_info "Procurando por mensagens detectadas (sequence $SEQUENCE ou próximas)..."

# Procurar por sequence específica
MESSAGE_LOGS=$(echo "$RELAYER_LOGS" | grep -iE "sequence.*$SEQUENCE|message.*$SEQUENCE|1276[0-9]" | head -20)

if [ ! -z "$MESSAGE_LOGS" ]; then
    print_success "✅ Mensagens encontradas nos logs:"
    echo "$MESSAGE_LOGS"
else
    print_warning "⚠️  Nenhuma mensagem com sequence $SEQUENCE encontrada nos logs recentes"
    
    # Procurar por qualquer mensagem
    ANY_MESSAGE=$(echo "$RELAYER_LOGS" | grep -iE "message|sequence" | tail -10)
    if [ ! -z "$ANY_MESSAGE" ]; then
        print_info "Últimas mensagens detectadas:"
        echo "$ANY_MESSAGE"
    fi
fi

echo ""

# ============================================================================
# PASSO 5: Verificar Checkpoints e Validators
# ============================================================================

print_section "PASSO 5: CHECKPOINTS E VALIDATORS"

print_info "Procurando por erros relacionados a checkpoints, validators e S3..."

# Erros relacionados a checkpoints
CHECKPOINT_ERRORS=$(echo "$RELAYER_LOGS" | grep -iE "checkpoint|validator|s3|bucket|storage" | grep -iE "error|fail|warn" | head -20)

if [ ! -z "$CHECKPOINT_ERRORS" ]; then
    print_warning "⚠️  Erros relacionados a checkpoints/validators encontrados:"
    echo "$CHECKPOINT_ERRORS"
else
    print_info "ℹ️  Nenhum erro explícito de checkpoint/validator encontrado"
fi

echo ""

# Verificar se relayer está tentando ler checkpoints
CHECKPOINT_ATTEMPTS=$(echo "$RELAYER_LOGS" | grep -iE "fetching checkpoint|reading checkpoint|checkpoint.*s3|validator.*announce" | tail -10)

if [ ! -z "$CHECKPOINT_ATTEMPTS" ]; then
    print_success "✅ Relayer está tentando ler checkpoints:"
    echo "$CHECKPOINT_ATTEMPTS"
else
    print_warning "⚠️  Nenhuma tentativa de ler checkpoints encontrada nos logs"
fi

echo ""

# ============================================================================
# PASSO 6: Verificar Pool de Mensagens
# ============================================================================

print_section "PASSO 6: POOL DE MENSAGENS"

print_info "Verificando pool de mensagens pendentes..."

# Procurar por informações de pool
POOL_INFO=$(echo "$RELAYER_LOGS" | grep -iE "pool|pending|queue|delivery" | tail -10)

if [ ! -z "$POOL_INFO" ]; then
    print_info "Informações de pool encontradas:"
    echo "$POOL_INFO"
else
    print_warning "⚠️  Nenhuma informação de pool encontrada"
fi

echo ""

# ============================================================================
# PASSO 7: Verificar API do Relayer
# ============================================================================

print_section "PASSO 7: API DO RELAYER"

print_info "Tentando consultar API do relayer (porta 19010)..."

# Verificar se a porta está aberta
if docker port "$RELAYER_CONTAINER" 2>/dev/null | grep -q "19010"; then
    print_success "✅ Porta 19010 está mapeada"
    
    # Tentar consultar métricas
    METRICS=$(curl -s http://localhost:19010/metrics 2>/dev/null | head -50 || echo "")
    
    if [ ! -z "$METRICS" ]; then
        print_success "✅ Métricas disponíveis:"
        echo "$METRICS" | grep -iE "message|pool|checkpoint|validator" | head -20
    else
        print_warning "⚠️  Não foi possível obter métricas"
    fi
else
    print_warning "⚠️  Porta 19010 não está mapeada ou não está acessível"
fi

echo ""

# ============================================================================
# PASSO 8: Verificar Configuração
# ============================================================================

print_section "PASSO 8: CONFIGURAÇÃO DO RELAYER"

print_info "Verificando arquivos de configuração..."

# Verificar se arquivos de config existem
if [ -f "teste-relayer/docker-compose-relayer-only.yml" ]; then
    print_success "✅ docker-compose-relayer-only.yml existe"
    
    # Verificar se .env existe
    if [ -f ".env" ]; then
        print_success "✅ Arquivo .env existe"
        
        # Verificar variáveis críticas (sem mostrar valores)
        if grep -q "AWS_ACCESS_KEY_ID" .env && grep -q "AWS_SECRET_ACCESS_KEY" .env; then
            print_success "✅ Credenciais AWS configuradas"
        else
            print_warning "⚠️  Credenciais AWS podem não estar configuradas"
        fi
        
        if grep -q "HYP_CHAINS_BSCTESTNET_SIGNER_KEY" .env && grep -q "HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY" .env; then
            print_success "✅ Chaves de signer configuradas"
        else
            print_warning "⚠️  Chaves de signer podem não estar configuradas"
        fi
    else
        print_error "❌ Arquivo .env não encontrado"
    fi
else
    print_error "❌ docker-compose-relayer-only.yml não encontrado"
fi

echo ""

# ============================================================================
# PASSO 9: Análise de Erros Específicos
# ============================================================================

print_section "PASSO 9: ANÁLISE DE ERROS ESPECÍFICOS"

print_info "Procurando por erros específicos relacionados a BSC -> Terra Classic..."

# Erros de quorum
QUORUM_ERRORS=$(echo "$RELAYER_LOGS" | grep -iE "quorum|threshold|signature.*insufficient" | head -10)

if [ ! -z "$QUORUM_ERRORS" ]; then
    print_error "❌ Erros de quorum encontrados:"
    echo "$QUORUM_ERRORS"
fi

# Erros de S3
S3_ERRORS=$(echo "$RELAYER_LOGS" | grep -iE "s3.*error|aws.*error|bucket.*error|access.*denied" | head -10)

if [ ! -z "$S3_ERRORS" ]; then
    print_error "❌ Erros de S3 encontrados:"
    echo "$S3_ERRORS"
fi

# Erros de validator discovery
VALIDATOR_DISCOVERY_ERRORS=$(echo "$RELAYER_LOGS" | grep -iE "validator.*not.*found|validator.*discovery|announce.*error" | head -10)

if [ ! -z "$VALIDATOR_DISCOVERY_ERRORS" ]; then
    print_error "❌ Erros de descoberta de validators encontrados:"
    echo "$VALIDATOR_DISCOVERY_ERRORS"
fi

# Erros de RPC
RPC_ERRORS=$(echo "$RELAYER_LOGS" | grep -iE "rpc.*error|connection.*refused|timeout.*rpc" | head -10)

if [ ! -z "$RPC_ERRORS" ]; then
    print_warning "⚠️  Erros de RPC encontrados:"
    echo "$RPC_ERRORS"
fi

echo ""

# ============================================================================
# PASSO 10: Resumo e Recomendações
# ============================================================================

print_section "RESUMO E RECOMENDAÇÕES"

print_info "Resumo do diagnóstico:"
echo ""

# Contar problemas encontrados
PROBLEMS=0

if [ "$ERROR_COUNT" -gt 0 ]; then
    print_error "  ❌ $ERROR_COUNT erros encontrados nos logs"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ -z "$MESSAGE_LOGS" ]; then
    print_warning "  ⚠️  Mensagem sequence $SEQUENCE não encontrada nos logs"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ -z "$CHECKPOINT_ATTEMPTS" ]; then
    print_warning "  ⚠️  Nenhuma tentativa de ler checkpoints encontrada"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ ! -z "$QUORUM_ERRORS" ] || [ ! -z "$S3_ERRORS" ] || [ ! -z "$VALIDATOR_DISCOVERY_ERRORS" ]; then
    print_error "  ❌ Erros críticos encontrados (quorum, S3 ou validator discovery)"
    PROBLEMS=$((PROBLEMS + 1))
fi

echo ""

if [ "$PROBLEMS" -eq 0 ]; then
    print_success "✅ Nenhum problema crítico encontrado"
    print_info "Verifique os logs completos para mais detalhes"
else
    print_error "❌ $PROBLEMS problema(s) encontrado(s)"
    echo ""
    print_info "Recomendações:"
    echo ""
    echo "  1. Verificar se validators estão gerando checkpoints"
    echo "  2. Verificar se validators anunciaram buckets S3 no Terra Classic"
    echo "  3. Verificar credenciais AWS do relayer"
    echo "  4. Verificar se há quorum suficiente de checkpoints"
    echo "  5. Verificar logs completos: docker logs $RELAYER_CONTAINER --tail 1000"
fi

echo ""
print_success "✅ Diagnóstico concluído!"
