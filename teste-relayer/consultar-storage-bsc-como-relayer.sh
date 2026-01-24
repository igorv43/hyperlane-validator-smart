#!/bin/bash

# Consultar storage locations no BSC usando a mesma lógica do relayer

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "Consultando como o relayer faz..."
echo "Relayer usa: get_announced_storage_locations(address[] memory validators)"
echo ""

# Converter validators para array
VALIDATORS_ARRAY="["
FIRST=true
for VALIDATOR in "${VALIDATORS_ISM[@]}"; do
    if [ "$FIRST" = false ]; then
        VALIDATORS_ARRAY+=","
    fi
    FIRST=false
    VALIDATORS_ARRAY+="$VALIDATOR"
done
VALIDATORS_ARRAY+="]"

echo "Validators: $VALIDATORS_ARRAY"
echo ""

# Consultar usando a função que aceita array
echo "Consultando get_announced_storage_locations(address[])..."
RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "get_announced_storage_locations(address[])" \
    "$VALIDATORS_ARRAY" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$RESULT" | grep -qi "error\|revert"; then
    echo "❌ Erro: $RESULT"
else
    echo "✅ Resposta obtida:"
    echo "$RESULT"
    echo ""
    
    # Tentar decodificar como string[][]
    DECODED=$(cast --abi-decode "get_announced_storage_locations(address[])(string[][])" "$RESULT" 2>/dev/null || echo "")
    
    if [ ! -z "$DECODED" ] && [ "$DECODED" != "()" ]; then
        echo "✅ Decodificado:"
        echo "$DECODED"
    else
        echo "⚠️  Não foi possível decodificar"
    fi
fi

