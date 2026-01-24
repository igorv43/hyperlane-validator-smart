#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Validators do ISM
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR CHECKPOINTS DOS VALIDATORS DO ISM                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

if ! command -v aws &> /dev/null; then
    echo "⚠️  AWS CLI não está instalado. Não é possível verificar checkpoints."
    exit 1
fi

# Consultar storage locations
RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address[])" \
    "[$(IFS=,; echo "${VALIDATORS_ISM[*]}")]" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$RESULT" | grep -qi "error\|revert"; then
    echo "❌ Erro ao consultar: $RESULT"
    exit 1
fi

DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null)

echo "🔍 Verificando checkpoints nos buckets S3..."
echo ""

VALIDATORS_WITH_CHECKPOINTS=0

for ((i=0; i<${#VALIDATORS_ISM[@]}; i++)); do
    VALIDATOR="${VALIDATORS_ISM[$i]}"
    STORAGE_JSON=$(echo "$DECODED" | jq -r ".[$i] // []" 2>/dev/null || echo "[]")
    STORAGE_COUNT=$(echo "$STORAGE_JSON" | jq 'length' 2>/dev/null || echo "0")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Validator: $VALIDATOR"
    echo ""
    
    if [ "$STORAGE_COUNT" -eq 0 ]; then
        echo "  ⚠️  Nenhuma storage location anunciada"
        echo ""
        continue
    fi
    
    echo "  Storage locations: $STORAGE_COUNT"
    echo ""
    
    HAS_CHECKPOINTS_IN_VALIDATOR=false
    
    echo "$STORAGE_JSON" | jq -r '.[]' | while read -r BUCKET_PATH; do
        if [[ "$BUCKET_PATH" == s3://* ]]; then
            BUCKET=$(echo "$BUCKET_PATH" | sed -E 's|s3://([^/]+).*|\1|')
            PREFIX=$(echo "$BUCKET_PATH" | sed -E 's|s3://[^/]+/?(.*)|\1|')
            
            if [ ! -z "$PREFIX" ]; then
                S3_PATH="s3://${BUCKET}/${PREFIX}/"
            else
                S3_PATH="s3://${BUCKET}/"
            fi
            
            echo "  📦 Bucket: $BUCKET"
            echo "     Path: $S3_PATH"
            
            # Verificar se o bucket existe e é acessível
            if ! aws s3 ls "s3://${BUCKET}/" > /dev/null 2>&1; then
                echo "     ❌ Bucket não acessível ou não existe"
                echo ""
                continue
            fi
            
            # Listar arquivos recentes
            FILES=$(aws s3 ls "$S3_PATH" --recursive 2>/dev/null | sort -k1,2 | tail -10 || echo "")
            
            if [ -z "$FILES" ]; then
                echo "     ⚠️  Nenhum arquivo encontrado"
                echo ""
                continue
            fi
            
            HAS_CHECKPOINTS_IN_VALIDATOR=true
            VALIDATORS_WITH_CHECKPOINTS=$((VALIDATORS_WITH_CHECKPOINTS + 1))
            
            echo "     ✅ Arquivos encontrados:"
            echo "$FILES" | while read -r LINE; do
                DATE=$(echo "$LINE" | awk '{print $1" "$2}')
                SIZE=$(echo "$LINE" | awk '{print $3}')
                FILE=$(echo "$LINE" | awk '{print $4}')
                
                # Extrair sequence se for checkpoint
                SEQUENCE=""
                if echo "$FILE" | grep -qiE "checkpoint.*[0-9]+"; then
                    SEQUENCE=$(echo "$FILE" | grep -oE "[0-9]+" | tail -1)
                fi
                
                echo "        📄 $FILE"
                echo "           Data: $DATE | Tamanho: $SIZE bytes"
                if [ ! -z "$SEQUENCE" ]; then
                    echo "           Sequence: $SEQUENCE"
                fi
            done
            
            # Verificar checkpoint específico para sequence 12768
            SEQUENCE_CHECK="12768"
            CHECKPOINT_FILE=$(echo "$FILES" | grep -i "checkpoint.*${SEQUENCE_CHECK}" || echo "")
            if [ ! -z "$CHECKPOINT_FILE" ]; then
                echo ""
                echo "     ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE_CHECK!"
                echo "        $CHECKPOINT_FILE"
            fi
            echo ""
        fi
    done
    
    if [ "$HAS_CHECKPOINTS_IN_VALIDATOR" = true ]; then
        echo "  ✅ Validator tem checkpoints disponíveis"
    else
        echo "  ❌ Validator NÃO tem checkpoints disponíveis"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 RESUMO:"
echo "   Validators verificados: ${#VALIDATORS_ISM[@]}"
echo "   Validators com checkpoints: $VALIDATORS_WITH_CHECKPOINTS"
echo ""

