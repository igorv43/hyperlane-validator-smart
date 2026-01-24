#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  MONITORAR RELAYER APÓS CORREÇÃO                                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

SOLANA_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"

echo "📊 Verificando saldo do relayer..."
BALANCE=$(solana balance "$SOLANA_ADDRESS" --url https://api.testnet.solana.com 2>&1)
echo "$BALANCE"
echo ""

SOL_AMOUNT=$(echo "$BALANCE" | grep -oE '[0-9]+\.[0-9]+' | head -1)

if [ ! -z "$SOL_AMOUNT" ]; then
    NEEDS_FUNDS=$(echo "$SOL_AMOUNT 0.1" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_FUNDS" = "yes" ]; then
        echo "⚠️  AINDA PRECISA ADICIONAR SOL"
        echo "   Saldo atual: $SOL_AMOUNT SOL"
        echo "   Mínimo necessário: 0.1 SOL"
        echo ""
        echo "🔧 Use o faucet do Solana:"
        echo "   https://faucet.solana.com/"
        echo "   Endereço: $SOLANA_ADDRESS"
        echo ""
        echo "Ou transfira de outra conta:"
        echo "   solana transfer $SOLANA_ADDRESS 0.1 --url https://api.testnet.solana.com"
    else
        echo "✅ SALDO SUFICIENTE: $SOL_AMOUNT SOL"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 VERIFICANDO STATUS DO RELAYER"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if docker ps | grep -q "hpl-relayer-testnet-local"; then
            echo "✅ Relayer está rodando"
            echo ""
            echo "📋 Últimos logs relacionados a Solana:"
            docker logs hpl-relayer-testnet-local --tail 50 2>&1 | grep -iE "solana|insufficient|rent|message.*35|sequence.*35" | tail -10 || echo "Nenhum log relevante encontrado"
            echo ""
            echo "📋 Verificando erros recentes:"
            docker logs hpl-relayer-testnet-local --tail 100 2>&1 | grep -iE "error.*solana|insufficient.*rent" | tail -5 || echo "✅ Nenhum erro de rent encontrado"
            echo ""
            echo "📋 Verificando processamento de mensagens:"
            docker logs hpl-relayer-testnet-local --tail 100 2>&1 | grep -iE "message.*35|sequence.*35|delivered|relayed" | tail -5 || echo "Nenhuma mensagem 35 processada recentemente"
        else
            echo "⚠️  Relayer não está rodando"
            echo "   Inicie com: cd teste-relayer && docker compose -f docker-compose-relayer-only.yml up -d relayer"
        fi
    fi
else
    echo "⚠️  Não foi possível verificar saldo"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 PRÓXIMOS PASSOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Se o saldo for < 0.1 SOL, adicione SOL via faucet"
echo "2. Reinicie o relayer: cd teste-relayer && docker compose restart relayer"
echo "3. Monitore logs: docker logs -f hpl-relayer-testnet-local | grep -i solana"
echo "4. Verifique se a mensagem sequence 35 foi processada"
echo ""

