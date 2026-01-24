#!/bin/bash

# ============================================================================
# Script: Consultar Eventos do ValidatorAnnounce BSC para Obter Storage Locations
# ============================================================================

set -e

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Obter bloco atual
CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "0")
FROM_BLOCK=$((CURRENT_BLOCK - 100000))  # Últimos ~100k blocos

echo "Consultando eventos do ValidatorAnnounce..."
echo "Contrato: $VALIDATOR_ANNOUNCE_BSC"
echo "RPC: $BSC_RPC"
echo "Bloco atual: $CURRENT_BLOCK"
echo "Consultando desde bloco: $FROM_BLOCK"
echo ""

# Consultar eventos ValidatorAnnounce
# Assinatura do evento: ValidatorAnnounce(address indexed validator, string storageLocation, string)
EVENT_SIG="ValidatorAnnounce(address,string,string)"

echo "Consultando eventos ValidatorAnnounce..."
cast logs \
    --from-block $FROM_BLOCK \
    --to-block $CURRENT_BLOCK \
    --address "$VALIDATOR_ANNOUNCE_BSC" \
    --rpc-url "$BSC_RPC" 2>&1 | \
    grep -i "validatorannounce\|storage\|s3://" | \
    head -100

