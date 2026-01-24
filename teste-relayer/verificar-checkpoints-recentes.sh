#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR VALIDATORS COM CHECKPOINTS RECENTES                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Obter todos os validators anunciados
echo "📋 Obtendo lista de validators anunciados..."
ANNOUNCED_VALIDATORS_RAW=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedValidators()" \
    --rpc-url "$BSC_RPC" 2>&1)

ALL_VALIDATORS=($(cast --abi-decode "getAnnouncedValidators()(address[])" "$ANNOUNCED_VALIDATORS_RAW" 2>/dev/null | grep -oE "0x[a-fA-F0-9]{40}"))

TOTAL=${#ALL_VALIDATORS[@]}
echo "✅ Total de validators: $TOTAL"
echo ""

if ! command -v aws &> /dev/null; then
    echo "⚠️  AWS CLI não está instalado. Verificando apenas storage locations anunciadas..."
    echo ""
    
    # Verificar storage locations sem AWS CLI
    BATCH_SIZE=10
    VALIDATORS_WITH_STORAGE=0
    
    for ((i=0; i<$TOTAL; i+=BATCH_SIZE)); do
        BATCH=("${ALL_VALIDATORS[@]:i:BATCH_SIZE}")
        BATCH_ARRAY="[$(IFS=,; echo "${BATCH[*]}")]"
        
        RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
            "getAnnouncedStorageLocations(address[])" \
            "$BATCH_ARRAY" \
            --rpc-url "$BSC_RPC" 2>&1)
        
        if ! echo "$RESULT" | grep -qi "error\|revert"; then
            DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null || echo "")
            
            if [ ! -z "$DECODED" ] && [ "$DECODED" != "()" ]; then
                for ((j=0; j<${#BATCH[@]}; j++)); do
                    VALIDATOR="${BATCH[$j]}"
                    STORAGE_JSON=$(echo "$DECODED" | jq -r ".[$j] // []" 2>/dev/null || echo "[]")
                    STORAGE_COUNT=$(echo "$STORAGE_JSON" | jq 'length' 2>/dev/null || echo "0")
                    
                    if [ "$STORAGE_COUNT" -gt 0 ]; then
                        VALIDATORS_WITH_STORAGE=$((VALIDATORS_WITH_STORAGE + 1))
                        echo "  ✅ $VALIDATOR"
                        echo "$STORAGE_JSON" | jq -r '.[]' | sed 's/^/    → /'
                    fi
                done
            fi
        fi
    done
    
    echo ""
    echo "📊 Resumo: $VALIDATORS_WITH_STORAGE de $TOTAL validators têm storage locations anunciadas"
    exit 0
fi

echo "🔍 Verificando checkpoints nos buckets S3..."
echo ""

# Verificar storage locations e checkpoints
BATCH_SIZE=10
VALIDATORS_WITH_CHECKPOINTS=0
VALIDATORS_WITH_STORAGE=0
VALIDATORS_CHECKED=0

declare -a RESULTS_JSON

for ((i=0; i<$TOTAL; i+=BATCH_SIZE)); do
    BATCH=("${ALL_VALIDATORS[@]:i:BATCH_SIZE}")
    BATCH_ARRAY="[$(IFS=,; echo "${BATCH[*]}")]"
    
    RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedStorageLocations(address[])" \
        "$BATCH_ARRAY" \
        --rpc-url "$BSC_RPC" 2>&1)
    
    if ! echo "$RESULT" | grep -qi "error\|revert"; then
        DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null || echo "")
        
        if [ ! -z "$DECODED" ] && [ "$DECODED" != "()" ]; then
            for ((j=0; j<${#BATCH[@]}; j++)); do
                VALIDATOR="${BATCH[$j]}"
                VALIDATORS_CHECKED=$((VALIDATORS_CHECKED + 1))
                STORAGE_JSON=$(echo "$DECODED" | jq -r ".[$j] // []" 2>/dev/null || echo "[]")
                STORAGE_COUNT=$(echo "$STORAGE_JSON" | jq 'length' 2>/dev/null || echo "0")
                
                if [ "$STORAGE_COUNT" -gt 0 ]; then
                    VALIDATORS_WITH_STORAGE=$((VALIDATORS_WITH_STORAGE + 1))
                    
                    # Verificar cada storage location
                    HAS_CHECKPOINTS=false
                    LATEST_CHECKPOINT=""
                    LATEST_DATE=""
                    
                    echo "$STORAGE_JSON" | jq -r '.[]' | while read -r BUCKET_PATH; do
                        if [[ "$BUCKET_PATH" == s3://* ]]; then
                            BUCKET=$(echo "$BUCKET_PATH" | sed -E 's|s3://([^/]+).*|\1|')
                            PREFIX=$(echo "$BUCKET_PATH" | sed -E 's|s3://[^/]+/?(.*)|\1|')
                            
                            if [ ! -z "$PREFIX" ]; then
                                S3_PATH="s3://${BUCKET}/${PREFIX}/"
                            else
                                S3_PATH="s3://${BUCKET}/"
                            fi
                            
                            # Listar arquivos recentes (últimos 20)
                            FILES=$(aws s3 ls "$S3_PATH" --recursive 2>/dev/null | sort -k1,2 | tail -20 | awk '{print $1" "$2" "$4}' || echo "")
                            
                            if [ ! -z "$FILES" ]; then
                                HAS_CHECKPOINTS=true
                                LATEST=$(echo "$FILES" | tail -1)
                                LATEST_DATE=$(echo "$LATEST" | awk '{print $1" "$2}')
                                LATEST_FILE=$(echo "$LATEST" | awk '{print $3}')
                                
                                echo "  ✅ $VALIDATOR"
                                echo "    Storage: $BUCKET_PATH"
                                echo "    Último checkpoint: $LATEST_DATE"
                                echo "    Arquivo: $LATEST_FILE"
                                echo ""
                                
                                # Extrair sequence do nome do arquivo se possível
                                if echo "$LATEST_FILE" | grep -qi "checkpoint.*[0-9]"; then
                                    SEQUENCE=$(echo "$LATEST_FILE" | grep -oE "[0-9]+" | tail -1)
                                    echo "    Sequence: $SEQUENCE"
                                    echo ""
                                fi
                            fi
                        fi
                    done
                fi
            done
        fi
    fi
    
    # Progress
    if [ $((i % 50)) -eq 0 ] && [ $i -gt 0 ]; then
        echo "  Progresso: $VALIDATORS_CHECKED/$TOTAL validators verificados..."
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  RESUMO                                                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Total de validators: $TOTAL"
echo "Validators com storage locations: $VALIDATORS_WITH_STORAGE"
echo "Validators verificados: $VALIDATORS_CHECKED"
echo ""

