#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  DIAGNÓSTICO DETALHADO: MENSAGEM 35 TERRA -> SOLANA                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

MESSAGE_ID="0x9910dbb32d10edeb1c2e2482966444795e7aaa03c4c33a7cf1d267ccab0f8ac1"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. VERIFICAR TODOS OS LOGS DA MENSAGEM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ALL_LOGS=$(docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "$MESSAGE_ID|nonce.*35.*1325.*1399811150")
TOTAL_LOGS=$(echo "$ALL_LOGS" | wc -l)

echo "Total de logs encontrados: $TOTAL_LOGS"
echo ""

if [ "$TOTAL_LOGS" -gt 0 ]; then
    echo "Últimos 10 logs:"
    echo "$ALL_LOGS" | tail -10
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. VERIFICAR STATUS DE ENTREGA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DELIVERED_COUNT=$(docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "delivered.*$MESSAGE_ID" | wc -l)
ERROR_COUNT=$(docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "$MESSAGE_ID.*error|error.*$MESSAGE_ID|insufficient.*rent.*$MESSAGE_ID" | wc -l)

echo "Logs de 'delivered': $DELIVERED_COUNT"
echo "Logs de 'error': $ERROR_COUNT"
echo ""

if [ "$DELIVERED_COUNT" -gt 0 ]; then
    echo "📋 Últimos logs de 'delivered':"
    docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "delivered.*$MESSAGE_ID" | tail -3
    echo ""
    echo "⚠️  NOTA: 'delivered' pode ser apenas uma verificação, não confirmação de entrega"
fi

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "📋 Últimos erros:"
    docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "$MESSAGE_ID.*error|error.*$MESSAGE_ID|insufficient.*rent" | tail -3
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. VERIFICAR ERROS RECENTES (ÚLTIMOS 5 MINUTOS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RECENT_ERRORS=$(docker logs hpl-relayer-testnet-local --since 5m 2>&1 | grep -iE "insufficient.*rent|error.*solana|error.*message")
RECENT_ERROR_COUNT=$(echo "$RECENT_ERRORS" | wc -l)

if [ "$RECENT_ERROR_COUNT" -gt 0 ]; then
    echo "⚠️  Encontrados $RECENT_ERROR_COUNT erro(s) recentes:"
    echo "$RECENT_ERRORS" | tail -10
else
    echo "✅ Nenhum erro recente encontrado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. VERIFICAR PROCESSAMENTO ATUAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Últimos logs sobre Solana (últimos 2 minutos):"
docker logs hpl-relayer-testnet-local --since 2m 2>&1 | grep -iE "solana|message|delivered|relayed|process" | tail -10 || echo "Nenhum log relevante encontrado"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. VERIFICAR SALDO E STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SOLANA_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"
BALANCE=$(solana balance "$SOLANA_ADDRESS" --url https://api.testnet.solana.com 2>&1)
echo "$BALANCE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. ANÁLISE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$RECENT_ERROR_COUNT" -eq 0 ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ Não há erros recentes"
    echo ""
    echo "💡 Possíveis razões para mensagem não entregue:"
    echo "   1. Mensagem ainda está sendo processada (pode levar alguns minutos)"
    echo "   2. Mensagem precisa ser reprocessada após correção"
    echo "   3. Verificar se há outras condições que impedem a entrega"
else
    echo "⚠️  Ainda há erros sendo reportados"
    echo "   Verifique os logs acima para detalhes"
fi

echo ""

