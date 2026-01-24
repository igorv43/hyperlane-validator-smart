#!/bin/bash

# Consultar storage locations no BSC usando formato similar ao Terra Classic

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "{"
echo "  \"data\": {"
echo "    \"storage_locations\": ["

FIRST=true
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    # Remover 0x (como no Terra Classic)
    VALIDATOR_CLEAN=$(echo "$VALIDATOR" | sed 's/^0x//')
    
    echo "      ["
    echo "        \"$VALIDATOR_CLEAN\","
    echo "        ["
    
    # No BSC, vamos tentar a função que aceita array de validators
    # A função pode ser: getAnnounceStorageLocations(address[] memory validators)
    # Retorna: tuple(address,string[])[]
    
    # Tentar com array de um validator
    STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnounceStorageLocations(address[])" \
        "[$VALIDATOR]" \
        --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        # Se falhar, tentar função alternativa
        STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
            "getStorageLocations(address[])" \
            "[$VALIDATOR]" \
            --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    fi
    
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        # Array vazio se não encontrar
        echo "        ]"
    else
        # Tentar decodificar como tuple(address,string[])[]
        # Ou como (address,string[])[]
        STORAGE_DECODED=$(cast --abi-decode "getAnnounceStorageLocations(address[])(tuple(address,string[])[])" "$STORAGE_RESPONSE" 2>/dev/null || \
            cast --abi-decode "getStorageLocations(address[])(tuple(address,string[])[])" "$STORAGE_RESPONSE" 2>/dev/null || \
            echo "")
        
        if [ ! -z "$STORAGE_DECODED" ] && [ "$STORAGE_DECODED" != "()" ]; then
            # Extrair storage locations (s3://...)
            STORAGE_S3=$(echo "$STORAGE_DECODED" | grep -oE "s3://[^ ]+" || echo "")
            
            if [ ! -z "$STORAGE_S3" ]; then
                # Converter para array JSON
                FIRST_STORAGE=true
                echo "$STORAGE_S3" | while read -r storage; do
                    if [ "$FIRST_STORAGE" = false ]; then
                        echo ","
                    fi
                    FIRST_STORAGE=false
                    echo -n "          \"$storage\""
                done
                echo ""
            fi
        fi
        echo "        ]"
    fi
    
    echo -n "      ]"
done

echo ""
echo "    ]"
echo "  }"
echo "}"

