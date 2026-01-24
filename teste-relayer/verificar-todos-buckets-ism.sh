#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR CHECKPOINTS NOS BUCKETS DOS VALIDATORS DO ISM                ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Validators do ISM e seus buckets
declare -A VALIDATOR_BUCKETS=(
    ["0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"]="hyperlane-testnet4-bsctestnet-validator-0"
    ["0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"]="hyperlane-testnet4-bsctestnet-validator-1"
    ["0x1f030345963c54ff8229720dd3a711c15c554aeb"]="hyperlane-testnet4-bsctestnet-validator-2"
)

SEQUENCE="12768"

for VALIDATOR in "${!VALIDATOR_BUCKETS[@]}"; do
    BUCKET="${VALIDATOR_BUCKETS[$VALIDATOR]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Validator: $VALIDATOR"
    echo "Bucket: $BUCKET"
    echo ""
    
    # Verificar checkpoint específico
    CHECKPOINT_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/checkpoint_${SEQUENCE}_with_id.json"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CHECKPOINT_URL" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE!"
        echo "     URL: $CHECKPOINT_URL"
        
        # Baixar checkpoint
        CHECKPOINT=$(curl -s "$CHECKPOINT_URL" 2>/dev/null || echo "")
        if [ ! -z "$CHECKPOINT" ]; then
            echo "     Tamanho: $(echo "$CHECKPOINT" | wc -c) bytes"
            
            # Extrair informações do checkpoint
            if command -v jq &> /dev/null; then
                ROOT=$(echo "$CHECKPOINT" | jq -r '.value.root // .root // "N/A"' 2>/dev/null || echo "N/A")
                INDEX=$(echo "$CHECKPOINT" | jq -r '.value.index // .index // "N/A"' 2>/dev/null || echo "N/A")
                echo "     Root: $ROOT"
                echo "     Index: $INDEX"
            fi
        fi
    else
        echo "  ⚠️  Checkpoint para sequence $SEQUENCE não encontrado (HTTP $HTTP_CODE)"
        
        # Tentar formato alternativo
        CHECKPOINT_URL2="https://${BUCKET}.s3.us-east-1.amazonaws.com/checkpoint_${SEQUENCE}.json"
        HTTP_CODE2=$(curl -s -o /dev/null -w "%{http_code}" "$CHECKPOINT_URL2" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE2" = "200" ]; then
            echo "  ✅ CHECKPOINT ENCONTRADO (formato alternativo)!"
            echo "     URL: $CHECKPOINT_URL2"
        fi
    fi
    
    # Listar últimos checkpoints
    echo ""
    echo "  📋 Últimos checkpoints no bucket:"
    LIST_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/?list-type=2&max-keys=10&prefix=checkpoint_"
    LIST_XML=$(curl -s "$LIST_URL" 2>/dev/null || echo "")
    
    if [ ! -z "$LIST_XML" ]; then
        echo "$LIST_XML" | grep -oE "<Key>checkpoint_[0-9]+[^<]*</Key>" | sed 's/<Key>//;s/<\/Key>//' | sort -V | tail -5 | sed 's/^/    - /'
    fi
    
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 RESUMO:"
echo "   Sequence verificada: $SEQUENCE"
echo "   Validators verificados: ${#VALIDATOR_BUCKETS[@]}"
echo ""

