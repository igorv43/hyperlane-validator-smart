#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAÇÃO COM 6 SOL                                                   ║"
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
    echo "✅ Saldo atual: $SOL_AMOUNT SOL"
    
    NEEDS_MORE=$(echo "$SOL_AMOUNT 1.0" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_MORE" = "no" ]; then
        echo "✅ Saldo suficiente!"
    else
        echo "⚠️  Saldo ainda pode ser insuficiente"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. VERIFICAR ERROS DE RENT (ÚLTIMOS 3 MINUTOS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    RENT_ERRORS=$(docker logs hpl-relayer-testnet-local --since 3m 2>&1 | grep -iE "insufficient.*rent|account_index.*5" | wc -l)
    
    if [ "$RENT_ERRORS" -eq 0 ]; then
        echo "✅ Nenhum erro de rent nos últimos 3 minutos!"
        echo ""
        echo "🎉 PROBLEMA PODE TER SIDO RESOLVIDO!"
    else
        echo "⚠️  Encontrados $RENT_ERRORS erro(s) de rent nos últimos 3 minutos"
        echo ""
        echo "Últimos erros:"
        docker logs hpl-relayer-testnet-local --since 3m 2>&1 | grep -iE "insufficient.*rent|account_index.*5" | tail -3
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
    MESSAGE_LOGS=$(docker logs hpl-relayer-testnet-local --since 5m 2>&1 | grep -iE "$MESSAGE_ID|nonce.*35.*1325.*1399811150" | tail -10)
    
    if [ ! -z "$MESSAGE_LOGS" ]; then
        echo "📋 Logs recentes sobre a mensagem 35:"
        echo "$MESSAGE_LOGS" | head -5
        echo ""
        
        # Verificar se há indicação de sucesso
        if echo "$MESSAGE_LOGS" | grep -qi "delivered\|success\|relayed"; then
            echo "✅ Mensagem parece ter sido processada com sucesso!"
        elif echo "$MESSAGE_LOGS" | grep -qi "insufficient\|error.*rent"; then
            echo "⚠️  Ainda há erros relacionados à mensagem"
        else
            echo "⏳ Mensagem está sendo processada..."
        fi
    else
        echo "⚠️  Nenhum log recente sobre a mensagem 35"
        echo "   Isso pode significar que a mensagem já foi processada ou ainda está aguardando"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. RESUMO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -z "$SOL_AMOUNT" ]; then
    NEEDS_MORE=$(echo "$SOL_AMOUNT 1.0" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_MORE" = "no" ] && [ "$RENT_ERRORS" -eq 0 ]; then
        echo "✅✅✅ PROBLEMA RESOLVIDO! ✅✅✅"
        echo ""
        echo "   - Saldo suficiente: $SOL_AMOUNT SOL"
        echo "   - Nenhum erro de rent nos logs recentes"
        echo "   - Relayer operacional"
        echo ""
        echo "📋 A mensagem 35 deve ser processada em breve."
        echo "   Monitore os logs para confirmar:"
        echo "   docker logs -f hpl-relayer-testnet-local | grep -i solana"
    else
        if [ "$NEEDS_MORE" = "yes" ]; then
            echo "⚠️  Saldo pode ser insuficiente: $SOL_AMOUNT SOL"
        fi
        if [ "$RENT_ERRORS" -gt 0 ]; then
            echo "⚠️  Ainda há erros de rent"
        fi
    fi
fi

echo ""

