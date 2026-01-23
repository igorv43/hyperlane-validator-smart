#!/bin/bash

# Script de diagnóstico para executar DENTRO do container do relayer
# Execute: docker exec -it hpl-relayer-testnet-local bash -c "bash /path/to/diagnostico-container.sh"

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         DIAGNÓSTICO DO RELAYER (DENTRO DO CONTAINER)                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

RELAYER_URL="http://localhost:9090"
DOMAIN_ID=1325

# 1. Health Check
echo -e "${BLUE}▶ 1. Health Check${NC}"
if curl -s -f "${RELAYER_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Relayer está respondendo${NC}"
    curl -s "${RELAYER_URL}/health" | jq '.' 2>/dev/null || curl -s "${RELAYER_URL}/health"
else
    echo -e "${RED}❌ Relayer não está respondendo${NC}"
    exit 1
fi
echo ""

# 2. Validators
echo -e "${BLUE}▶ 2. Validators Descobertos (Terra Classic - domain 1325)${NC}"
VALIDATORS=$(curl -s "${RELAYER_URL}/validators" 2>/dev/null)
TERRA_VALIDATORS=$(echo "$VALIDATORS" | jq '.["1325"]' 2>/dev/null)

if [ -n "$TERRA_VALIDATORS" ] && [ "$TERRA_VALIDATORS" != "null" ] && [ "$TERRA_VALIDATORS" != "[]" ]; then
    echo -e "${GREEN}✅ Validators do Terra Classic foram descobertos${NC}"
    echo "$TERRA_VALIDATORS" | jq '.'
else
    echo -e "${RED}❌ Nenhum validator do Terra Classic foi descoberto${NC}"
    echo "Todos os validators:"
    echo "$VALIDATORS" | jq '.' 2>/dev/null || echo "$VALIDATORS"
fi
echo ""

# 3. Checkpoints
echo -e "${BLUE}▶ 3. Checkpoints Lidos do S3${NC}"
CHECKPOINTS=$(curl -s "${RELAYER_URL}/checkpoints/${DOMAIN_ID}" 2>/dev/null)
LAST_CP=$(echo "$CHECKPOINTS" | jq -r '.lastCheckpoint' 2>/dev/null)

if [ -n "$LAST_CP" ] && [ "$LAST_CP" != "null" ]; then
    echo -e "${GREEN}✅ Relayer está lendo checkpoints. Último: $LAST_CP${NC}"
    echo "$CHECKPOINTS" | jq '.' 2>/dev/null || echo "$CHECKPOINTS"
else
    echo -e "${RED}❌ Relayer não está lendo checkpoints${NC}"
    echo "Verificar:"
    echo "  - Variáveis AWS: AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:0:10}..."
    echo "  - Testar S3: aws s3 ls s3://bucket/ --region ${AWS_REGION:-us-east-1}"
fi
echo ""

# 4. Sync Status
echo -e "${BLUE}▶ 4. Status de Sincronização${NC}"
SYNC_STATUS=$(curl -s "${RELAYER_URL}/sync/${DOMAIN_ID}" 2>/dev/null)

if [ -n "$SYNC_STATUS" ] && [ "$SYNC_STATUS" != "null" ]; then
    SYNCED=$(echo "$SYNC_STATUS" | jq -r '.synced' 2>/dev/null)
    LAST_BLOCK=$(echo "$SYNC_STATUS" | jq -r '.lastIndexedBlock' 2>/dev/null)
    MSG_PROCESSED=$(echo "$SYNC_STATUS" | jq -r '.messagesProcessed' 2>/dev/null)
    
    if [ "$SYNCED" = "true" ]; then
        echo -e "${GREEN}✅ Relayer está sincronizado${NC}"
    else
        echo -e "${YELLOW}⚠️  Relayer pode não estar sincronizado${NC}"
    fi
    
    echo "Último bloco: $LAST_BLOCK"
    echo "Mensagens processadas: $MSG_PROCESSED"
    echo "$SYNC_STATUS" | jq '.' 2>/dev/null || echo "$SYNC_STATUS"
