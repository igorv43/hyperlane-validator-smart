#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"
VALIDATOR="0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"

echo "Testando diferentes funções do ValidatorAnnounce..."
echo ""

# Função 1: getAnnouncedStorageLocations
echo "1. getAnnouncedStorageLocations(address):"
cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address)" \
    "$VALIDATOR" \
    --rpc-url "$BSC_RPC" 2>&1 | head -3
echo ""

# Tentar outras variações possíveis
echo "2. Tentando outras funções possíveis..."

# Verificar se há função para obter storage location de forma diferente
echo "   Testando getStorageLocation(address):"
cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getStorageLocation(address)" \
    "$VALIDATOR" \
    --rpc-url "$BSC_RPC" 2>&1 | head -3
echo ""

echo "3. Consultando eventos ValidatorAnnounce para este validator:"
CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "0")
FROM_BLOCK=$((CURRENT_BLOCK - 1000000))

cast logs \
    --from-block $FROM_BLOCK \
    --to-block $CURRENT_BLOCK \
    --address "$VALIDATOR_ANNOUNCE_BSC" \
    --rpc-url "$BSC_RPC" 2>&1 | \
    grep -i "$VALIDATOR" | \
    head -10

