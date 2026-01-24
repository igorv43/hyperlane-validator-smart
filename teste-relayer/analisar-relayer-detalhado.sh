#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  ANÁLISE DETALHADA DO RELAYER - TERRA -> SOLANA                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

CONTAINER="hpl-relayer-testnet-local"

if ! docker ps | grep -q "$CONTAINER"; then
    echo "❌ Relayer não está rodando. Iniciando..."
    cd teste-relayer && docker compose -f docker-compose-relayer-only.yml up -d relayer
    sleep 10
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. VERIFICAR SE RELAYER ESTÁ PROCESSANDO MENSAGENS TERRA->SOLANA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Buscar logs sobre Terra Classic
echo "📋 Logs relacionados a Terra Classic:"
docker logs "$CONTAINER" 2>&1 | grep -i "terraclassic\|terra" | tail -10

echo ""
echo "📋 Logs relacionados a Solana:"
docker logs "$CONTAINER" 2>&1 | grep -i "solana\|sealevel" | tail -10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. VERIFICAR CHECKPOINTS E VALIDATORS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Logs sobre checkpoints:"
docker logs "$CONTAINER" 2>&1 | grep -i "checkpoint\|storage.*location\|s3\|bucket" | tail -15

echo ""
echo "📋 Logs sobre validators:"
docker logs "$CONTAINER" 2>&1 | grep -i "validator.*announce\|validator.*found\|validator.*discover" | tail -15

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. VERIFICAR POOL DE MENSAGENS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Pool size e processamento:"
docker logs "$CONTAINER" 2>&1 | grep -i "pool.*size\|processing.*transaction\|finality.*pool" | tail -20

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. VERIFICAR ERROS E WARNINGS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "❌ Erros encontrados:"
docker logs "$CONTAINER" 2>&1 | grep -i "error" | tail -20

echo ""
echo "⚠️  Warnings encontrados:"
docker logs "$CONTAINER" 2>&1 | grep -i "warn" | tail -20

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. VERIFICAR CONFIGURAÇÃO E VARIÁVEIS DE AMBIENTE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Variáveis AWS:"
docker exec "$CONTAINER" env 2>/dev/null | grep -i "AWS\|S3" || echo "Não foi possível acessar container"

echo ""
echo "📋 Configuração do relayer:"
if [ -f "hyperlane/relayer.testnet.json" ]; then
    cat hyperlane/relayer.testnet.json | jq '.chains | keys' 2>/dev/null
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. VERIFICAR SEQUENCES E MENSAGENS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Sequences detectadas:"
docker logs "$CONTAINER" 2>&1 | grep -iE "sequence.*[0-9]+|found.*log|indexing" | tail -20

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. VERIFICAR ÚLTIMAS LINHAS DE LOG (CONTEXTO GERAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Últimas 30 linhas de log:"
docker logs "$CONTAINER" 2>&1 | tail -30

echo ""

