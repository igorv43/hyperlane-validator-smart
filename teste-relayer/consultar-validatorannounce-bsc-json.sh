#!/bin/bash

# ============================================================================
# Script: Consultar ValidatorAnnounce BSC - Saída JSON Completa
# ============================================================================

set -e

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Validators do ISM
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

# ============================================================================
# FUNÇÕES
# ============================================================================

# Consultar validators anunciados
get_announced_validators() {
    local result=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedValidators()" \
        --rpc-url "$BSC_RPC" 2>&1)
    
    if echo "$result" | grep -qi "error"; then
        echo "{\"error\": \"$result\"}"
        return 1
    fi
    
    # Decodificar
    local decoded=$(cast --abi-decode "getAnnouncedValidators()(address[])" "$result" 2>/dev/null || echo "")
    
    if [ -z "$decoded" ]; then
        echo "{\"error\": \"Failed to decode validators\"}"
        return 1
    fi
    
    # Extrair endereços
    local validators=($(echo "$decoded" | grep -oE "0x[a-fA-F0-9]{40}"))
    
    # Converter para JSON array
    local json_array="["
    for i in "${!validators[@]}"; do
        if [ $i -gt 0 ]; then
            json_array+=","
        fi
        json_array+="\"${validators[$i]}\""
    done
    json_array+="]"
    
    echo "$json_array"
}

# Consultar storage location de um validator
get_storage_location() {
    local validator="$1"
    
    local result=$(timeout 10 cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnouncedStorageLocations(address)" \
        "$validator" \
        --rpc-url "$BSC_RPC" 2>&1 || echo "TIMEOUT")
    
    if echo "$result" | grep -qi "error\|revert\|timeout"; then
        # "execution reverted" significa que não há storage location anunciada
        if echo "$result" | grep -qi "execution reverted"; then
            echo "[]"
        else
            echo "{\"error\": \"$(echo "$result" | head -1 | sed 's/"/\\"/g')\"}"
        fi
        return 0
    fi
    
    # Tentar decodificar como string[]
    local decoded=$(cast --abi-decode "getAnnouncedStorageLocations(address)(string[])" "$result" 2>/dev/null || echo "")
    
    if [ -z "$decoded" ] || [ "$decoded" == "()" ]; then
        echo "[]"
        return 0
    fi
    
    # Extrair storage locations (s3://...)
    local storage_locations=($(echo "$decoded" | grep -oE "s3://[^ ]+" || echo ""))
    
    if [ ${#storage_locations[@]} -eq 0 ]; then
        echo "[]"
        return 0
    fi
    
    # Converter para JSON array
    local json_array="["
    for i in "${!storage_locations[@]}"; do
        if [ $i -gt 0 ]; then
            json_array+=","
        fi
        json_array+="\"${storage_locations[$i]}\""
    done
    json_array+="]"
    
    echo "$json_array"
}

# ============================================================================
# INÍCIO
# ============================================================================

echo "{"
echo "  \"validatorAnnounce\": \"$VALIDATOR_ANNOUNCE_BSC\","
echo "  \"rpc\": \"$BSC_RPC\","
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"data\": {"

# Obter lista de validators
echo "    \"announcedValidators\": "
VALIDATORS_JSON=$(get_announced_validators)
if echo "$VALIDATORS_JSON" | grep -q "error"; then
    echo "$VALIDATORS_JSON"
else
    echo "$VALIDATORS_JSON"
fi
echo ","

# Obter storage locations apenas para validators do ISM e alguns exemplos
echo "    \"validatorsWithStorage\": ["

VALIDATORS_ARRAY=($(echo "$VALIDATORS_JSON" | grep -oE "0x[a-fA-F0-9]{40}"))

# Processar apenas os primeiros 10 validators + validators do ISM para não demorar muito
VALIDATORS_TO_PROCESS=("${VALIDATORS_ARRAY[@]:0:10}")
for ism_val in "${VALIDATORS_ISM[@]}"; do
    # Adicionar validators do ISM se não estiverem nos primeiros 10
    FOUND=false
    for val in "${VALIDATORS_TO_PROCESS[@]}"; do
        if [ "$(echo "$ism_val" | tr '[:upper:]' '[:lower:]')" == "$(echo "$val" | tr '[:upper:]' '[:lower:]')" ]; then
            FOUND=true
            break
        fi
    done
    if [ "$FOUND" = false ]; then
        VALIDATORS_TO_PROCESS+=("$ism_val")
    fi
done

FIRST=true
for validator in "${VALIDATORS_TO_PROCESS[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    echo "      {"
    echo "        \"validator\": \"$validator\","
    echo "        \"storageLocations\": "
    
    STORAGE_JSON=$(get_storage_location "$validator")
    echo "$STORAGE_JSON" | sed 's/^/        /'
    
    echo -n "      }"
done

echo ""
echo "    ],"
echo "    \"totalValidators\": ${#VALIDATORS_ARRAY[@]},"
echo "    \"validatorsProcessed\": ${#VALIDATORS_TO_PROCESS[@]},"

# Verificar validators do ISM especificamente
echo "    \"ismValidators\": ["

FIRST=true
for validator in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    echo "      {"
    echo "        \"validator\": \"$validator\","
    
    # Verificar se está na lista de anunciados
    IS_ANNOUNCED=false
    for announced in "${VALIDATORS_ARRAY[@]}"; do
        if [ "$(echo "$validator" | tr '[:upper:]' '[:lower:]')" == "$(echo "$announced" | tr '[:upper:]' '[:lower:]')" ]; then
            IS_ANNOUNCED=true
            break
        fi
    done
    
    echo "        \"isAnnounced\": $IS_ANNOUNCED,"
    echo "        \"storageLocations\": "
    
    if [ "$IS_ANNOUNCED" = true ]; then
        STORAGE_JSON=$(get_storage_location "$validator")
    else
        STORAGE_JSON="[]"
    fi
    echo "$STORAGE_JSON" | sed 's/^/        /'
    
    echo -n "      }"
done

echo ""
echo "    ]"

echo "  }"
echo "}"
