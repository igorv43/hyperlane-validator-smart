#!/bin/bash

echo "========================================="
echo "🔍 VERIFICAÇÃO DE CHECKPOINTS DOS VALIDADORES"
echo "========================================="
echo ""

# Validadores identificados nos logs
VALIDATORS=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

THRESHOLD=2
SEPOLIA_RPC="https://1rpc.io/sepolia"
VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
MESSAGE_ID="0x0a067dda3182caf21401732b58dc2a34c796bbb8a3e01ed398cf8942bf78edfa"
ORIGIN_DOMAIN="11155111"  # Sepolia

echo "📋 Informações:"
echo "   Threshold necessário: $THRESHOLD de ${#VALIDATORS[@]} validadores"
echo "   Message ID: $MESSAGE_ID"
echo "   Origem: Sepolia ($ORIGIN_DOMAIN)"
echo ""

echo "1️⃣ Verificando anúncios dos validadores no ValidatorAnnounce..."
echo ""

LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 5000))  # Últimos 5000 blocos

for i in "${!VALIDATORS[@]}"; do
    VALIDATOR="${VALIDATORS[$i]}"
    echo "   [$((i+1))] Verificando: $VALIDATOR"
    
    # Buscar anúncios deste validador
    ANNOUNCEMENT=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
        "Announcement(address indexed validator, string storageLocation, string[] domains)" \
        --address "$VALIDATOR_ANNOUNCE" \
        --topic1 "$(cast --to-uint256 "$VALIDATOR" | cut -c3-)" \
        --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tail -1)
    
    if [ -n "$ANNOUNCEMENT" ]; then
        echo "      ✅ Anúncio encontrado!"
        # Extrair storage location
        STORAGE=$(echo "$ANNOUNCEMENT" | grep -oP 'storageLocation: \K[^,]+' || echo "")
        if [ -n "$STORAGE" ]; then
            echo "      📍 Storage Location: $STORAGE"
            
            # Verificar se é S3
            if echo "$STORAGE" | grep -q "s3://"; then
                BUCKET=$(echo "$STORAGE" | sed 's|s3://||' | cut -d'/' -f1)
                echo "      🪣 Bucket S3: $BUCKET"
                echo "      💡 Verifique se o relayer tem acesso de leitura a este bucket"
            elif echo "$STORAGE" | grep -q "https://"; then
                echo "      🌐 URL HTTP: $STORAGE"
                echo "      💡 Verifique se a URL está acessível"
            else
                echo "      📁 Local: $STORAGE"
                echo "      ⚠️  Checkpoints locais - relayer precisa de allowLocalCheckpointSyncers=true"
            fi
        fi
    else
        echo "      ❌ Nenhum anúncio encontrado"
        echo "      ⚠️  Este validador não anunciou sua localização de checkpoints"
    fi
    echo ""
done

echo "2️⃣ Verificando configuração do relayer para checkpoints..."
echo ""

if [ -f "hyperlane/relayer.testnet.json" ]; then
    ALLOW_LOCAL=$(jq -r '.allowLocalCheckpointSyncers // "not set"' hyperlane/relayer.testnet.json 2>/dev/null)
    echo "   allowLocalCheckpointSyncers: $ALLOW_LOCAL"
    
    # Verificar se há configuração de checkpointSyncer
    CHECKPOINT_SYNCER=$(jq -r '.checkpointSyncer // "not set"' hyperlane/relayer.testnet.json 2>/dev/null)
    if [ "$CHECKPOINT_SYNCER" != "not set" ] && [ "$CHECKPOINT_SYNCER" != "null" ]; then
        echo "   checkpointSyncer configurado: Sim"
        echo "$CHECKPOINT_SYNCER" | jq '.' 2>/dev/null | sed 's/^/      /'
    else
        echo "   checkpointSyncer: Não configurado"
    fi
else
    echo "   ❌ Arquivo de configuração não encontrado"
fi

echo ""
echo "3️⃣ Verificando logs do relayer para tentativas de buscar checkpoints..."
echo ""

# Buscar logs relacionados a checkpoint syncer
CHECKPOINT_LOGS=$(docker logs hpl-relayer-testnet 2>&1 | grep -iE "checkpoint.*syncer|s3.*checkpoint|fetching.*checkpoint" | tail -10)

if [ -n "$CHECKPOINT_LOGS" ]; then
    echo "   Logs encontrados:"
    echo "$CHECKPOINT_LOGS" | sed 's/^/      /'
else
    echo "   ⚠️  Nenhum log de checkpoint syncer encontrado"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "💡 DIAGNÓSTICO:"
echo ""
echo "   Se nenhum validador está anunciado:"
echo "   → Os validadores externos não estão rodando ou não anunciaram"
echo ""
echo "   Se validadores estão anunciados mas relayer não acessa:"
echo "   → Verifique se allowLocalCheckpointSyncers está correto"
echo "   → Verifique se o relayer tem acesso ao S3 (se usar S3)"
echo "   → Verifique se as URLs HTTP estão acessíveis (se usar HTTP)"
echo ""
echo "   Se quorum não é atingido:"
echo "   → Menos de $THRESHOLD validadores estão criando checkpoints"
echo "   → Checkpoints não estão acessíveis para o relayer"

