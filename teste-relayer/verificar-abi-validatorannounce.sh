#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

echo "Tentando obter ABI do contrato via BSCScan API..."
echo ""

# Tentar obter ABI via BSCScan API (se disponível)
BSCSCAN_API="https://api-testnet.bscscan.com/api"
CONTRACT_ABI=$(curl -s "$BSCSCAN_API?module=contract&action=getabi&address=$VALIDATOR_ANNOUNCE_BSC&apikey=YourApiKeyToken" 2>/dev/null | jq -r '.result' 2>/dev/null || echo "")

if [ ! -z "$CONTRACT_ABI" ] && [ "$CONTRACT_ABI" != "null" ] && [ "$CONTRACT_ABI" != "Contract source code not verified" ]; then
    echo "ABI obtido via BSCScan:"
    echo "$CONTRACT_ABI" | jq '.[] | select(.name | contains("Storage") or contains("storage") or contains("Announce")) | {name: .name, inputs: .inputs, outputs: .outputs}' 2>/dev/null | head -50
else
    echo "Não foi possível obter ABI via BSCScan"
    echo ""
    echo "Tentando descobrir função via cast:"
    echo ""
    
    # Listar funções conhecidas do ValidatorAnnounce
    echo "Funções conhecidas do ValidatorAnnounce:"
    echo "  - getAnnouncedValidators() returns (address[])"
    echo "  - getAnnouncedStorageLocations(address) returns (string[])"
    echo "  - getAnnounceStorageLocations(address[]) returns (tuple(address,string[])[])?"
    echo "  - announce(address,string) - para anunciar"
    echo ""
    
    # Testar se há função que aceita array
    VALIDATOR="0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    
    echo "Testando getAnnounceStorageLocations(address[]):"
    cast call "$VALIDATOR_ANNOUNCE_BSC" \
        "getAnnounceStorageLocations(address[])" \
        "[$VALIDATOR]" \
        --rpc-url "$BSC_RPC" 2>&1 | head -3
fi

