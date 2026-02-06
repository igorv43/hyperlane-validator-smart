#!/bin/bash

echo "========================================="
echo "🔍 OBTER ISM DO TERRA CLASSIC"
echo "========================================="
echo ""

TERRA_MAILBOX="0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd"
TERRA_LCD="https://lcd.luncblaze.com"

echo "📍 Mailbox do Terra Classic: $TERRA_MAILBOX"
echo ""

echo "1️⃣ Tentando obter ISM via API REST..."
echo ""

QUERY_BASE64=$(echo -n "{\"interchain_security_module\":{}}" | base64 -w 0)
QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$TERRA_MAILBOX/smart/$QUERY_BASE64"

RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
    TERRA_ISM=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
    if [ -n "$TERRA_ISM" ] && [ "$TERRA_ISM" != "null" ] && [ "$TERRA_ISM" != "" ]; then
        echo "   ✅ ISM do Terra Classic: $TERRA_ISM"
        echo ""
        echo "   Use este valor no script configurar-ism-transacoes.sh:"
        echo "   TERRA_ISM=\"$TERRA_ISM\""
    else
        echo "   ❌ Não foi possível obter ISM via API"
    fi
else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // .error' 2>/dev/null)
    echo "   ⚠️  Erro: $ERROR"
    echo ""
    echo "   💡 Verifique manualmente no Terra Finder:"
    echo "   https://finder.terraclassic.community/testnet"
    echo "   Contrato: $TERRA_MAILBOX"
fi

echo ""
echo "========================================="

