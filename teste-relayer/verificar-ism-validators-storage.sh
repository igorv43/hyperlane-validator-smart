#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

# Validators do ISM (Terra Classic para domain 97)
VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR STORAGE LOCATIONS DOS VALIDATORS DO ISM (BSC)                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Validators do ISM (Terra Classic para domain 97):"
for VAL in "${VALIDATORS_ISM[@]}"; do
    echo "  • $VAL"
done
echo ""

# Consultar usando a função correta: getAnnouncedStorageLocations(address[])
echo "🔍 Consultando getAnnouncedStorageLocations(address[]) no BSC..."
echo ""

RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address[])" \
    "[$(IFS=,; echo "${VALIDATORS_ISM[*]}")]" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$RESULT" | grep -qi "error\|revert"; then
    echo "❌ Erro ao consultar:"
    echo "$RESULT"
    exit 1
fi

# Decodificar como string[][]
DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null)

if [ -z "$DECODED" ] || [ "$DECODED" == "()" ]; then
    echo "❌ Não foi possível decodificar a resposta"
    exit 1
fi

# Processar resultado
echo "✅ Resposta decodificada:"
echo "$DECODED"
echo ""

# Criar JSON estruturado
echo "📊 Resultado estruturado:"
echo "{"
echo "  \"validatorAnnounce\": \"$VALIDATOR_ANNOUNCE_BSC\","
echo "  \"rpc\": \"$BSC_RPC\","
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
echo "  \"method\": \"getAnnouncedStorageLocations(address[]) - como relayer\","
echo "  \"data\": {"
echo "    \"storage_locations\": ["

FIRST=true
for ((i=0; i<${#VALIDATORS_ISM[@]}; i++)); do
    VALIDATOR="${VALIDATORS_ISM[$i]}"
    VALIDATOR_CLEAN=$(echo "$VALIDIDATOR" | sed 's/^0x//')
    
    # Extrair storage locations para este validator
    STORAGE_JSON=$(echo "$DECODED" | jq -r ".[$i] // []" 2>/dev/null || echo "[]")
    
    if [ "$FIRST" = false ]; then
        echo ","
    fi
    FIRST=false
    
    echo "      ["
    echo "        \"$VALIDATOR_CLEAN\","
    echo "        $STORAGE_JSON"
    echo -n "      ]"
done

echo ""
echo "    ]"
echo "  }"
echo "}"

