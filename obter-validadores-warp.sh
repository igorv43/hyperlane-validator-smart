#!/bin/bash

echo "========================================="
echo "🔍 OBTENDO VALIDADORES DO WARP ROUTE"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
SEPOLIA_RPC="https://1rpc.io/sepolia"
API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"

echo "📍 Contrato Warp Route:"
echo "   $WARP_ROUTE"
echo "   https://sepolia.etherscan.io/address/$WARP_ROUTE"
echo ""

echo "1️⃣ Obtendo ISM do Warp Route..."
WARP_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -z "$WARP_ISM" ] || [ "$WARP_ISM" = "0x" ] || [ "$WARP_ISM" = "0x0000000000000000000000000000000000000000" ]; then
    echo "   ❌ Não foi possível obter o ISM"
    exit 1
fi

echo "   ✅ ISM: $WARP_ISM"
echo "   🔗 https://sepolia.etherscan.io/address/$WARP_ISM"
echo ""

echo "2️⃣ Verificando tipo de ISM..."
echo ""

# Verificar se é DomainRoutingISM
ISM_FOR_TERRA=$(cast call "$WARP_ISM" "module(uint32)(address)" "1325" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM_FOR_TERRA" != "0x" ]; then
    echo "   ✅ É DomainRoutingISM"
    echo "   📍 ISM para Terra Classic (1325): $ISM_FOR_TERRA"
    ACTUAL_ISM="$ISM_FOR_TERRA"
else
    echo "   ⚠️  Não é DomainRoutingISM, usando ISM principal"
    ACTUAL_ISM="$WARP_ISM"
fi

echo ""
echo "3️⃣ Tentando obter validadores do ISM: $ACTUAL_ISM"
echo ""

# Método 1: validators() - retorna array
echo "   Método 1: validators()..."
VALIDATORS_ARRAY=$(cast call "$ACTUAL_ISM" "validators()(address[])" --rpc-url "$SEPOLIA_RPC" 2>/dev/null)

if [ -n "$VALIDATORS_ARRAY" ] && [ "$VALIDATORS_ARRAY" != "0x" ] && [ "$VALIDATORS_ARRAY" != "" ]; then
    echo "   ✅ Validadores encontrados via validators():"
    echo "$VALIDATORS_ARRAY" | sed 's/^/      /'
    echo ""
    exit 0
fi

# Método 2: validatorCount() e validatorAt()
echo "   Método 2: validatorCount() e validatorAt()..."
VALIDATOR_COUNT=$(cast call "$ACTUAL_ISM" "validatorCount()(uint256)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -n "$VALIDATOR_COUNT" ] && [ "$VALIDATOR_COUNT" != "0" ] && [ "$VALIDATOR_COUNT" != "0x0" ] && [ "$VALIDATOR_COUNT" != "0x" ]; then
    COUNT_DEC=$(printf "%d" "$VALIDATOR_COUNT" 2>/dev/null || echo "0")
    
    if [ "$COUNT_DEC" -gt 0 ] && [ "$COUNT_DEC" -lt 100 ]; then
        echo "   ✅ Número de validadores: $COUNT_DEC"
        echo ""
        echo "   Validadores:"
        VALIDATORS=()
        for i in $(seq 0 $((COUNT_DEC - 1))); do
            VAL=$(cast call "$ACTUAL_ISM" "validatorAt(uint256)(address)" "$i" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
            if [ -n "$VAL" ] && [ "$VAL" != "0x" ]; then
                VALIDATORS+=("$VAL")
                echo "      [$((i+1))] $VAL"
            fi
        done
        echo ""
        
        # Verificar threshold
        THRESHOLD=$(cast call "$ACTUAL_ISM" "threshold()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
        if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" != "0x" ]; then
            THRESHOLD_DEC=$(printf "%d" "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
            echo "   ✅ Threshold: $THRESHOLD_DEC de $COUNT_DEC"
        fi
        exit 0
    fi
fi

# Método 3: Tentar via Etherscan API
echo "   Método 3: Verificando via Etherscan API..."
echo ""

# Buscar eventos ou storage slots que possam conter validadores
echo "   Buscando eventos relacionados a validadores..."
EVENTS=$(curl -s "https://api-sepolia.etherscan.io/api?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$ACTUAL_ISM&apikey=$API_KEY" 2>/dev/null)

if echo "$EVENTS" | jq -e '.status == "1"' >/dev/null 2>&1; then
    echo "   ✅ Eventos encontrados no Etherscan"
    echo "   (Verifique manualmente: https://sepolia.etherscan.io/address/$ACTUAL_ISM#events)"
else
    echo "   ⚠️  Não foi possível obter eventos via API"
fi

echo ""
echo "4️⃣ Verificando código do contrato no Etherscan..."
echo "   https://sepolia.etherscan.io/address/$ACTUAL_ISM#code"
echo ""

# Tentar ler storage slots comuns onde validadores podem estar armazenados
echo "5️⃣ Tentando ler storage slots comuns..."
echo ""

# Storage slot 0 geralmente contém o primeiro elemento de um array
SLOT0=$(cast storage "$ACTUAL_ISM" 0 --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
if [ -n "$SLOT0" ] && [ "$SLOT0" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "   Storage slot 0: $SLOT0"
    # Tentar interpretar como endereço
    ADDR=$(cast --to-checksum-address "0x${SLOT0:26:40}" 2>/dev/null)
    if [ -n "$ADDR" ] && [ "$ADDR" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   Possível endereço: $ADDR"
    fi
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "💡 Se não foi possível obter validadores automaticamente:"
echo "   1. Verifique o código do contrato no Etherscan"
echo "   2. O ISM pode ser de um tipo diferente (MessageIdMultisig, etc.)"
echo "   3. Os validadores podem estar em storage slots específicos"
echo ""