else
    echo -e "${RED}❌ Não foi possível obter status de sincronização${NC}"
fi
echo ""

# 5. Pool
echo -e "${BLUE}▶ 5. Pool de Mensagens${NC}"
POOL=$(curl -s "${RELAYER_URL}/pool" 2>/dev/null)
POOL_SIZE=$(echo "$POOL" | jq -r '.size' 2>/dev/null)

if [ -n "$POOL_SIZE" ] && [ "$POOL_SIZE" != "null" ]; then
    if [ "$POOL_SIZE" -gt 0 ]; then
        echo -e "${GREEN}✅ Há $POOL_SIZE mensagem(ns) no pool${NC}"
        echo "$POOL" | jq '.messages[] | {id, origin, destination, status}' 2>/dev/null || echo "$POOL"
    else
        echo -e "${YELLOW}⚠️  Pool está vazio (size: 0)${NC}"
    fi
else
    echo -e "${RED}❌ Não foi possível obter informações do pool${NC}"
fi
echo ""

# 6. AWS Vars
echo -e "${BLUE}▶ 6. Variáveis AWS${NC}"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${GREEN}✅ Credenciais AWS configuradas${NC}"
    echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
    echo "AWS_REGION: ${AWS_REGION:-us-east-1}"
    
    if command -v aws &> /dev/null; then
        echo "Testando S3..."
        BUCKET="hyperlane-validator-signatures-igorverasvalidador-terraclassic"
        if aws s3 ls "s3://${BUCKET}/" --region "${AWS_REGION:-us-east-1}" 2>&1 | head -n 3; then
            echo -e "${GREEN}✅ Acesso ao S3 OK${NC}"
        else
            echo -e "${RED}❌ Erro ao acessar S3${NC}"
        fi
    fi
else
    echo -e "${RED}❌ Credenciais AWS não configuradas${NC}"
fi
echo ""

# 7. Config
echo -e "${BLUE}▶ 7. Configuração${NC}"
if [ -f "/etc/hyperlane/relayer.testnet.json" ]; then
    RELAY_CHAINS=$(cat /etc/hyperlane/relayer.testnet.json | jq -r '.relayChains' 2>/dev/null)
    ALLOW_LOCAL=$(cat /etc/hyperlane/relayer.testnet.json | jq -r '.allowLocalCheckpointSyncers' 2>/dev/null)
    
    echo "relayChains: $RELAY_CHAINS"
    if echo "$RELAY_CHAINS" | grep -q "terraclassictestnet"; then
        echo -e "${GREEN}✅ Terra Classic incluído${NC}"
    else
        echo -e "${RED}❌ Terra Classic NÃO incluído${NC}"
    fi
    
    echo "allowLocalCheckpointSyncers: $ALLOW_LOCAL"
    if [ "$ALLOW_LOCAL" = "false" ]; then
        echo -e "${GREEN}✅ Configurado para ler do S3${NC}"
    else
        echo -e "${YELLOW}⚠️  allowLocalCheckpointSyncers não é false${NC}"
    fi
else
    echo -e "${RED}❌ Arquivo de configuração não encontrado${NC}"
fi
echo ""

# 8. Logs Recentes
echo -e "${BLUE}▶ 8. Logs Recentes (checkpoint/1325/error)${NC}"
if [ -f "/proc/1/fd/1" ]; then
    echo "Últimas linhas com 'checkpoint', '1325' ou 'error':"
    grep -i "checkpoint\|1325\|error" /proc/1/fd/1 2>/dev/null | tail -n 10 || echo "Não foi possível acessar logs"
else
    echo "Não foi possível acessar logs do processo"
fi
echo ""

echo -e "${CYAN}══════════════════════════════════════════════════════════════════════════${NC}"
echo "Diagnóstico completo!"
