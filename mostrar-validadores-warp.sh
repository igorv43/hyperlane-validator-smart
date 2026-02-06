#!/bin/bash

echo "========================================="
echo "📋 VALIDADORES DO WARP ROUTE - SEPOLIA"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
SEPOLIA_RPC="https://1rpc.io/sepolia"

echo "📍 Contrato Warp Route:"
echo "   $WARP_ROUTE"
echo "   https://sepolia.etherscan.io/address/$WARP_ROUTE"
echo ""

echo "📍 ISM do Warp Route:"
echo "   $WARP_ISM"
echo "   https://sepolia.etherscan.io/address/$WARP_ISM"
echo ""

echo "🔍 Tentando obter validadores..."
echo ""

# Tentar método final: usar cast com ABI específico
echo "Método 1: Tentando validators() com cast..."
RESULT1=$(cast call "$WARP_ISM" "validators()(address[])" --rpc-url "$SEPOLIA_RPC" 2>&1)

if echo "$RESULT1" | grep -q "0x" && ! echo "$RESULT1" | grep -qi "error\|revert\|invalid"; then
    echo "   ✅ Resultado:"
    echo "$RESULT1" | sed 's/^/      /'
    echo ""
    echo "   Validadores extraídos:"
    # Tentar extrair endereços do resultado
    echo "$RESULT1" | grep -oE "0x[a-fA-F0-9]{40}" | while read addr; do
        echo "      - $addr"
    done
    exit 0
fi

echo "Método 2: Tentando validatorCount()..."
COUNT=$(cast call "$WARP_ISM" "validatorCount()(uint256)" --rpc-url "$SEPOLIA_RPC" 2>&1 | grep -oE "[0-9]+" | head -1)

if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ] && [ "$COUNT" -lt 20 ]; then
    echo "   ✅ Número de validadores: $COUNT"
    echo ""
    echo "   Obtendo validadores individuais..."
    for i in $(seq 0 $((COUNT - 1))); do
        VAL=$(cast call "$WARP_ISM" "validatorAt(uint256)(address)" "$i" --rpc-url "$SEPOLIA_RPC" 2>&1 | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
        if [ -n "$VAL" ]; then
            echo "      [$((i+1))] $VAL"
        fi
    done
    exit 0
fi

echo ""
echo "❌ Não foi possível obter validadores automaticamente"
echo ""
echo "========================================="
echo "📝 INSTRUÇÕES PARA OBTER MANUALMENTE"
echo "========================================="
echo ""
echo "1. Acesse o Etherscan do ISM:"
echo "   https://sepolia.etherscan.io/address/$WARP_ISM#readContract"
echo ""
echo "2. Na seção 'Read Contract', procure e execute:"
echo ""
echo "   a) validatorCount() → para saber quantos validadores há"
echo "   b) validatorAt(0), validatorAt(1), validatorAt(2)... → para cada validador"
echo "   c) OU validators() → se disponível, retorna array completo"
echo "   d) threshold() → para saber quantos assinaturas são necessárias"
echo ""
echo "3. Alternativamente, verifique os storage slots:"
echo "   https://sepolia.etherscan.io/address/$WARP_ISM#readContract"
echo "   - Slot 0: pode conter validatorCount"
echo "   - Slots 2+: podem conter endereços dos validadores"
echo ""
echo "4. Depois de obter os validadores, verifique se eles estão anunciados:"
echo "   ./analisar-validadores-rpc.sh"
echo ""
echo "========================================="

