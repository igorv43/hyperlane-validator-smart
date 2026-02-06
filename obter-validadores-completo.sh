#!/bin/bash

WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
SEPOLIA_RPC="https://1rpc.io/sepolia"

echo "========================================="
echo "🔍 OBTENDO VALIDADORES - MÉTODOS COMPLETOS"
echo "========================================="
echo ""

echo "📍 ISM: $WARP_ISM"
echo ""

# Lista de métodos possíveis para obter validadores
METHODS=(
    "validators()(address[])"
    "validators()(address[3])"
    "validators()(address[5])"
    "getValidators()(address[])"
    "getValidators()(address[3])"
    "validatorCount()(uint256)"
    "validatorCount()(uint8)"
    "count()(uint256)"
    "threshold()(uint8)"
)

echo "1️⃣ Tentando diferentes métodos..."
echo ""

for METHOD in "${METHODS[@]}"; do
    FUNC_NAME=$(echo "$METHOD" | cut -d'(' -f1)
    RESULT=$(cast call "$WARP_ISM" "$METHOD" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$RESULT" ] && [ "$RESULT" != "0x" ] && [ "$RESULT" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   ✅ $FUNC_NAME: $RESULT"
        
        # Se for validatorCount, tentar obter validadores individuais
        if [[ "$FUNC_NAME" == "validatorCount" ]] || [[ "$FUNC_NAME" == "count" ]]; then
            COUNT=$(printf "%d" "$RESULT" 2>/dev/null || echo "0")
            if [ "$COUNT" -gt 0 ] && [ "$COUNT" -lt 20 ]; then
                echo "      Tentando obter $COUNT validadores..."
                for i in $(seq 0 $((COUNT - 1))); do
                    VAL=$(cast call "$WARP_ISM" "validatorAt(uint256)(address)" "$i" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
                    if [ -n "$VAL" ] && [ "$VAL" != "0x" ]; then
                        echo "         [$((i+1))] $VAL"
                    fi
                done
            fi
        fi
    fi
done

echo ""
echo "2️⃣ Tentando métodos específicos de MessageIdMultisig..."
echo ""

# MessageIdMultisig pode ter métodos diferentes
MSG_ID_METHODS=(
    "validators()(address[])"
    "validatorCount()(uint256)"
    "threshold()(uint8)"
)

for METHOD in "${MSG_ID_METHODS[@]}"; do
    FUNC_NAME=$(echo "$METHOD" | cut -d'(' -f1)
    RESULT=$(cast call "$WARP_ISM" "$METHOD" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$RESULT" ] && [ "$RESULT" != "0x" ] && [ "$RESULT" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   ✅ $FUNC_NAME: $RESULT"
    fi
done

echo ""
echo "3️⃣ Verificando storage slots (MessageIdMultisig armazena em slots específicos)..."
echo ""

# MessageIdMultisig geralmente armazena:
# - slot 0: validatorCount
# - slot 1: threshold  
# - slots 2+: validators (um por slot)

SLOT0=$(cast storage "$WARP_ISM" 0 --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
if [ -n "$SLOT0" ]; then
    COUNT_FROM_SLOT=$(printf "%d" "$SLOT0" 2>/dev/null || echo "0")
    echo "   Storage slot 0 (possível validatorCount): $SLOT0 = $COUNT_FROM_SLOT"
    
    if [ "$COUNT_FROM_SLOT" -gt 0 ] && [ "$COUNT_FROM_SLOT" -lt 20 ]; then
        echo ""
        echo "   Validadores nos storage slots:"
        for i in $(seq 2 $((COUNT_FROM_SLOT + 1))); do
            SLOT_VAL=$(cast storage "$WARP_ISM" "$i" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
            if [ -n "$SLOT_VAL" ] && [ "$SLOT_VAL" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
                # Extrair endereço (últimos 20 bytes = 40 hex chars)
                ADDR="0x${SLOT_VAL:26:40}"
                ADDR_CHECKSUM=$(cast --to-checksum-address "$ADDR" 2>/dev/null)
                if [ -n "$ADDR_CHECKSUM" ] && [ "$ADDR_CHECKSUM" != "0x0000000000000000000000000000000000000000" ]; then
                    echo "      Slot $i: $ADDR_CHECKSUM"
                fi
            fi
        done
    fi
fi

SLOT1=$(cast storage "$WARP_ISM" 1 --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
if [ -n "$SLOT1" ]; then
    THRESHOLD_FROM_SLOT=$(printf "%d" "$SLOT1" 2>/dev/null || echo "0")
    echo "   Storage slot 1 (possível threshold): $SLOT1 = $THRESHOLD_FROM_SLOT"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="

