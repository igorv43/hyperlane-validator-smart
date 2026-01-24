#!/bin/bash

# Consultar storage locations no BSC no formato exato do Terra Classic

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Obter todos os validators anunciados primeiro
ANNOUNCED_VALIDATORS_RAW=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedValidators()" \
    --rpc-url "$BSC_RPC" 2>&1)

ALL_VALIDATORS=($(cast --abi-decode "getAnnouncedValidators()(address[])" "$ANNOUNCED_VALIDATORS_RAW" 2>/dev/null | grep -oE "0x[a-fA-F0-9]{40}"))

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "{"
echo "  \"data\": {"
echo "    \"storage_locations\": ["

FIRST=true
# Processar validators do ISM
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
    
    # No BSC, a função pode não existir ou ter nome diferente
    # Vamos tentar todas as variações possíveis
    
    # Tentativa 1: getAnnounceStorageLocations(address[])
    STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnounceStorageLocations(address[])" \
        "[$VALIDATOR]" \
        --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    
    # Se falhar, tentar outras funções
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        # Tentativa 2: getStorageLocations(address[])
        STORAGE_RESPONSE=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
            "getStorageLocations(address[])" \
            "[$VALIDATOR]" \
            --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    fi
    
    # Se ainda falhar, verificar eventos
    if echo "$STORAGE_RESPONSE" | grep -qi "error\|revert\|timeout"; then
        # Consultar eventos para este validator
        CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "0")
        FROM_BLOCK=$((CURRENT_BLOCK - 5000000))  # Últimos 5M blocos
        
        EVENTS=$(cast logs \
            --from-block $FROM_BLOCK \
            --to-block $CURRENT_BLOCK \
            --address "$VALIDATOR_ANNOUNCE_BSC" \
            --rpc-url "$BSC_RPC" 2>&1 | \
            grep -i "$VALIDATOR" | \
            grep -oE "s3://[^ ]+" | \
            head -1 || echo "")
        
        if [ ! -z "$EVENTS" ]; then
            echo "          \"$EVENTS\""
        fi
    else
        # Tentar decodificar resposta
        # O formato esperado é: [(address, [string])]
        STORAGE_DECODED=$(cast --abi-decode "getAnnounceStorageLocations(address[])((address,string[])[])" "$STORAGE_RESPONSE" 2>/dev/null || \
            cast --abi-decode "getStorageLocations(address[])((address,string[])[])" "$STORAGE_RESPONSE" 2>/dev/null || \
            echo "")
        
        if [ ! -z "$STORAGE_DECODED" ] && [ "$STORAGE_DECODED" != "()" ]; then
            # Extrair storage locations (s3://...)
            STORAGE_S3=$(echo "$STORAGE_DECODED" | grep -oE "s3://[^ ]+" || echo "")
            
            if [ ! -z "$STORAGE_S3" ]; then
                echo "          \"$STORAGE_S3\""
            fi
        fi
    fi
    
    echo "        ]"
    echo -n "      ]"
done

echo ""
echo "    ]"
echo "  }"
echo "}"

