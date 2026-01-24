#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

CURRENT_BLOCK=$(cast block-number --rpc-url "$BSC_RPC" 2>/dev/null || echo "0")
FROM_BLOCK=$((CURRENT_BLOCK - 2000000))  # Últimos 2M blocos

echo "Consultando TODOS os eventos do ValidatorAnnounce..."
echo "Contrato: $VALIDATOR_ANNOUNCE_BSC"
echo "Blocos: $FROM_BLOCK até $CURRENT_BLOCK"
echo ""

# Consultar todos os eventos do ValidatorAnnounce
ALL_EVENTS=$(cast logs \
    --from-block $FROM_BLOCK \
    --to-block $CURRENT_BLOCK \
    --address "$VALIDATOR_ANNOUNCE_BSC" \
    --rpc-url "$BSC_RPC" 2>&1)

echo "Total de eventos encontrados: $(echo "$ALL_EVENTS" | wc -l)"
echo ""

# Procurar por storage locations (s3://)
echo "Procurando por storage locations (s3://) nos eventos:"
echo "$ALL_EVENTS" | grep -i "s3://" | head -20

echo ""
echo "Procurando por validators do ISM nos eventos:"
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    echo "  Validator: $VALIDATOR"
    echo "$ALL_EVENTS" | grep -i "$VALIDATOR" | head -5
    echo ""
done

