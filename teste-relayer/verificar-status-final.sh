#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAÇÃO FINAL DO STATUS                                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

SOLANA_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. SALDO SOLANA"
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
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. ERROS DE RENT (ÚLTIMOS 3 MINUTOS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    RENT_ERRORS=$(docker logs hpl-relayer-testnet-local --since 3m 2>&1 | grep -iE "insufficient.*rent|error.*solana.*rent" | wc -l)
    
    if [ "$RENT_ERRORS" -eq 0 ]; then
        echo "✅ Nenhum erro de rent nos últimos 3 minutos"
    else
        echo "⚠️  Encontrados $RENT_ERRORS erro(s) de rent nos últimos 3 minutos"
        echo ""
        echo "Últimos erros:"
        docker logs hpl-relayer-testnet-local --since 3m 2>&1 | grep -iE "insufficient.*rent|error.*solana.*rent" | tail -3
    fi
else
    echo "⚠️  Relayer não está rodando"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. PROCESSAMENTO DA MENSAGEM 35"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MESSAGE_ID="0x9910dbb32d10edeb1c2e2482966444795e7aaa03c4c33a7cf1d267ccab0f8ac1"

if docker ps | grep -q "hpl-relayer-testnet-local"; then
    # Verificar se há logs sobre a mensagem nos últimos 5 minutos
    MESSAGE_LOGS=$(docker logs hpl-relayer-testnet-local --since 5m 2>&1 | grep -iE "$MESSAGE_ID|nonce.*35.*1325.*1399811150" | tail -5)
    
    if [ ! -z "$MESSAGE_LOGS" ]; then
        echo "📋 Logs recentes sobre a mensagem 35:"
        echo "$MESSAGE_LOGS" | head -3
        echo ""
        
        # Verificar se há indicação de sucesso
        if echo "$MESSAGE_LOGS" | grep -qi "delivered\|success\|relayed"; then
            echo "✅ Mensagem parece ter sido processada com sucesso!"
        elif echo "$MESSAGE_LOGS" | grep -qi "insufficient\|error"; then
            echo "⚠️  Ainda há erros relacionados à mensagem"
        else
            echo "⏳ Mensagem está sendo processada..."
        fi
    else
        echo "⚠️  Nenhum log recente sobre a mensagem 35"
        echo "   Isso pode significar que a mensagem já foi processada anteriormente"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. RESUMO FINAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -z "$SOL_AMOUNT" ]; then
    NEEDS_FUNDS=$(echo "$SOL_AMOUNT 0.1" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_FUNDS" = "no" ] && [ "$RENT_ERRORS" -eq 0 ]; then
        echo "✅ PROBLEMA RESOLVIDO!"
        echo ""
        echo "   - Saldo suficiente: $SOL_AMOUNT SOL"
        echo "   - Nenhum erro de rent nos logs recentes"
        echo "   - Relayer operacional"
        echo ""
        echo "📋 A mensagem 35 deve ser processada em breve."
        echo "   Monitore os logs para confirmar:"
        echo "   docker logs -f hpl-relayer-testnet-local | grep -i solana"
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

