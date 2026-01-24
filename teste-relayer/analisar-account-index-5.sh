#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  ANÁLISE: account_index: 5 - InsufficientFundsForRent                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "O erro 'account_index: 5' indica que a 5ª conta na transação não tem SOL suficiente."
echo ""
echo "Analisando os logs da simulação, vejo que a transação tenta criar uma"
echo "Associated Token Account (ATA) para o recipient:"
echo "  recipient: BirXd4QDxfq2vx9LGqgXXSgZrjT81rhoFGUbQRWDEf1j"
echo ""
echo "O problema é que o relayer precisa pagar o rent para criar essa conta,"
echo "mas o SOL precisa estar na conta correta."
echo ""

SOLANA_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VERIFICANDO SALDO ATUAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

BALANCE=$(solana balance "$SOLANA_ADDRESS" --url https://api.testnet.solana.com 2>&1)
echo "$BALANCE"
echo ""

SOL_AMOUNT=$(echo "$BALANCE" | grep -oE '[0-9]+\.[0-9]+' | head -1)

if [ ! -z "$SOL_AMOUNT" ]; then
    echo "Saldo atual: $SOL_AMOUNT SOL"
    echo ""
    
    # Verificar se precisa de mais SOL
    NEEDS_MORE=$(echo "$SOL_AMOUNT 1.0" | awk '{if ($1 < $2) print "yes"; else print "no"}')
    
    if [ "$NEEDS_MORE" = "yes" ]; then
        echo "⚠️  RECOMENDAÇÃO: Adicionar mais SOL"
        echo "   Saldo atual: $SOL_AMOUNT SOL"
        echo "   Recomendado: 1.0 SOL ou mais"
        echo ""
        echo "O problema pode ser que:"
        echo "  1. O relayer precisa de mais SOL para múltiplas transações"
        echo "  2. A conta derivada (ATA) precisa de SOL para rent"
        echo "  3. O SOL precisa estar na conta do signer principal"
        echo ""
        echo "🔧 SOLUÇÃO: Adicionar mais SOL"
        echo "   Faucet: https://faucet.solana.com/"
        echo "   Endereço: $SOLANA_ADDRESS"
        echo ""
        echo "Ou transferir:"
        echo "   solana transfer $SOLANA_ADDRESS 1.0 --url https://api.testnet.solana.com"
    else
        echo "✅ Saldo parece suficiente: $SOL_AMOUNT SOL"
        echo ""
        echo "⚠️  Mas ainda há erros de rent. Possíveis causas:"
        echo "  1. O relayer pode estar usando uma conta derivada diferente"
        echo "  2. Pode haver um problema com a forma como o SOL é alocado"
        echo "  3. Pode ser necessário reiniciar o relayer após adicionar SOL"
        echo ""
        echo "🔧 TENTAR:"
        echo "  1. Adicionar mais SOL (2-3 SOL para garantir)"
        echo "  2. Reiniciar o relayer completamente"
        echo "  3. Verificar se há outras contas que precisam de SOL"
    fi
fi

echo ""

