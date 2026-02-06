#!/bin/bash

echo "========================================="
echo "🔍 VERIFICAÇÃO CORRETA DO ISM"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
SEPOLIA_RPC="https://1rpc.io/sepolia"

# ISM encontrado nos logs do relayer
ISM_FROM_LOGS="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3559f29d0278b001ed0421249"

# ISM do Warp Route (obtido anteriormente)
WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"

echo "1️⃣ ISM encontrado nos logs do relayer:"
echo "   $ISM_FROM_LOGS"
echo "   (para mensagens BSC → Terra Classic)"
echo ""

echo "2️⃣ ISM do Warp Route (Sepolia):"
echo "   $WARP_ISM"
echo ""

# Verificar se são iguais
if [ "$(echo "$ISM_FROM_LOGS" | tr '[:upper:]' '[:lower:]')" = "$(echo "$WARP_ISM" | tr '[:upper:]' '[:lower:]')" ]; then
    echo "   ✅ São o mesmo ISM!"
else
    echo "   ⚠️  São ISMs diferentes"
    echo "   → O ISM dos logs pode ser para outra rota (BSC → Terra)"
    echo "   → Precisamos verificar o ISM específico para Sepolia → Terra"
fi

echo ""
echo "3️⃣ Verificando ISM do Warp Route para Sepolia → Terra Classic..."
echo ""

# Obter ISM do Warp Route
WARP_ISM_CHECK=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -n "$WARP_ISM_CHECK" ] && [ "$WARP_ISM_CHECK" != "0x" ]; then
    echo "   ✅ ISM do Warp Route: $WARP_ISM_CHECK"
    echo ""
    
    # Verificar se é DomainRoutingISM
    echo "4️⃣ Verificando se é DomainRoutingISM..."
    ISM_FOR_TERRA=$(cast call "$WARP_ISM_CHECK" "module(uint32)(address)" "1325" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM_FOR_TERRA" != "0x" ]; then
        echo "   ✅ É DomainRoutingISM"
        echo "   📍 ISM para Terra Classic (1325): $ISM_FOR_TERRA"
        ACTUAL_ISM="$ISM_FOR_TERRA"
    else
        echo "   ⚠️  Não é DomainRoutingISM ou não encontrado"
        ACTUAL_ISM="$WARP_ISM_CHECK"
    fi
    
    echo ""
    echo "5️⃣ Verificando validadores no ISM: $ACTUAL_ISM"
    echo ""
    
    # Tentar diferentes métodos para obter validadores
    # Método 1: validators()
    VALIDATORS1=$(cast call "$ACTUAL_ISM" "validators()(address[])" --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
    
    # Método 2: validatorCount() e validatorAt()
    VALIDATOR_COUNT=$(cast call "$ACTUAL_ISM" "validatorCount()(uint256)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$VALIDATORS1" ] && [ "$VALIDATORS1" != "0x" ] && [ "$VALIDATORS1" != "" ]; then
        echo "   ✅ Validadores encontrados (método validators()):"
        echo "$VALIDATORS1" | sed 's/^/      /'
    elif [ -n "$VALIDATOR_COUNT" ] && [ "$VALIDATOR_COUNT" != "0" ] && [ "$VALIDATOR_COUNT" != "0x0" ] && [ "$VALIDATOR_COUNT" != "0x" ]; then
        COUNT_DEC=$(printf "%d" "$VALIDATOR_COUNT" 2>/dev/null || echo "$VALIDATOR_COUNT")
        echo "   ✅ Número de validadores: $COUNT_DEC"
        echo "   Validadores:"
        for i in $(seq 0 $((COUNT_DEC - 1))); do
            VAL=$(cast call "$ACTUAL_ISM" "validatorAt(uint256)(address)" "$i" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
            if [ -n "$VAL" ] && [ "$VAL" != "0x" ]; then
                echo "      [$((i+1))] $VAL"
            fi
        done
    else
        echo "   ⚠️  Não foi possível obter validadores diretamente"
        echo "   ISM pode ser de outro tipo"
        echo ""
        echo "   Verificando no Etherscan:"
        echo "   https://sepolia.etherscan.io/address/$ACTUAL_ISM#code"
    fi
    
    # Verificar threshold
    THRESHOLD=$(cast call "$ACTUAL_ISM" "threshold()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" != "0x" ]; then
        THRESHOLD_DEC=$(printf "%d" "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
        echo ""
        echo "   ✅ Threshold: $THRESHOLD_DEC"
    fi
else
    echo "   ❌ Não foi possível obter o ISM do Warp Route"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "💡 NOTA:"
echo "   Os validadores que aparecem nos logs (0x242d8a..., etc.)"
echo "   são do ISM usado para mensagens BSC → Terra Classic"
echo "   Para mensagens Sepolia → Terra Classic, precisamos verificar"
echo "   o ISM específico do Warp Route do Sepolia"

