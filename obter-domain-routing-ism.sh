#!/bin/bash

TX_HASH="0x3c50e8b38b2fad4413507da28036569af5806b4ceaf4a6f852fced39d363d4cc"
FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
RPC="https://sepolia.drpc.org"

echo "Buscando DomainRoutingISM criado..."
echo ""

# Tentar obter via Etherscan API
API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"
TX_URL="https://api-sepolia.etherscan.io/api?module=proxy&action=eth_getTransactionReceipt&txhash=$TX_HASH&apikey=$API_KEY"

echo "Verificando transação no Etherscan..."
RESPONSE=$(curl -s "$TX_URL")

# Tentar extrair logs
LOGS=$(echo "$RESPONSE" | jq -r '.result.logs[]' 2>/dev/null)

if [ -n "$LOGS" ] && [ "$LOGS" != "null" ]; then
    echo "Logs encontrados, buscando endereço..."
    # O evento Deployed geralmente tem o endereço no primeiro tópico ou nos dados
    ADDRESS=$(echo "$RESPONSE" | jq -r '.result.logs[] | select(.topics[0] != null) | .address' 2>/dev/null | grep -v "$FACTORY" | head -1)
    
    if [ -n "$ADDRESS" ] && [ "$ADDRESS" != "null" ]; then
        echo "✅ DomainRoutingISM encontrado: $ADDRESS"
        echo "$ADDRESS"
        exit 0
    fi
fi

echo "⚠️  Não foi possível obter via API"
echo ""
echo "💡 Verifique manualmente no Etherscan:"
echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
echo ""
echo "   Procure pelo evento 'Deployed' ou 'DomainRoutingISM' criado"
echo "   O endereço do DomainRoutingISM estará nos logs da transação"

