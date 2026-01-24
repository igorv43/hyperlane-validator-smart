#!/bin/bash

# Consultar storage locations no Terra Classic E BSC

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
VALIDATOR_ANNOUNCE_TERRA="terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5"
BSC_RPC="https://bsc-testnet.publicnode.com"
TERRA_RPC="https://rpc.luncblaze.com:443"
TERRA_CHAIN_ID="rebel-2"

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "{"
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"validators\": ["

FIRST=true
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    echo "    {"
    echo "      \"validator\": \"$VALIDATOR\","
    
    # Consultar no BSC
    echo "      \"bsc\": {"
    STORAGE_BSC=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedStorageLocations(address)" \
        "$VALIDATOR" \
        --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    
    if echo "$STORAGE_BSC" | grep -qi "error\|revert\|timeout"; then
        echo "        \"storageLocations\": [],"
        echo "        \"status\": \"sem_storage_location_anunciada\""
    else
        STORAGE_DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address)(string[])" "$STORAGE_BSC" 2>/dev/null || echo "")
        STORAGE_S3=$(echo "$STORAGE_DECODED" | grep -oE "s3://[^ ]+" | head -1 || echo "")
        if [ ! -z "$STORAGE_S3" ]; then
            echo "        \"storageLocations\": [\"$STORAGE_S3\"],"
            echo "        \"status\": \"com_storage_location_anunciada\""
        else
            echo "        \"storageLocations\": [],"
            echo "        \"status\": \"sem_storage_location_anunciada\""
        fi
    fi
    echo "      },"
    
    # Consultar no Terra Classic
    echo "      \"terraClassic\": {"
    VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
    QUERY_TERRA="{\"get_announce_storage_locations\": {\"validators\": [\"$VALIDATOR_CLEAN\"]}}"
    
    STORAGE_TERRA=$(timeout 15 terrad query wasm contract-state smart \
        "$VALIDATOR_ANNOUNCE_TERRA" \
        "$QUERY_TERRA" \
        --chain-id "$TERRA_CHAIN_ID" \
        --node "$TERRA_RPC" \
        --output json 2>&1 || echo "TIMEOUT")
    
    if echo "$STORAGE_TERRA" | grep -qi "error\|timeout\|TIMEOUT"; then
        echo "        \"storageLocations\": [],"
        echo "        \"status\": \"erro_ao_consultar\""
    else
        # Extrair storage locations da resposta
        STORAGE_S3_TERRA=$(echo "$STORAGE_TERRA" | jq -r '.data.storage_locations[]?[1][]? // empty' 2>/dev/null | grep -oE "s3://[^ ]+" | head -1 || echo "")
        if [ ! -z "$STORAGE_S3_TERRA" ]; then
            echo "        \"storageLocations\": [\"$STORAGE_S3_TERRA\"],"
            echo "        \"status\": \"com_storage_location_anunciada\""
        else
            echo "        \"storageLocations\": [],"
            echo "        \"status\": \"sem_storage_location_anunciada\""
        fi
    fi
    echo "      }"
    
    echo -n "    }"
done

echo ""
echo "  ]"
echo "}"

