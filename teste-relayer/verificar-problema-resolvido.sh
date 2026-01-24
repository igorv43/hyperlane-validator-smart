#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR SE PROBLEMA FOI RESOLVIDO                                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

SOLANA_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"
MESSAGE_ID="0x9910dbb32d10edeb1c2e2482966444795e7aaa03c4c33a7cf1d267ccab0f8ac1"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. VERIFICAR SALDO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

BALANCE=$(solana balance "$SOLANA_ADDRESS" --url https://api.testnet.solana.com 2>&1)
echo "$BALANCE"
echo ""

SOL_AMOUNT=$(echo "$BALANCE" | grep -oE '[0-9]+\.[0-9]+' | head -1)

if [ ! -z "$SOL_AMOUNT" ]; then
    NEEDS_FUNDS=$(echo "$SOL_AMOUNT 0.1" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_FUNDS" = "no" ]; then
        echo "✅ Saldo suficiente: $SOL_AMOUNT SOL"
    else
        echo "⚠️  Saldo insuficiente: $SOL_AMOUNT SOL"
        echo "   Adicione SOL via: https://faucet.solana.com/"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. VERIFICAR ERROS DE RENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    RENT_ERRORS=$(docker logs hpl-relayer-testnet-local --tail 200 2>&1 | grep -iE "insufficient.*rent|error.*solana.*rent" | wc -l)
    
    if [ "$RENT_ERRORS" -eq 0 ]; then
        echo "✅ Nenhum erro de rent encontrado nos últimos logs"
    else
        echo "⚠️  Encontrados $RENT_ERRORS erro(s) de rent nos últimos logs"
        echo ""
        echo "Últimos erros:"
        docker logs hpl-relayer-testnet-local --tail 200 2>&1 | grep -iE "insufficient.*rent|error.*solana.*rent" | tail -3
    fi
else
    echo "⚠️  Relayer não está rodando"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. VERIFICAR PROCESSAMENTO DA MENSAGEM 35"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    MESSAGE_LOGS=$(docker logs hpl-relayer-testnet-local --tail 500 2>&1 | grep -iE "message.*35|sequence.*35|$MESSAGE_ID" | tail -10)
    
    if [ ! -z "$MESSAGE_LOGS" ]; then
        echo "📋 Logs relacionados à mensagem 35:"
        echo "$MESSAGE_LOGS"
    else
        echo "⚠️  Nenhum log encontrado sobre a mensagem 35"
        echo "   Isso pode significar que a mensagem já foi processada ou ainda está aguardando"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. RESUMO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -z "$SOL_AMOUNT" ]; then
    NEEDS_FUNDS=$(echo "$SOL_AMOUNT 0.1" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_FUNDS" = "no" ] && [ "$RENT_ERRORS" -eq 0 ]; then
        echo "✅ PROBLEMA RESOLVIDO!"
        echo ""
        echo "   - Saldo suficiente: $SOL_AMOUNT SOL"
        echo "   - Nenhum erro de rent"
        echo ""
        echo "📋 Próximos passos:"
        echo "   1. Monitore os logs: docker logs -f hpl-relayer-testnet-local"
        echo "   2. Verifique se novas mensagens são processadas"
        echo "   3. Verifique no Solana explorer se a mensagem foi entregue"
    else
        echo "⚠️  Ainda há problemas:"
        if [ "$NEEDS_FUNDS" = "yes" ]; then
            echo "   - Saldo insuficiente: $SOL_AMOUNT SOL"
        fi
        if [ "$RENT_ERRORS" -gt 0 ]; then
            echo "   - Erros de rent ainda presentes"
        fi
    fi
fi

echo ""

