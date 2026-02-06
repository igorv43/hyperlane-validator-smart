#!/bin/bash

echo "========================================="
echo "✅ VALIDADORES DO ISM DO WARP ROUTE"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
RPC="https://sepolia.drpc.org"

echo "📍 Contrato Warp Route:"
echo "   $WARP_ROUTE"
echo ""

echo "📍 ISM do Warp Route:"
echo "   $WARP_ISM"
echo ""

echo "🔍 Obtendo validadores e threshold..."
echo ""

RESULT=$(cast call "$WARP_ISM" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$RPC" 2>/dev/null)

if [ -z "$RESULT" ] || echo "$RESULT" | grep -qi "error\|revert"; then
    echo "   ❌ Erro ao obter validadores"
    exit 1
fi

# Extrair validadores
VALIDATORS=()
while IFS= read -r addr; do
    if [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
        if [ -n "$CHECKSUM" ]; then
            VALIDATORS+=("$CHECKSUM")
        fi
    fi
done < <(echo "$RESULT" | grep -oE "0x[a-fA-F0-9]{40}")

# Extrair threshold
THRESHOLD=$(echo "$RESULT" | grep -oE "[0-9]+" | tail -1)

echo "========================================="
echo "📋 VALIDADORES ENCONTRADOS"
echo "========================================="
echo ""

if [ ${#VALIDATORS[@]} -gt 0 ]; then
    echo "✅ Total de validadores: ${#VALIDATORS[@]}"
    echo ""
    for i in "${!VALIDATORS[@]}"; do
        echo "   [$((i+1))] ${VALIDATORS[$i]}"
    done
    echo ""
    
    if [ -n "$THRESHOLD" ]; then
        echo "✅ Threshold: $THRESHOLD de ${#VALIDATORS[@]}"
        echo ""
    fi
    
    echo "========================================="
    echo "🔍 VERIFICANDO ANÚNCIOS NO SEPOLIA"
    echo "========================================="
    echo ""
    
    VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
    LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FROM_BLOCK=$((LATEST_BLOCK - 50000))
    
    echo "Buscando anúncios nos últimos 50000 blocos..."
    echo "Blocos: $FROM_BLOCK até $LATEST_BLOCK"
    echo ""
    
    ANNOUNCED=0
    for VAL in "${VALIDATORS[@]}"; do
        VAL_PADDED=$(printf "0x%064s" "${VAL:2}" | tr ' ' '0')
        
        echo "Verificando: $VAL"
        ANNOUNCEMENT=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
            "Announcement(address indexed validator, string storageLocation, string[] domains)" \
            --address "$VALIDATOR_ANNOUNCE" \
            --topic1 "$VAL_PADDED" \
            --rpc-url "$RPC" 2>/dev/null)
        
        if [ -n "$ANNOUNCEMENT" ] && [ "$ANNOUNCEMENT" != "" ]; then
            echo "   ✅ ANUNCIADO"
            
            # Tentar extrair storage location
            STORAGE=$(echo "$ANNOUNCEMENT" | grep -oP 'storageLocation: \K[^,}]+' | head -1)
            if [ -n "$STORAGE" ]; then
                echo "      📦 Storage: $STORAGE"
            fi
            ANNOUNCED=$((ANNOUNCED + 1))
        else
            echo "   ❌ NÃO ANUNCIADO"
        fi
        echo ""
    done
    
    echo "========================================="
    echo "📊 RESUMO"
    echo "========================================="
    echo ""
    echo "Validadores no ISM: ${#VALIDATORS[@]}"
    echo "Validadores anunciados: $ANNOUNCED"
    echo "Threshold necessário: $THRESHOLD"
    echo ""
    
    if [ -n "$THRESHOLD" ]; then
        if [ $ANNOUNCED -ge "$THRESHOLD" ]; then
            echo "✅ Quorum possível! ($ANNOUNCED >= $THRESHOLD)"
            echo ""
            echo "💡 O relayer DEVERIA conseguir buscar checkpoints e entregar mensagens"
        else
            echo "❌ Quorum IMPOSSÍVEL! ($ANNOUNCED < $THRESHOLD)"
            echo "   ⚠️  Faltam $((THRESHOLD - ANNOUNCED)) validador(es) anunciando"
            echo ""
            echo "💡 Isso explica por que a mensagem não está sendo entregue:"
            echo "   → O relayer precisa de $THRESHOLD validador(es) assinando"
            echo "   → Apenas $ANNOUNCED validador(es) está(ão) anunciado(s)"
        fi
    fi
else
    echo "❌ Nenhum validador encontrado"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="

