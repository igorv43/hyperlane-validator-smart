#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO ISM DO WARP - DOMAIN ROUTING"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
TERRA_DOMAIN="1325"
RPC="https://sepolia.drpc.org"

echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM do Warp: $WARP_ISM"
echo "📍 Domain Terra Classic: $TERRA_DOMAIN"
echo ""

echo "1️⃣ Verificando se o ISM é DomainRoutingISM..."
echo ""

# Verificar se é DomainRoutingISM tentando obter o ISM para o domain 1325
ISM_FOR_TERRA=$(cast call "$WARP_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')

if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM_FOR_TERRA" != "0x" ]; then
    echo "   ✅ É DomainRoutingISM!"
    echo "   📍 ISM para Terra Classic (1325): $ISM_FOR_TERRA"
    echo ""
    
    echo "2️⃣ Obtendo validadores do ISM do Terra Classic..."
    echo ""
    
    # Obter validadores do ISM do Terra Classic
    VALIDATORS_RESULT=$(cast call "$ISM_FOR_TERRA" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$RPC" 2>/dev/null)
    
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
            echo ""
        fi
        
        echo "3️⃣ Verificando anúncios no TERRA CLASSIC..."
        echo ""
        
        VALIDATOR_ANNOUNCE_TERRA="0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"
        TERRA_LCD="https://lcd.luncblaze.com"
        
        ANNOUNCED=0
        for VAL in "${VALIDATORS_LIST[@]}"; do
            echo "   Verificando: $VAL"
            
            # Tentar query via REST API do Terra Classic
            QUERY_BASE64=$(echo -n "{\"get_announced_storage_locations\":{\"validator\":\"$VAL\"}}" | base64 -w 0)
            QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$VALIDATOR_ANNOUNCE_TERRA/smart/$QUERY_BASE64"
            
            RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)
            
            if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
                DATA=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
                if [ -n "$DATA" ] && [ "$DATA" != "null" ] && [ "$DATA" != "" ]; then
                    echo "      ✅ ANUNCIADO no Terra Classic!"
                    echo "$DATA" | jq '.' 2>/dev/null | sed 's/^/         /'
                    ANNOUNCED=$((ANNOUNCED + 1))
                else
                    echo "      ❌ NÃO ANUNCIADO no Terra Classic"
                fi
            else
                echo "      ⚠️  Não foi possível verificar via API"
            fi
            echo ""
        done
        
        echo "========================================="
        echo "📊 RESUMO"
        echo "========================================="
        echo ""
        echo "Validadores no ISM do Terra Classic: ${#VALIDATORS_LIST[@]}"
        echo "Validadores anunciados no Terra Classic: $ANNOUNCED"
        echo "Threshold necessário: $THRESHOLD_VAL"
        echo ""
        
        if [ -n "$THRESHOLD_VAL" ]; then
            if [ $ANNOUNCED -ge "$THRESHOLD_VAL" ]; then
                echo "✅ Quorum possível! ($ANNOUNCED >= $THRESHOLD_VAL)"
                echo ""
                echo "💡 O relayer DEVERIA conseguir buscar checkpoints"
                echo "   dos validadores do Terra Classic anunciados"
            else
                echo "❌ Quorum IMPOSSÍVEL! ($ANNOUNCED < $THRESHOLD_VAL)"
                echo "   ⚠️  Faltam $((THRESHOLD_VAL - ANNOUNCED)) validador(es) anunciando"
                echo ""
                echo "💡 Isso explica por que a mensagem não está sendo entregue:"
                echo "   → O relayer precisa buscar checkpoints do TERRA CLASSIC"
                echo "   → Os validadores do Terra Classic precisam estar anunciados"
                echo "   → Apenas $ANNOUNCED de $THRESHOLD_VAL está(ão) anunciado(s)"
            fi
        fi
    else
        echo "   ❌ Não foi possível obter validadores do ISM do Terra Classic"
    fi
else
    echo "   ⚠️  Não é DomainRoutingISM ou não encontrou ISM para Terra Classic"
    echo ""
    echo "   O ISM do Warp Route pode não estar configurado corretamente"
    echo "   Deveria ser um DomainRoutingISM que aponta para o ISM do Terra Classic"
    echo ""
    echo "   Verifique a configuração do Warp Route"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="

