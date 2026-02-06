#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO VALIDADOR NO TERRA CLASSIC"
echo "========================================="
echo ""

VALIDATOR="0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0"
VALIDATOR_ANNOUNCE_TERRA="0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"
TERRA_LCD="https://lcd.luncblaze.com"

echo "📍 Validador:"
echo "   $VALIDATOR"
echo ""

echo "📍 ValidatorAnnounce do Terra Classic:"
echo "   $VALIDATOR_ANNOUNCE_TERRA"
echo ""

echo "1️⃣ Verificando anúncios no Terra Classic..."
echo ""

# No Terra Classic (Cosmos), o ValidatorAnnounce é um contrato Cosmos
# Precisamos usar a API REST para verificar

# Tentar obter anúncios via API REST do Terra Classic
echo "   Tentando via API REST do Terra Classic..."
echo ""

# Converter endereço Ethereum para formato Cosmos (bech32)
# O validador é um endereço Ethereum, mas no Terra Classic pode estar em formato diferente
# Vamos tentar verificar diretamente no contrato via query

# Para Cosmos, precisamos fazer uma query ao contrato
# O contrato ValidatorAnnounce no Terra Classic pode ter métodos diferentes

echo "   Verificando se o validador está anunciado..."
echo ""

# Tentar buscar eventos ou dados do contrato via REST API
# O ValidatorAnnounce no Terra Classic pode expor dados via query

# Verificar se há uma forma de consultar via REST
QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$VALIDATOR_ANNOUNCE_TERRA/smart"

# Tentar diferentes queries possíveis
echo "   Tentando query do contrato ValidatorAnnounce..."
echo ""

# Query para obter storage locations de um validador específico
# O contrato pode ter um método getAnnouncedStorageLocations(address)
VALIDATOR_HEX=$(echo "$VALIDATOR" | cut -c3-)
QUERY_DATA=$(echo -n "{\"get_announced_storage_locations\":{\"validator\":\"$VALIDATOR\"}}" | base64 -w 0)

RESPONSE=$(curl -s "$QUERY_URL/$QUERY_DATA" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
    DATA=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
    if [ -n "$DATA" ] && [ "$DATA" != "null" ] && [ "$DATA" != "" ]; then
        echo "   ✅ Validador está anunciado!"
        echo "   📦 Storage locations:"
        echo "$DATA" | jq '.' 2>/dev/null | sed 's/^/      /'
    else
        echo "   ❌ Validador não está anunciado ou query falhou"
    fi
else
    echo "   ⚠️  Não foi possível verificar via API REST"
    echo "   Tentando método alternativo..."
    echo ""
    
    # Tentar verificar via eventos ou outras formas
    echo "   💡 O ValidatorAnnounce do Terra Classic é um contrato Cosmos"
    echo "   Pode ser necessário verificar de forma diferente"
    echo ""
    echo "   Verifique manualmente:"
    echo "   - Contrato: $VALIDATOR_ANNOUNCE_TERRA"
    echo "   - Terra Finder: https://finder.terraclassic.community/testnet"
fi

echo ""
echo "========================================="
echo "💡 IMPORTANTE"
echo "========================================="
echo ""
echo "Para mensagens Sepolia → Terra Classic:"
echo ""
echo "1. A mensagem é enviada DO Sepolia"
echo "2. O ISM no Terra Classic (destino) valida a mensagem"
echo "3. Os validadores do Terra Classic precisam:"
echo "   → Criar checkpoints das mensagens recebidas"
echo "   → Anunciar no ValidatorAnnounce do TERRA CLASSIC"
echo "   → Disponibilizar checkpoints acessíveis"
echo ""
echo "4. O relayer busca checkpoints do domínio de ORIGEM (Sepolia)"
echo "   MAS os validadores que assinam são do domínio de DESTINO (Terra Classic)"
echo ""
echo "⚠️  Isso pode ser um problema de configuração do relayer!"
echo "   O relayer pode precisar buscar checkpoints dos validadores do Terra Classic"
echo "   que estão anunciados no Terra Classic, não no Sepolia"
echo ""

