#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  DIAGNÓSTICO CORRIGIDO: MENSAGEM TERRA CLASSIC -> SOLANA                 ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

BUCKET="hyperlane-validator-signatures-igorverasvalidador-terraclassic"
BUCKET_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/"

echo "✅ VALIDATOR ESTÁ GERANDO CHECKPOINTS!"
echo ""
echo "📦 Bucket: $BUCKET"
echo "   URL: $BUCKET_URL"
echo ""

# Obter todas as sequences
SEQUENCES=$(curl -s "${BUCKET_URL}?list-type=2&max-keys=1000&prefix=checkpoint_" | \
    grep -oE "<Key>checkpoint_[0-9]+[^<]*</Key>" | \
    sed 's/<Key>//;s/<\/Key>//' | \
    grep -oE "[0-9]+" | \
    sort -n)

TOTAL=$(echo "$SEQUENCES" | wc -l)
MAX=$(echo "$SEQUENCES" | tail -1)

echo "📊 Estatísticas dos checkpoints:"
echo "   Total de checkpoints: $TOTAL"
echo "   Sequence mais recente: $MAX"
echo ""

# Verificar checkpoint mais recente
LATEST_CHECKPOINT="checkpoint_${MAX}_with_id.json"
echo "📄 Checkpoint mais recente: $LATEST_CHECKPOINT"
echo ""

# Verificar se há informações sobre destino
CHECKPOINT_DATA=$(curl -s "${BUCKET_URL}${LATEST_CHECKPOINT}" 2>/dev/null)

if [ ! -z "$CHECKPOINT_DATA" ]; then
    echo "📋 Informações do checkpoint:"
    echo "$CHECKPOINT_DATA" | jq -r '.value | {root, index, merkle_tree_hook_address, mailbox_address}' 2>/dev/null || echo "$CHECKPOINT_DATA" | head -10
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 POSSÍVEIS CAUSAS DA MENSAGEM NÃO CHEGAR:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. ❓ A mensagem pode ter uma sequence mais nova que $MAX"
echo "   → Verificar qual é a sequence da mensagem enviada"
echo ""
echo "2. ❓ Relayer não está processando mensagens Terra->Solana"
echo "   → Verificar logs do relayer"
echo "   → Verificar se Solana está nas chains configuradas"
echo ""
echo "3. ❓ ISM do Solana não tem validators do Terra Classic"
echo "   → Verificar ISM do Solana para domain 1325"
echo "   → Verificar se o validator está no ISM do Solana"
echo ""
echo "4. ❓ Quorum não está sendo atingido"
echo "   → Verificar threshold do ISM do Solana"
echo "   → Verificar se há outros validators gerando checkpoints"
echo ""
echo "5. ❓ Relayer não está lendo checkpoints do S3"
echo "   → Verificar credenciais AWS do relayer"
echo "   → Verificar se o relayer consegue acessar o bucket S3"
echo ""

