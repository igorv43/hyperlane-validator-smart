#!/bin/bash

echo "========================================="
echo "🔍 VALIDADOR DO TERRA CLASSIC - VERIFICAÇÃO COMPLETA"
echo "========================================="
echo ""

VALIDATOR="0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0"
VALIDATOR_ANNOUNCE_TERRA="0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"
TERRA_LCD="https://lcd.luncblaze.com"

echo "📍 Validador do Terra Classic:"
echo "   $VALIDATOR"
echo ""

echo "📍 ValidatorAnnounce do Terra Classic:"
echo "   $VALIDATOR_ANNOUNCE_TERRA"
echo ""

echo "1️⃣ Entendendo o fluxo correto..."
echo ""
echo "   Para mensagens Sepolia → Terra Classic:"
echo ""
echo "   a) Mensagem enviada DO Sepolia (origin: 11155111)"
echo "   b) ISM no Terra Classic (destino) valida a mensagem"
echo "   c) ISM usa validadores do Terra Classic: $VALIDATOR"
echo "   d) Validadores do Terra Classic precisam criar checkpoints"
echo "   e) Validadores precisam anunciar no ValidatorAnnounce do TERRA CLASSIC"
echo ""
echo "   ⚠️  IMPORTANTE: O relayer busca checkpoints do domínio de ORIGEM (Sepolia)"
echo "      MAS os validadores que assinam são do Terra Classic"
echo "      Isso pode ser um problema de configuração!"
echo ""

echo "2️⃣ Verificando anúncios no Terra Classic..."
echo ""

# Tentar query via REST API do Terra Classic
echo "   Tentando query via REST API..."
QUERY_BASE64=$(echo -n "{\"get_announced_storage_locations\":{\"validator\":\"$VALIDATOR\"}}" | base64 -w 0)
QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$VALIDATOR_ANNOUNCE_TERRA/smart/$QUERY_BASE64"

RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
    DATA=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
    if [ -n "$DATA" ] && [ "$DATA" != "null" ] && [ "$DATA" != "" ]; then
        echo "   ✅ Validador está anunciado no Terra Classic!"
        echo "   📦 Storage locations:"
        echo "$DATA" | jq '.' 2>/dev/null | sed 's/^/      /'
    else
        echo "   ❌ Validador não está anunciado no Terra Classic"
    fi
else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // .error' 2>/dev/null)
    if [ -n "$ERROR" ] && [ "$ERROR" != "null" ]; then
        echo "   ⚠️  Erro na query: $ERROR"
    else
        echo "   ❌ Não foi possível verificar via API REST"
    fi
fi

echo ""
echo "3️⃣ Verificando se o relayer está configurado corretamente..."
echo ""

# Verificar configuração do relayer
if [ -f "hyperlane/relayer.testnet.json" ]; then
    ALLOW_LOCAL=$(jq -r '.allowLocalCheckpointSyncers // "not set"' hyperlane/relayer.testnet.json 2>/dev/null)
    echo "   allowLocalCheckpointSyncers: $ALLOW_LOCAL"
    
    # Verificar se há checkpointSyncer configurado
    CHECKPOINT_SYNCER=$(jq -r '.checkpointSyncer // "not set"' hyperlane/relayer.testnet.json 2>/dev/null)
    if [ "$CHECKPOINT_SYNCER" != "not set" ] && [ "$CHECKPOINT_SYNCER" != "null" ]; then
        echo "   checkpointSyncer: Configurado"
        echo "$CHECKPOINT_SYNCER" | jq '.' 2>/dev/null | sed 's/^/      /'
    else
        echo "   checkpointSyncer: Não configurado"
    fi
fi

echo ""
echo "========================================="
echo "💡 DIAGNÓSTICO"
echo "========================================="
echo ""
echo "Se o validador do Terra Classic não está anunciado:"
echo "   → O validador precisa rodar e anunciar no Terra Classic"
echo "   → O anúncio deve ser no ValidatorAnnounce do Terra Classic"
echo ""
echo "Se o relayer não consegue buscar checkpoints:"
echo "   → Verifique se allowLocalCheckpointSyncers está correto"
echo "   → Verifique se checkpointSyncer está configurado"
echo "   → O relayer pode precisar buscar checkpoints do Terra Classic"
echo "     (não do Sepolia) se os validadores são do Terra Classic"
echo ""

