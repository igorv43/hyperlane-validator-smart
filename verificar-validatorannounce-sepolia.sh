#!/bin/bash

echo "========================================="
echo "📋 CONTRATO VALIDATORANNOUNCE - SEPOLIA"
echo "========================================="
echo ""

# Endereço do contrato ValidatorAnnounce do Sepolia
VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
SEPOLIA_RPC="https://1rpc.io/sepolia"
SEPOLIA_ETHERSCAN="https://sepolia.etherscan.io"

echo "📍 Endereço do Contrato:"
echo "   $VALIDATOR_ANNOUNCE"
echo ""
echo "🔗 Links:"
echo "   Etherscan: $SEPOLIA_ETHERSCAN/address/$VALIDATOR_ANNOUNCE"
echo "   Contrato: $SEPOLIA_ETHERSCAN/address/$VALIDATOR_ANNOUNCE#code"
echo "   Eventos: $SEPOLIA_ETHERSCAN/address/$VALIDATOR_ANNOUNCE#events"
echo ""

echo "📝 Este contrato é onde os validadores anunciam:"
echo "   - Onde estão armazenando seus checkpoints (S3, HTTP, local)"
echo "   - Para quais domínios eles estão validando"
echo ""

echo "1️⃣ Verificando eventos de anúncio recentes..."
echo ""

LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 20000))  # Últimos 20000 blocos (~3 dias)

echo "   Buscando eventos desde o bloco $FROM_BLOCK até $LATEST_BLOCK"
echo ""

# Buscar eventos Announcement
# Evento: Announcement(address indexed validator, string storageLocation, string[] domains)
ANNOUNCEMENTS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
    "Announcement(address indexed validator, string storageLocation, string[] domains)" \
    --address "$VALIDATOR_ANNOUNCE" \
    --rpc-url "$SEPOLIA_RPC" 2>/dev/null)

if [ -z "$ANNOUNCEMENTS" ]; then
    echo "   ❌ Nenhum anúncio encontrado"
    echo ""
    echo "   ⚠️  Isso significa que:"
    echo "      - Nenhum validador anunciou checkpoints no Sepolia"
    echo "      - Os validadores podem não estar rodando"
    echo "      - Os validadores podem não ter anunciado ainda"
else
    echo "   ✅ Anúncios encontrados:"
    echo ""
    echo "$ANNOUNCEMENTS" | head -50 | sed 's/^/      /'
    echo ""
    
    # Contar quantos anúncios
    COUNT=$(echo "$ANNOUNCEMENTS" | grep -c "Announcement" || echo "0")
    echo "   Total de anúncios encontrados: $COUNT"
fi

echo ""
echo "2️⃣ Verificando no Etherscan via API..."
echo ""

# Tentar buscar via API do Etherscan
API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"
EVENT_TOPIC="0x"$(cast keccak "Announcement(address,string,string[])" | cut -c3-)

RESPONSE=$(curl -s "https://api-sepolia.etherscan.io/api?module=logs&action=getLogs&fromBlock=$FROM_BLOCK&toBlock=latest&address=$VALIDATOR_ANNOUNCE&topic0=$EVENT_TOPIC&apikey=$API_KEY" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.result | length > 0' >/dev/null 2>&1; then
    COUNT_API=$(echo "$RESPONSE" | jq '.result | length')
    echo "   ✅ $COUNT_API anúncio(s) encontrado(s) via API do Etherscan"
    echo ""
    echo "   Primeiros anúncios:"
    echo "$RESPONSE" | jq -r '.result[0:3] | .[] | "      Validador: \(.topics[1]) | Bloco: \(.blockNumber)"' 2>/dev/null
else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // .result' 2>/dev/null)
    if [ -n "$ERROR" ] && [ "$ERROR" != "null" ]; then
        echo "   ⚠️  Erro na API: $ERROR"
    else
        echo "   ❌ Nenhum anúncio encontrado via API"
    fi
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "💡 COMO FUNCIONA:"
echo ""
echo "   1. Validadores rodam e detectam mensagens no Sepolia"
echo "   2. Validadores criam checkpoints assinados"
echo "   3. Validadores anunciam no contrato $VALIDATOR_ANNOUNCE:"
echo "      - Onde estão os checkpoints (S3, HTTP, etc)"
echo "      - Para quais domínios estão validando"
echo "   4. Relayer lê os anúncios e busca os checkpoints"
echo "   5. Relayer coleta assinaturas suficientes (quorum)"
echo "   6. Relayer entrega a mensagem no destino"
echo ""

