#!/bin/bash

# Script de diagnóstico completo do relayer
# Execute dentro do container ou do host

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
    echo -e "${CYAN}║$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
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

# Configuração
RELAYER_URL="${RELAYER_URL:-http://localhost:9090}"
DOMAIN_ID=1325

print_header "                    DIAGNÓSTICO DO RELAYER"

# 1. Health Check
print_section "1. Health Check"
if curl -s -f "${RELAYER_URL}/health" > /dev/null 2>&1; then
    print_success "Relayer está respondendo"
    curl -s "${RELAYER_URL}/health" | jq '.' 2>/dev/null || curl -s "${RELAYER_URL}/health"
else
    print_error "Relayer não está respondendo em ${RELAYER_URL}"
    print_info "Verifique se o container está rodando: docker ps | grep relayer"
    exit 1
fi

# 2. Validators Descobertos
print_section "2. Validators Descobertos (Terra Classic - domain 1325)"
VALIDATORS=$(curl -s "${RELAYER_URL}/validators" 2>/dev/null)
TERRA_VALIDATORS=$(echo "$VALIDATORS" | jq '.["1325"]' 2>/dev/null)

if [ -n "$TERRA_VALIDATORS" ] && [ "$TERRA_VALIDATORS" != "null" ] && [ "$TERRA_VALIDATORS" != "[]" ]; then
    print_success "Validators do Terra Classic foram descobertos"
    echo "$TERRA_VALIDATORS" | jq '.'
else
    print_error "Nenhum validator do Terra Classic foi descoberto"
    print_warning "O relayer pode não estar consultando ValidatorAnnounce"
    echo "Todos os validators:"
    echo "$VALIDATORS" | jq '.' 2>/dev/null || echo "$VALIDATORS"
fi

# 3. Checkpoints Lidos
print_section "3. Checkpoints Lidos do S3 (Terra Classic)"
CHECKPOINTS=$(curl -s "${RELAYER_URL}/checkpoints/${DOMAIN_ID}" 2>/dev/null)
LAST_CP=$(echo "$CHECKPOINTS" | jq -r '.lastCheckpoint' 2>/dev/null)

if [ -n "$LAST_CP" ] && [ "$LAST_CP" != "null" ]; then
    print_success "Relayer está lendo checkpoints. Último checkpoint: $LAST_CP"
    echo "$CHECKPOINTS" | jq '.' 2>/dev/null || echo "$CHECKPOINTS"
else
    print_error "Relayer não está lendo checkpoints do S3"
    print_warning "Verifique:"
    print_warning "  - Variáveis de ambiente AWS (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
    print_warning "  - Permissões do IAM user (precisa de s3:GetObject)"
    print_warning "  - Se o bucket está acessível"
fi

# 4. Status de Sincronização
print_section "4. Status de Sincronização (Terra Classic)"
SYNC_STATUS=$(curl -s "${RELAYER_URL}/sync/${DOMAIN_ID}" 2>/dev/null)

if [ -n "$SYNC_STATUS" ] && [ "$SYNC_STATUS" != "null" ]; then
    SYNCED=$(echo "$SYNC_STATUS" | jq -r '.synced' 2>/dev/null)
    LAST_BLOCK=$(echo "$SYNC_STATUS" | jq -r '.lastIndexedBlock' 2>/dev/null)
    MSG_PROCESSED=$(echo "$SYNC_STATUS" | jq -r '.messagesProcessed' 2>/dev/null)
    
    if [ "$SYNCED" = "true" ]; then
        print_success "Relayer está sincronizado"
    else
        print_warning "Relayer pode não estar sincronizado"
    fi
    
    echo "Último bloco indexado: $LAST_BLOCK"
    echo "Mensagens processadas: $MSG_PROCESSED"
    echo "$SYNC_STATUS" | jq '.' 2>/dev/null || echo "$SYNC_STATUS"
else
    print_error "Não foi possível obter status de sincronização"
    print_warning "O relayer pode não estar sincronizando o Terra Classic"
fi

# 5. Pool de Mensagens
print_section "5. Pool de Mensagens (prontas para enviar)"
POOL=$(curl -s "${RELAYER_URL}/pool" 2>/dev/null)
POOL_SIZE=$(echo "$POOL" | jq -r '.size' 2>/dev/null)

