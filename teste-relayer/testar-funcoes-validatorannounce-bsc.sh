#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"
VALIDATOR="0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"

echo "Testando diferentes assinaturas de função..."
echo ""

# Função 1: getAnnounceStorageLocations(address[])
echo "1. getAnnounceStorageLocations(address[]):"
cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnounceStorageLocations(address[])" \
    "[$VALIDATOR]" \
    --rpc-url "$BSC_RPC" 2>&1 | head -5
echo ""

# Função 2: getAnnounceStorageLocations(address[],uint32)
echo "2. getAnnounceStorageLocations(address[],uint32):"
cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnounceStorageLocations(address[],uint32)" \
    "[$VALIDATOR]" "97" \
    --rpc-url "$BSC_RPC" 2>&1 | head -5
echo ""

# Função 3: getStorageLocations(address[])
echo "3. getStorageLocations(address[]):"
cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getStorageLocations(address[])" \
    "[$VALIDATOR]" \
    --rpc-url "$BSC_RPC" 2>&1 | head -5
echo ""

# Função 4: getAnnouncedStorageLocations(address) - já testamos, mas vamos ver o resultado completo
echo "4. getAnnouncedStorageLocations(address) - resultado completo:"
cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address)" \
    "$VALIDATOR" \
    --rpc-url "$BSC_RPC" 2>&1

