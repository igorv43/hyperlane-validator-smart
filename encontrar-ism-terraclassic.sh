#!/bin/bash

echo "========================================="
echo "🔍 ENCONTRANDO ISM DO TERRA CLASSIC"
echo "========================================="
echo ""

VALIDATOR="0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0"
TERRA_MAILBOX="0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd"
TERRA_LCD="https://lcd.luncblaze.com"

echo "📍 Validador: $VALIDATOR"
echo "📍 Mailbox Terra Classic: $TERRA_MAILBOX"
echo ""

echo "1️⃣ Tentando obter ISM via API REST do Terra Classic..."
echo ""

# Tentar diferentes queries
QUERIES=(
    "{\"interchain_security_module\":{}}"
    "{\"get_interchain_security_module\":{}}"
    "{\"ism\":{}}"
)

for QUERY in "${QUERIES[@]}"; do
    QUERY_BASE64=$(echo -n "$QUERY" | base64 -w 0)
    QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$TERRA_MAILBOX/smart/$QUERY_BASE64"
    
    RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)
    
    if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
        DATA=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
        if [ -n "$DATA" ] && [ "$DATA" != "null" ] && [ "$DATA" != "" ]; then
            echo "   ✅ ISM encontrado via query: $QUERY"
            echo "   ISM: $DATA"
            echo ""
            echo "   Use este valor:"
            echo "   export TERRA_ISM=\"$DATA\""
            exit 0
        fi
    fi
done

echo "   ⚠️  Não foi possível obter via API REST"
echo ""

echo "2️⃣ Verificando logs do relayer..."
echo ""

# Tentar encontrar nos logs do relayer
if docker ps | grep -q hpl-relayer-testnet; then
    echo "   Buscando ISM nos logs do relayer..."
    ISM_FROM_LOGS=$(docker logs hpl-relayer-testnet 2>&1 | grep -i "ism\|interchain.*security" | grep -i "terra\|1325" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
    
    if [ -n "$ISM_FROM_LOGS" ]; then
        echo "   ✅ Possível ISM encontrado nos logs: $ISM_FROM_LOGS"
        echo ""
        echo "   Use este valor (verifique se está correto):"
        echo "   export TERRA_ISM=\"$ISM_FROM_LOGS\""
    else
        echo "   ⚠️  Não encontrado nos logs"
    fi
else
    echo "   ⚠️  Relayer não está rodando"
fi

echo ""
echo "3️⃣ Verificando configuração do validador..."
echo ""

# O ISM do Terra Classic é o contrato que contém os validadores
# Se sabemos os validadores, podemos tentar encontrar o ISM
echo "   O ISM do Terra Classic é o contrato que contém:"
echo "   - Validador: $VALIDATOR"
echo "   - Threshold: 1"
echo ""
echo "   💡 Você pode encontrar o ISM:"
echo "   1. No Terra Finder: https://finder.terraclassic.community/testnet"
echo "   2. Consultando o Mailbox: $TERRA_MAILBOX"
echo "   3. Verificando transações de criação do ISM"
echo ""

echo "========================================="
echo "💡 PRÓXIMOS PASSOS"
echo "========================================="
echo ""
echo "Se você souber o endereço do ISM do Terra Classic, configure:"
echo "   export TERRA_ISM=\"<endereco_ism_terra_classic>\""
echo ""
echo "Depois execute:"
echo "   ./corrigir-ism-sepolia.sh"
echo ""

