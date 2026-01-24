#!/bin/bash

# Consultar exatamente como o relayer faz

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "Baseado no código do relayer:"
echo "  - Relayer usa: origin_validator_announce (chain de origem = BSC)"
echo "  - Função: get_announced_storage_locations(address[] memory validators)"
echo "  - Retorna: string[][] (array de arrays de strings)"
echo ""

# Testar função exata do contrato
echo "Testando getAnnouncedStorageLocations(address[])..."

# Converter para formato correto do cast
VALIDATORS_STR=$(printf '%s\n' "${VALIDATORS_ISM[@]}" | jq -R . | jq -s . | tr -d '\n' | sed 's/"/0x/g')

# Tentar com array
RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address[])" \
    "[$(IFS=,; echo "${VALIDATORS_ISM[*]}")]" \
    --rpc-url "$BSC_RPC" 2>&1)

echo "Resultado:"
echo "$RESULT" | head -10

if ! echo "$RESULT" | grep -qi "error\|revert"; then
    echo ""
    echo "Tentando decodificar como string[][]..."
    DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null || echo "")
    
    if [ ! -z "$DECODED" ] && [ "$DECODED" != "()" ]; then
        echo "✅ Decodificado:"
        echo "$DECODED"
    fi
fi

