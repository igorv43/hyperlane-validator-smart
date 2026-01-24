#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  DIAGNÓSTICO COMPLETO DO RELAYER LOCAL                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se o relayer está rodando
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 1: Verificar Status do Relayer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    echo "✅ Relayer está rodando"
    docker ps | grep "hpl-relayer-testnet-local"
else
    echo "❌ Relayer NÃO está rodando"
    echo ""
    echo "Iniciando relayer..."
    docker compose -f docker-compose-relayer-only.yml up -d relayer
    sleep 5
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 2: Verificar Configuração do Relayer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "../hyperlane/relayer.testnet.json" ]; then
    echo "📄 Configuração do relayer:"
    cat ../hyperlane/relayer.testnet.json | jq '.' 2>/dev/null || cat ../hyperlane/relayer.testnet.json
else
    echo "⚠️  Arquivo de configuração não encontrado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 3: Verificar Logs do Relayer (últimas 100 linhas)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    echo "📋 Logs do relayer:"
    docker logs hpl-relayer-testnet-local --tail 100 2>&1 | tail -50
else
    echo "⚠️  Relayer não está rodando, não é possível ver logs"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 4: Verificar Mensagens Processadas"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    echo "🔍 Buscando informações sobre mensagens:"
    docker logs hpl-relayer-testnet-local 2>&1 | grep -i "message\|sequence\|solana\|terra" | tail -20
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 5: Verificar Checkpoints e Validators"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    echo "🔍 Buscando informações sobre checkpoints:"
    docker logs hpl-relayer-testnet-local 2>&1 | grep -i "checkpoint\|validator\|s3\|bucket" | tail -20
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 6: Verificar Erros"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    echo "🔍 Buscando erros:"
    docker logs hpl-relayer-testnet-local 2>&1 | grep -i "error\|fail\|warn" | tail -30
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 7: Verificar Chains Configuradas"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "../hyperlane/agent-config.docker-testnet.json" ]; then
    echo "📋 Chains configuradas:"
    cat ../hyperlane/agent-config.docker-testnet.json | jq -r '.chains | keys[]' 2>/dev/null
    echo ""
    echo "🔍 Verificando Solana:"
    cat ../hyperlane/agent-config.docker-testnet.json | jq '.chains.solanatestnet' 2>/dev/null
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 8: Verificar Checkpoints no S3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

BUCKET="hyperlane-validator-signatures-igorverasvalidador-terraclassic"
BUCKET_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/"

echo "📦 Verificando checkpoints no bucket: $BUCKET"
echo ""

# Obter sequence mais recente
LATEST_INDEX=$(curl -s "${BUCKET_URL}checkpoint_latest_index.json" 2>/dev/null || echo "")
if [ ! -z "$LATEST_INDEX" ]; then
    echo "✅ Sequence mais recente: $LATEST_INDEX"
    
    # Verificar últimos 5 checkpoints
    echo ""
    echo "📋 Últimos 5 checkpoints:"
    for i in $(seq $((LATEST_INDEX - 4)) $LATEST_INDEX); do
        CHECKPOINT_FILE="checkpoint_${i}_with_id.json"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BUCKET_URL}${CHECKPOINT_FILE}" 2>/dev/null)
        if [ "$HTTP_CODE" = "200" ]; then
            DATE=$(curl -s "${BUCKET_URL}?list-type=2&prefix=${CHECKPOINT_FILE}" 2>/dev/null | \
                grep -oE "<LastModified>[^<]+</LastModified>" | \
                sed 's/<LastModified>//;s/<\/LastModified>//' | head -1)
            echo "  ✅ Sequence $i - $DATE"
        else
            echo "  ❌ Sequence $i - Não encontrado"
        fi
    done
else
    echo "⚠️  Não foi possível obter o índice mais recente"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMO E ANÁLISE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

