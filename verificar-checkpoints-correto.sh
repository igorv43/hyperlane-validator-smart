#!/bin/bash

echo "========================================="
echo "🔍 VERIFICAÇÃO CORRETA DE CHECKPOINTS"
echo "========================================="
echo ""

# A mensagem foi enviada DE Sepolia PARA Terra Classic
ORIGIN_DOMAIN="11155111"  # Sepolia (onde a mensagem foi enviada)
DESTINATION_DOMAIN="1325"  # Terra Classic (onde será entregue)
MESSAGE_ID="0x0a067dda3182caf21401732b58dc2a34c796bbb8a3e01ed398cf8942bf78edfa"

echo "📋 Informações da Mensagem:"
echo "   Message ID: $MESSAGE_ID"
echo "   Origem: Sepolia (domain $ORIGIN_DOMAIN) ← CHECKPOINTS DEVEM SER BUSCADOS AQUI"
echo "   Destino: Terra Classic (domain $DESTINATION_DOMAIN)"
echo ""

echo "💡 IMPORTANTE:"
echo "   O relayer precisa buscar checkpoints do domínio de ORIGEM (Sepolia)"
echo "   porque os validadores do Sepolia assinam as mensagens enviadas DO Sepolia"
echo ""

# Validadores do ISM (estes são os validadores que devem criar checkpoints)
VALIDATORS=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

THRESHOLD=2

echo "1️⃣ Verificando anúncios dos validadores do SEPOLIA..."
echo "   (Estes validadores devem criar checkpoints das mensagens enviadas do Sepolia)"
echo ""

SEPOLIA_RPC="https://1rpc.io/sepolia"
VALIDATOR_ANNOUNCE_SEPOLIA="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"

LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 10000))  # Últimos 10000 blocos

echo "   Buscando anúncios no contrato: $VALIDATOR_ANNOUNCE_SEPOLIA"
echo "   Blocos: $FROM_BLOCK até $LATEST_BLOCK"
echo ""

# Buscar TODOS os anúncios recentes primeiro
echo "   Buscando todos os anúncios recentes..."
ALL_ANNOUNCEMENTS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
    "Announcement(address indexed validator, string storageLocation, string[] domains)" \
    --address "$VALIDATOR_ANNOUNCE_SEPOLIA" \
    --rpc-url "$SEPOLIA_RPC" 2>/dev/null)

if [ -z "$ALL_ANNOUNCEMENTS" ]; then
    echo "   ❌ Nenhum anúncio encontrado no Sepolia"
    echo ""
    echo "   ⚠️  PROBLEMA: Nenhum validador anunciou checkpoints no Sepolia"
    echo "      Isso significa que os validadores não estão rodando ou não anunciaram"
else
    echo "   ✅ Anúncios encontrados:"
    echo "$ALL_ANNOUNCEMENTS" | head -30 | sed 's/^/      /'
    echo ""
    
    # Verificar se algum dos validadores do ISM está na lista
    echo "   Verificando se os validadores do ISM estão anunciados..."
    for i in "${!VALIDATORS[@]}"; do
        VALIDATOR="${VALIDATORS[$i]}"
        if echo "$ALL_ANNOUNCEMENTS" | grep -qi "${VALIDATOR:2}"; then
            echo "      ✅ [$((i+1))] $VALIDATOR - ANUNCIADO"
        else
            echo "      ❌ [$((i+1))] $VALIDATOR - NÃO ANUNCIADO"
        fi
    done
fi

echo ""
echo "2️⃣ Verificando se os anúncios incluem o domínio Sepolia ($ORIGIN_DOMAIN)..."
echo ""

# Os validadores devem anunciar para quais domínios eles criam checkpoints
# Normalmente anunciam para o domínio onde estão validando (origem)
if [ -n "$ALL_ANNOUNCEMENTS" ]; then
    # Verificar se há anúncios que mencionam o domínio Sepolia
    if echo "$ALL_ANNOUNCEMENTS" | grep -q "$ORIGIN_DOMAIN\|sepolia\|11155111"; then
        echo "   ✅ Alguns anúncios mencionam Sepolia"
    else
        echo "   ⚠️  Anúncios encontrados mas não mencionam explicitamente Sepolia"
        echo "      (Isso pode ser normal se anunciarem para múltiplos domínios)"
    fi
fi

echo ""
echo "3️⃣ Verificando logs do relayer para ver qual domínio ele está tentando buscar..."
echo ""

# Buscar logs que mostram tentativas de buscar checkpoints
CHECKPOINT_ATTEMPTS=$(docker logs hpl-relayer-testnet 2>&1 | grep -iE "fetching.*checkpoint|checkpoint.*origin|origin.*11155111|sepolia.*checkpoint" | tail -10)

if [ -n "$CHECKPOINT_ATTEMPTS" ]; then
    echo "   Logs encontrados:"
    echo "$CHECKPOINT_ATTEMPTS" | sed 's/^/      /'
else
    echo "   ⚠️  Nenhum log específico de busca de checkpoint encontrado"
    echo "   (O relayer pode estar falhando silenciosamente)"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "📝 RESUMO:"
echo ""
echo "   Para mensagens enviadas DE Sepolia PARA Terra Classic:"
echo "   → O relayer precisa buscar checkpoints dos VALIDADORES DO SEPOLIA"
echo "   → Os validadores do Sepolia devem estar anunciados no ValidatorAnnounce do Sepolia"
echo "   → Os checkpoints devem estar acessíveis (S3, HTTP ou local)"
echo ""
echo "   Domínio a verificar: SEPOLIA (domain $ORIGIN_DOMAIN)"
echo "   Contrato ValidatorAnnounce: $VALIDATOR_ANNOUNCE_SEPOLIA"
echo ""

