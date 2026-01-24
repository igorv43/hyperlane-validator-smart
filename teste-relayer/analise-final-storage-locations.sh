#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║         ANÁLISE FINAL: STORAGE LOCATIONS DOS VALIDATORS DO ISM           ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Consultar storage locations
RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address[])" \
    "[$(IFS=,; echo "${VALIDATORS_ISM[*]}")]" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$RESULT" | grep -qi "error\|revert"; then
    echo "❌ Erro: $RESULT"
    exit 1
fi

DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null)

echo "📊 RESULTADO:"
echo ""
echo "Validators do ISM e suas storage locations:"
echo ""

for ((i=0; i<${#VALIDATORS_ISM[@]}; i++)); do
    VALIDATOR="${VALIDATORS_ISM[$i]}"
    STORAGE_JSON=$(echo "$DECODED" | jq -r ".[$i] // []" 2>/dev/null || echo "[]")
    STORAGE_COUNT=$(echo "$STORAGE_JSON" | jq 'length' 2>/dev/null || echo "0")
    
    echo "  Validator $((i+1)): $VALIDATOR"
    if [ "$STORAGE_COUNT" -gt 0 ]; then
        echo "    ✅ Storage locations encontradas: $STORAGE_COUNT"
        echo "$STORAGE_JSON" | jq -r '.[]' | sed 's/^/      - /'
    else
        echo "    ❌ NENHUMA storage location encontrada"
    fi
    echo ""
done

# Criar JSON final
FINAL_JSON=$(jq -n \
    --arg va "$VALIDATOR_ANNOUNCE_BSC" \
    --arg rpc "$BSC_RPC" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --argjson validators "$(jq -n '$ARGS.positional' --args "${VALIDATORS_ISM[@]}")" \
    --argjson decoded "$(echo "$DECODED" | jq '.')" \
    '{
        validatorAnnounce: $va,
        rpc: $rpc,
        timestamp: $timestamp,
        method: "getAnnouncedStorageLocations(address[]) - como relayer",
        data: {
            storage_locations: [
                range(0; $validators | length) as $i |
                [
                    ($validators[$i] | ltrimstr("0x")),
                    ($decoded[$i] // [])
                ]
            ]
        }
    }')

echo "$FINAL_JSON" | jq '.' > resultado-final-ism-storage.json
echo "$FINAL_JSON" | jq '.'

echo ""
echo "✅ Resultado salvo em: resultado-final-ism-storage.json"

