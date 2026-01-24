#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  ANÁLISE: SEQUENCES NOS BUCKETS DOS VALIDATORS DO ISM                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

declare -A VALIDATOR_BUCKETS=(
    ["0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"]="hyperlane-testnet4-bsctestnet-validator-0"
    ["0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"]="hyperlane-testnet4-bsctestnet-validator-1"
    ["0x1f030345963c54ff8229720dd3a711c15c554aeb"]="hyperlane-testnet4-bsctestnet-validator-2"
)

SEQUENCE_TARGET="12768"

for VALIDATOR in "${!VALIDATOR_BUCKETS[@]}"; do
    BUCKET="${VALIDATOR_BUCKETS[$VALIDATOR]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Validator: $VALIDATOR"
    echo "Bucket: $BUCKET"
    echo ""
    
    # Obter todas as sequences
    LIST_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/?list-type=2&max-keys=1000&prefix=checkpoint_"
    LIST_XML=$(curl -s "$LIST_URL" 2>/dev/null || echo "")
    
    if [ -z "$LIST_XML" ]; then
        echo "  ⚠️  Não foi possível acessar o bucket"
        echo ""
        continue
    fi
    
    # Extrair sequences
    SEQUENCES=$(echo "$LIST_XML" | grep -oE "<Key>checkpoint_[0-9]+[^<]*</Key>" | sed 's/<Key>//;s/<\/Key>//' | grep -oE "[0-9]+" | sort -n)
    
    if [ -z "$SEQUENCES" ]; then
        echo "  ⚠️  Nenhum checkpoint encontrado"
        echo ""
        continue
    fi
    
    TOTAL=$(echo "$SEQUENCES" | wc -l)
    MIN=$(echo "$SEQUENCES" | head -1)
    MAX=$(echo "$SEQUENCES" | tail -1)
    
    echo "  📊 Estatísticas:"
    echo "     Total de checkpoints: $TOTAL"
    echo "     Sequence mínima: $MIN"
    echo "     Sequence máxima: $MAX"
    echo ""
    
    # Verificar se a sequence target existe
    if echo "$SEQUENCES" | grep -q "^${SEQUENCE_TARGET}$"; then
        echo "  ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE_TARGET!"
    else
        echo "  ❌ Checkpoint para sequence $SEQUENCE_TARGET NÃO encontrado"
        
        # Encontrar sequences mais próximas
        CLOSEST_BELOW=$(echo "$SEQUENCES" | awk -v target="$SEQUENCE_TARGET" '$1 < target {print $1}' | tail -1)
        CLOSEST_ABOVE=$(echo "$SEQUENCES" | awk -v target="$SEQUENCE_TARGET" '$1 > target {print $1}' | head -1)
        
        if [ ! -z "$CLOSEST_BELOW" ]; then
            DIFF_BELOW=$((SEQUENCE_TARGET - CLOSEST_BELOW))
            echo "     Sequence mais próxima abaixo: $CLOSEST_BELOW (diff: -$DIFF_BELOW)"
        fi
        
        if [ ! -z "$CLOSEST_ABOVE" ]; then
            DIFF_ABOVE=$((CLOSEST_ABOVE - SEQUENCE_TARGET))
            echo "     Sequence mais próxima acima: $CLOSEST_ABOVE (diff: +$DIFF_ABOVE)"
        fi
    fi
    
    # Mostrar últimas 5 sequences
    echo ""
    echo "  📋 Últimas 5 sequences:"
    echo "$SEQUENCES" | tail -5 | awk '{print "     - " $1}'
    
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 CONCLUSÃO:"
echo "   Sequence verificada: $SEQUENCE_TARGET"
echo "   Se os validators não têm checkpoints para esta sequence,"
echo "   significa que eles não estão gerando checkpoints para mensagens BSC->Terra Classic"
echo "   ou os checkpoints estão muito desatualizados."
echo ""

