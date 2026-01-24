#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

echo "🔍 Obtendo TODOS os validators anunciados e suas storage locations..."
echo ""

# Obter lista de validators
ANNOUNCED_VALIDATORS_RAW=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedValidators()" \
    --rpc-url "$BSC_RPC" 2>&1)

ALL_VALIDATORS=($(cast --abi-decode "getAnnouncedValidators()(address[])" "$ANNOUNCED_VALIDATORS_RAW" 2>/dev/null | grep -oE "0x[a-fA-F0-9]{40}"))

echo "Total de validators: ${#ALL_VALIDATORS[@]}"
echo ""

# Consultar storage locations para TODOS os validators (em lotes de 10)
echo "{"
echo "  \"validatorAnnounce\": \"$VALIDATOR_ANNOUNCE_BSC\","
echo "  \"rpc\": \"$BSC_RPC\","
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"method\": \"getAnnouncedStorageLocations(address[]) - como relayer\","
echo "  \"data\": {"
echo "    \"storage_locations\": ["

FIRST=true
BATCH_SIZE=10

for ((i=0; i<${#ALL_VALIDATORS[@]}; i+=BATCH_SIZE)); do
    BATCH=("${ALL_VALIDATORS[@]:i:BATCH_SIZE}")
    
    # Criar array para a chamada
    BATCH_ARRAY="[$(IFS=,; echo "${BATCH[*]}")]"
    
    # Consultar
    RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedStorageLocations(address[])" \
        "$BATCH_ARRAY" \
        --rpc-url "$BSC_RPC" 2>&1)
    
    if ! echo "$RESULT" | grep -qi "error\|revert"; then
        DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null || echo "")
        
        if [ ! -z "$DECODED" ] && [ "$DECODED" != "()" ]; then
            # Processar cada validator do batch
            for ((j=0; j<${#BATCH[@]}; j++)); do
                if [ "$FIRST" = false ]; then
                    echo ","
                fi
                FIRST=false
                
                VALIDATOR="${BATCH[$j]}"
                VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
                
                # Extrair storage locations para este validator (j-ésimo no resultado)
                # O resultado é um array de arrays, precisamos extrair o j-ésimo
                STORAGE_ARRAY=$(echo "$DECODED" | jq -r ".[$j] // []" 2>/dev/null || echo "[]")
                
                echo "      ["
                echo "        \"$VALIDATOR_CLEAN\","
                echo "        $STORAGE_ARRAY"
                echo -n "      ]"
            done
        fi
    fi
done

echo ""
echo "    ]"
echo "  }"
echo "}"

