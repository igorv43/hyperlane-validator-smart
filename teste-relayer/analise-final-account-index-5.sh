#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  ANÁLISE FINAL: account_index: 5                                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 ANÁLISE DOS LOGS DA SIMULAÇÃO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Dos logs da simulação, vejo que:"
echo ""
echo "1. A transação tenta criar uma Associated Token Account (ATA)"
echo "2. O programa ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL é chamado"
echo "3. O log mostra: 'Program log: Initialize the associated token account'"
echo "4. O erro ocorre em account_index: 5"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 POSSÍVEL CAUSA RAIZ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "O problema pode ser que:"
echo ""
echo "1. O relayer não está incluindo uma instrução para transferir SOL"
echo "   do signer principal (account_index: 0) para a conta ATA (account_index: 5)"
echo ""
echo "2. Em Solana, quando você cria uma conta, ela precisa de SOL para rent exemption."
echo "   O relayer pode não estar alocando SOL corretamente na transação."
echo ""
echo "3. Pode ser um bug na versão 1.7.0 do Hyperlane relayer relacionado"
echo "   à criação de ATAs no Solana."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 SOLUÇÕES POSSÍVEIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1. Verificar se há uma versão mais recente do relayer que corrige isso"
echo "2. Verificar se há configuração para pré-criar ATAs"
echo "3. Verificar se o recipient precisa ter SOL antes de receber tokens"
echo "4. Verificar se há uma forma de configurar o relayer para incluir"
echo "   instruções de transferência de SOL na transação"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 STATUS ATUAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SOLANA_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"
BALANCE=$(solana balance "$SOLANA_ADDRESS" --url https://api.testnet.solana.com 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)

echo "✅ Saldo: $BALANCE SOL"
echo "⚠️  Erro ainda ocorre mesmo com $BALANCE SOL"
echo ""

echo "Isso confirma que o problema NÃO é apenas falta de SOL no signer principal,"
echo "mas sim como o relayer constrói a transação para criar a conta ATA."
echo ""

