#!/bin/bash

BUCKET="hyperlane-validator-signatures-igorverasvalidador-terraclassic"
BUCKET_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR CHECKPOINTS DO VALIDATOR TERRA CLASSIC                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "📦 Bucket: $BUCKET"
echo "   URL: $BUCKET_URL"
echo ""

# Listar checkpoints recentes
echo "🔍 Checkpoints recentes:"
curl -s "${BUCKET_URL}?list-type=2&max-keys=50&prefix=checkpoint_" | \
    grep -oE "<Key>checkpoint_[0-9]+[^<]*</Key>" | \
    sed 's/<Key>//;s/<\/Key>//' | \
    sort -V | \
    tail -10 | \
    while read -r FILE; do
        # Obter data de modificação
        DATE=$(curl -s "${BUCKET_URL}?list-type=2&prefix=${FILE}" | \
            grep -oE "<LastModified>[^<]+</LastModified>" | \
            sed 's/<LastModified>//;s/<\/LastModified>//' | head -1)
        SEQUENCE=$(echo "$FILE" | grep -oE "[0-9]+")
        echo "  ✅ Sequence $SEQUENCE - $FILE ($DATE)"
    done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar checkpoint mais recente
echo "📊 Checkpoint mais recente:"
LATEST_INDEX=$(curl -s "${BUCKET_URL}checkpoint_latest_index.json" 2>/dev/null || echo "")
if [ ! -z "$LATEST_INDEX" ]; then
    echo "  Índice mais recente: $LATEST_INDEX"
else
    # Tentar obter do último checkpoint
    LATEST_CHECKPOINT=$(curl -s "${BUCKET_URL}?list-type=2&max-keys=1000&prefix=checkpoint_" | \
        grep -oE "<Key>checkpoint_[0-9]+[^<]*</Key>" | \
        sed 's/<Key>//;s/<\/Key>//' | \
        sort -V | \
        tail -1)
    
    if [ ! -z "$LATEST_CHECKPOINT" ]; then
        SEQUENCE=$(echo "$LATEST_CHECKPOINT" | grep -oE "[0-9]+")
        echo "  Sequence mais recente encontrada: $SEQUENCE"
        echo "  Arquivo: $LATEST_CHECKPOINT"
        
        # Baixar e mostrar informações do checkpoint
        CHECKPOINT_JSON=$(curl -s "${BUCKET_URL}${LATEST_CHECKPOINT}" 2>/dev/null)
        if [ ! -z "$CHECKPOINT_JSON" ]; then
            echo ""
            echo "  📄 Conteúdo do checkpoint:"
            echo "$CHECKPOINT_JSON" | jq '.' 2>/dev/null | head -20 || echo "$CHECKPOINT_JSON" | head -20
        fi
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar todas as sequences disponíveis
echo "📋 Todas as sequences disponíveis:"
SEQUENCES=$(curl -s "${BUCKET_URL}?list-type=2&max-keys=1000&prefix=checkpoint_" | \
    grep -oE "<Key>checkpoint_[0-9]+[^<]*</Key>" | \
    sed 's/<Key>//;s/<\/Key>//' | \
    grep -oE "[0-9]+" | \
    sort -n)

TOTAL=$(echo "$SEQUENCES" | wc -l)
MIN=$(echo "$SEQUENCES" | head -1)
MAX=$(echo "$SEQUENCES" | tail -1)

echo "  Total de checkpoints: $TOTAL"
echo "  Sequence mínima: $MIN"
echo "  Sequence máxima: $MAX"
echo ""

