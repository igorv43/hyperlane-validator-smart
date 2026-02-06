#!/bin/bash

MESSAGE_ID="$1"

if [ -z "$MESSAGE_ID" ]; then
    echo "Uso: $0 <message_id>"
    exit 1
fi

echo "========================================="
echo "Verificando mensagem: $MESSAGE_ID"
echo "========================================="
echo ""

# Verificar se a mensagem foi entregue no Terra Classic
echo "1. Verificando se mensagem foi entregue no Terra Classic..."
DELIVERED=$(curl -s "https://lcd.luncblaze.com/cosmwasm/wasm/v1/contract/terra1rnv34hdzl5dvx9dg5qe9t0y0hqe29gxfr38xzzkrv4zzd6wc0s8sdzzp5d/smart/$(echo -n "{\"delivered\":{\"id\":\"$MESSAGE_ID\"}}" | base64 -w 0)" | jq -r '.data' 2>/dev/null || echo "erro")

if [ "$DELIVERED" != "erro" ] && [ "$DELIVERED" != "null" ]; then
    echo "✅ Mensagem foi entregue!"
    echo "Resposta: $DELIVERED"
else
    echo "❌ Mensagem ainda não foi entregue"
fi

echo ""
echo "2. Verificando logs do relayer..."
docker logs hpl-relayer-testnet 2>&1 | grep -i "${MESSAGE_ID:2:10}" | tail -5 || echo "Mensagem não encontrada nos logs"

