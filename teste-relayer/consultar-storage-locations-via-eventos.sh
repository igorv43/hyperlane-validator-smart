#!/bin/bash

# ============================================================================
# Script: Consultar Storage Locations via Eventos do ValidatorAnnounce
# ============================================================================

set -e

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Validators do ISM
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "{"
echo "  \"validatorAnnounce\": \"$VALIDATOR_ANNOUNCE_BSC\","
echo "  \"rpc\": \"$BSC_RPC\","
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"method\": \"events\","
echo "  \"data\": {"

# Obter bloco atual
CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "0")
FROM_BLOCK=$((CURRENT_BLOCK - 500000))  # Últimos ~500k blocos

echo "    \"currentBlock\": $CURRENT_BLOCK,"
echo "    \"fromBlock\": $FROM_BLOCK,"
echo "    \"validatorsFromEvents\": ["

# Consultar eventos para cada validator do ISM
FIRST=true
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    echo "      {"
    echo "        \"validator\": \"$VALIDATOR\","
    echo "        \"events\": ["
    
    # Consultar eventos ValidatorAnnounce para este validator
    EVENTS=$(cast logs \
        --from-block $FROM_BLOCK \
        --to-block $CURRENT_BLOCK \
        --address "$VALIDATOR_ANNOUNCE_BSC" \
        --rpc-url "$BSC_RPC" 2>&1 | \
        grep -i "$VALIDATOR" | \
        head -20 || echo "")
    
    if [ -z "$EVENTS" ]; then
        echo "        ]"
    else
        # Tentar extrair storage locations dos eventos
        STORAGE_LOCATIONS=$(echo "$EVENTS" | grep -oE "s3://[^ ]+" | sort -u || echo "")
        
        if [ ! -z "$STORAGE_LOCATIONS" ]; then
            echo "$STORAGE_LOCATIONS" | while read -r storage; do
                echo "          \"$storage\","
            done | sed '$ s/,$//'
        fi
        echo "        ]"
    fi
    
    echo -n "      }"
done

echo ""
echo "    ]"
echo "  }"
echo "}"

