#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR ISM DO SOLANA PARA TERRA CLASSIC                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

SOLANA_RPC="https://api.testnet.solana.com"
MAILBOX_SOLANA="75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR"
TERRA_DOMAIN=1325

echo "📋 Mailbox Solana: $MAILBOX_SOLANA"
echo "📋 Domain Terra Classic: $TERRA_DOMAIN"
echo ""

# Verificar se há ferramentas do Solana disponíveis
if command -v solana &> /dev/null; then
    echo "✅ Solana CLI disponível"
    echo ""
    echo "🔍 Verificando conta do Mailbox:"
    solana account "$MAILBOX_SOLANA" --url "$SOLANA_RPC" 2>&1 | head -10
else
    echo "⚠️  Solana CLI não disponível"
    echo ""
    echo "🔍 Tentando via RPC direto..."
    
    # Consultar conta via RPC
    ACCOUNT_INFO=$(curl -s -X POST "$SOLANA_RPC" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAccountInfo\",\"params\":[\"$MAILBOX_SOLANA\",{\"encoding\":\"jsonParsed\"}]}" 2>&1)
    
    if echo "$ACCOUNT_INFO" | jq -e '.result.value' > /dev/null 2>&1; then
        echo "✅ Conta encontrada"
        LAMPORTS=$(echo "$ACCOUNT_INFO" | jq -r '.result.value.lamports // "N/A"' 2>/dev/null)
        echo "   Lamports: $LAMPORTS"
    else
        echo "❌ Erro ao consultar conta: $(echo "$ACCOUNT_INFO" | jq -r '.error.message // .error' 2>/dev/null)"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 NOTA:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Para verificar o ISM do Solana, é necessário:"
echo "1. Consultar o programa do Mailbox no Solana"
echo "2. Verificar o ISM configurado para domain $TERRA_DOMAIN"
echo "3. Verificar se há validators do Terra Classic no ISM"
echo ""
echo "Isso requer acesso ao programa do Hyperlane no Solana ou"
echo "ferramentas específicas para consultar programas Sealevel."
echo ""