if [ -n "$POOL_SIZE" ] && [ "$POOL_SIZE" != "null" ]; then
    if [ "$POOL_SIZE" -gt 0 ]; then
        print_success "Há $POOL_SIZE mensagem(ns) no pool"
        echo "$POOL" | jq '.messages[] | {id, origin, destination, status}' 2>/dev/null || echo "$POOL"
    else
        print_warning "Pool está vazio (size: 0)"
        print_info "Isso pode ser normal se não houver mensagens novas"
    fi
else
    print_error "Não foi possível obter informações do pool"
fi

# 6. Variáveis de Ambiente AWS
print_section "6. Variáveis de Ambiente AWS"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    print_success "Credenciais AWS estão configuradas"
    echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
    echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}..."
    echo "AWS_REGION: ${AWS_REGION:-us-east-1}"
    
    # Testar acesso ao S3
    print_info "Testando acesso ao S3..."
    if command -v aws &> /dev/null; then
        BUCKET="hyperlane-validator-signatures-igorverasvalidador-terraclassic"
        if aws s3 ls "s3://${BUCKET}/" --region "${AWS_REGION:-us-east-1}" 2>&1 | head -n 3; then
            print_success "Acesso ao S3 OK"
        else
            print_error "Não foi possível acessar o bucket S3"
        fi
    else
        print_warning "AWS CLI não está instalado, não é possível testar acesso ao S3"
    fi
else
    print_error "Credenciais AWS não estão configuradas"
    print_warning "Configure AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY"
fi

# 7. Configuração do Relayer
print_section "7. Configuração do Relayer"
if [ -f "/etc/hyperlane/relayer.testnet.json" ]; then
    RELAY_CHAINS=$(cat /etc/hyperlane/relayer.testnet.json | jq -r '.relayChains' 2>/dev/null)
    ALLOW_LOCAL=$(cat /etc/hyperlane/relayer.testnet.json | jq -r '.allowLocalCheckpointSyncers' 2>/dev/null)
    WHITELIST=$(cat /etc/hyperlane/relayer.testnet.json | jq '.whitelist' 2>/dev/null)
    
    echo "relayChains: $RELAY_CHAINS"
    if echo "$RELAY_CHAINS" | grep -q "terraclassictestnet"; then
        print_success "Terra Classic está incluído em relayChains"
    else
        print_error "Terra Classic NÃO está incluído em relayChains"
    fi
    
    echo "allowLocalCheckpointSyncers: $ALLOW_LOCAL"
    if [ "$ALLOW_LOCAL" = "false" ]; then
        print_success "Relayer está configurado para ler do S3"
    else
        print_warning "allowLocalCheckpointSyncers não é false"
    fi
    
    echo "Whitelist:"
    echo "$WHITELIST" | jq '.'
else
    print_error "Arquivo de configuração não encontrado: /etc/hyperlane/relayer.testnet.json"
fi

# 8. Resumo e Próximos Passos
print_section "8. Resumo e Próximos Passos"
echo ""
echo "Problemas identificados:"
echo ""

if [ -z "$TERRA_VALIDATORS" ] || [ "$TERRA_VALIDATORS" = "null" ] || [ "$TERRA_VALIDATORS" = "[]" ]; then
    print_error "  • Validators não foram descobertos"
    echo "    → Verificar se o validator anunciou no contrato ValidatorAnnounce"
    echo "    → Verificar logs do relayer por 'Discovering validators'"
fi

if [ -z "$LAST_CP" ] || [ "$LAST_CP" = "null" ]; then
    print_error "  • Relayer não está lendo checkpoints"
    echo "    → Verificar credenciais AWS"
    echo "    → Verificar permissões do IAM user"
    echo "    → Verificar se o bucket está acessível"
fi

if [ "$POOL_SIZE" = "0" ] || [ -z "$POOL_SIZE" ]; then
    print_warning "  • Pool está vazio"
    echo "    → Verificar se há mensagens sendo enviadas do Terra Classic"
    echo "    → Verificar se o validator está gerando checkpoints"
fi

echo ""
print_info "Para mais detalhes, verifique os logs do relayer:"
echo "  docker logs -f hpl-relayer-testnet-local"
