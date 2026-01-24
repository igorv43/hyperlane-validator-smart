#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"
VALIDATOR="0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"

echo "Testando TODAS as funções possíveis do ValidatorAnnounce..."
echo ""

# Lista de funções para testar
FUNCTIONS=(
    "getAnnounceStorageLocations(address[])"
    "getAnnouncedStorageLocations(address)"
    "getStorageLocations(address[])"
    "getStorageLocation(address)"
    "announcedStorageLocations(address)"
    "storageLocations(address)"
    "getAnnouncedStorageLocation(address)"
)

for FUNC in "${FUNCTIONS[@]}"; do
    echo "Testando: $FUNC"
    RESULT=$(timeout 5 cast call "$VALIDATOR_ANNOUNCE_BSC" "$FUNC" "$VALIDATOR" --rpc-url "$BSC_RPC" 2>&1 | head -3)
    if ! echo "$RESULT" | grep -qi "error\|revert"; then
        echo "  ✅ SUCESSO! Resposta:"
        echo "$RESULT" | head -5
        echo ""
        break
    else
        echo "  ❌ Erro ou revert"
    fi
    echo ""
done

