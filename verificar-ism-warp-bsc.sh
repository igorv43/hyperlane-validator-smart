#!/bin/bash

echo "========================================="
echo "🔍 CONFIGURAÇÃO DO ISM DO WARP ROUTE BSC"
echo "========================================="
echo ""

WARP_BSC="0x2144Be4477202ba2d50c9A8be3181241878cf7D8"
BSC_RPC="https://bsc-testnet.publicnode.com"
TERRA_DOMAIN="1325"

echo "📍 Warp Route BSC: $WARP_BSC"
echo "   https://testnet.bscscan.com/address/$WARP_BSC"
echo ""

echo "1️⃣ Obtendo ISM do Warp Route..."
echo ""

ISM_BSC=$(cast call "$WARP_BSC" "interchainSecurityModule()(address)" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')

if [ -z "$ISM_BSC" ] || [ "$ISM_BSC" = "0x" ] || [ "$ISM_BSC" = "0x0000000000000000000000000000000000000000" ]; then
    echo "   ❌ Não foi possível obter ISM do Warp Route"
    exit 1
fi

ISM_BSC_CHECKSUM=$(cast --to-checksum-address "$ISM_BSC" 2>/dev/null)

echo "   ✅ ISM do Warp Route: $ISM_BSC_CHECKSUM"
echo "   https://testnet.bscscan.com/address/$ISM_BSC_CHECKSUM"
echo ""

echo "2️⃣ Verificando tipo do ISM..."
echo ""

MODULE_TYPE=$(cast call "$ISM_BSC" "moduleType()(uint8)" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   Module Type: $TYPE_DEC"
case "$TYPE_DEC" in
    1) 
        echo "   → ROUTING (DomainRoutingISM) ✅"
        echo ""
        echo "3️⃣ Verificando configuração para Terra Classic..."
        echo ""
        
        ISM_FOR_TERRA=$(cast call "$ISM_BSC" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')
        
        if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM_FOR_TERRA" != "0x" ]; then
            ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
            echo "   ✅ ISM para Terra Classic (1325): $ISM_FOR_TERRA_CHECKSUM"
            echo "   https://testnet.bscscan.com/address/$ISM_FOR_TERRA_CHECKSUM"
            echo ""
            
            echo "4️⃣ Obtendo validadores do ISM do Terra Classic..."
            echo ""
            
            VALIDATORS_RESULT=$(cast call "$ISM_FOR_TERRA" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$BSC_RPC" 2>/dev/null)
            
            if [ -n "$VALIDATORS_RESULT" ] && [ "$VALIDATORS_RESULT" != "0x" ] && ! echo "$VALIDATORS_RESULT" | grep -qi "error\|revert"; then
                echo "   ✅ Validadores obtidos!"
                echo ""
                
                # Extrair validadores
                VALIDATORS_LIST=()
                while IFS= read -r addr; do
                    if [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                        CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
                        if [ -n "$CHECKSUM" ]; then
                            VALIDATORS_LIST+=("$CHECKSUM")
                        fi
                    fi
                done < <(echo "$VALIDATORS_RESULT" | grep -oE "0x[a-fA-F0-9]{40}")
                
                # Extrair threshold
                THRESHOLD_VAL=$(echo "$VALIDATORS_RESULT" | grep -oE "[0-9]+" | tail -1)
                
                echo "   📋 Validadores do ISM do Terra Classic:"
                for i in "${!VALIDATORS_LIST[@]}"; do
                    echo "      [$((i+1))] ${VALIDATORS_LIST[$i]}"
                done
                echo ""
                
                if [ -n "$THRESHOLD_VAL" ]; then
                    echo "   ✅ Threshold: $THRESHOLD_VAL de ${#VALIDATORS_LIST[@]}"
                fi
            else
                echo "   ⚠️  Não foi possível obter validadores"
            echo "   Tentando método alternativo..."
                
                # Tentar validatorCount
                VALIDATOR_COUNT=$(cast call "$ISM_FOR_TERRA" "validatorCount()(uint256)" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')
                if [ -n "$VALIDATOR_COUNT" ] && [ "$VALIDATOR_COUNT" != "0" ] && [ "$VALIDATOR_COUNT" != "0x0" ]; then
                    COUNT_DEC=$(printf "%d" "$VALIDATOR_COUNT" 2>/dev/null || echo "0")
                    echo "   Número de validadores: $COUNT_DEC"
                fi
            fi
        else
            echo "   ❌ NÃO configurado para Terra Classic"
            echo "   ⚠️  DomainRoutingISM existe mas não tem module(1325)"
        fi
        ;;
    5) 
        echo "   → MESSAGE_ID_MULTISIG ❌"
        echo ""
        echo "3️⃣ Obtendo validadores do ISM..."
        echo ""
        
        VALIDATORS_RESULT=$(cast call "$ISM_BSC" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$BSC_RPC" 2>/dev/null)
        
        if [ -n "$VALIDATORS_RESULT" ] && [ "$VALIDATORS_RESULT" != "0x" ] && ! echo "$VALIDATORS_RESULT" | grep -qi "error\|revert"; then
            echo "   ✅ Validadores obtidos!"
            echo ""
            
            # Extrair validadores
            VALIDATORS_LIST=()
            while IFS= read -r addr; do
                if [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                    CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
                    if [ -n "$CHECKSUM" ]; then
                        VALIDATORS_LIST+=("$CHECKSUM")
                    fi
                fi
            done < <(echo "$VALIDATORS_RESULT" | grep -oE "0x[a-fA-F0-9]{40}")
            
            # Extrair threshold
            THRESHOLD_VAL=$(echo "$VALIDATORS_RESULT" | grep -oE "[0-9]+" | tail -1)
            
            echo "   📋 Validadores:"
            for i in "${!VALIDATORS_LIST[@]}"; do
                echo "      [$((i+1))] ${VALIDATORS_LIST[$i]}"
            done
            echo ""
            
            if [ -n "$THRESHOLD_VAL" ]; then
                echo "   ✅ Threshold: $THRESHOLD_VAL de ${#VALIDATORS_LIST[@]}"
            fi
        fi
        ;;
    *) 
        echo "   → Tipo desconhecido ($TYPE_DEC)"
        ;;
esac

echo ""
echo "========================================="
echo "📊 RESUMO"
echo "========================================="
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "✅ ISM = DomainRoutingISM (CORRETO)"
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        echo "✅ DomainRoutingISM.module(1325) = ISM do Terra Classic"
        echo "✅ Configuração está CORRETA (como no Solana)"
    else
        echo "❌ DomainRoutingISM.module(1325) NÃO configurado"
        echo "⚠️  Precisa configurar para Terra Classic"
    fi
elif [ "$TYPE_DEC" = "5" ]; then
    echo "❌ ISM = MESSAGE_ID_MULTISIG (INCORRETO)"
    echo "⚠️  DEVERIA ser DomainRoutingISM (tipo 1)"
    echo "📝 Precisa reconfigurar como no Solana"
else
    echo "⚠️  Tipo desconhecido: $TYPE_DEC"
fi

echo ""
echo "========================================="
echo "💡 COMPARAÇÃO COM SOLANA"
echo "========================================="
echo ""
echo "✅ Solana (funcionando):"
echo "   ISM = DomainRoutingISM"
echo "   DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo ""
echo "📊 BSC (atual):"
if [ "$TYPE_DEC" = "1" ]; then
    echo "   ISM = DomainRoutingISM ✅"
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   DomainRoutingISM.module(1325) = ISM do Terra Classic ✅"
        echo "   Status: ✅ Configurado corretamente"
    else
        echo "   DomainRoutingISM.module(1325) = NÃO CONFIGURADO ❌"
        echo "   Status: ⚠️  Precisa configurar Terra Classic"
    fi
else
    echo "   ISM = MESSAGE_ID_MULTISIG ❌"
    echo "   Status: ❌ Precisa reconfigurar"
fi
echo ""

