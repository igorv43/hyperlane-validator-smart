#!/bin/bash

echo "========================================="
echo "👀 MONITORAMENTO DE VALIDADORES - SEPOLIA"
echo "========================================="
echo ""

VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
SEPOLIA_RPC="https://1rpc.io/sepolia"

ISM_VALIDATORS=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

THRESHOLD=2
INTERVAL=${1:-60}  # Intervalo em segundos (padrão: 60s)

echo "📋 Monitorando validadores do ISM:"
for i in "${!ISM_VALIDATORS[@]}"; do
    echo "   [$((i+1))] ${ISM_VALIDATORS[$i]}"
done
echo ""
echo "   Threshold: $THRESHOLD de ${#ISM_VALIDATORS[@]}"
echo "   Intervalo de verificação: ${INTERVAL}s"
echo "   Pressione Ctrl+C para parar"
echo ""
echo "========================================="
echo ""

LAST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LAST_BLOCK - 1000))

while true; do
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    CURRENT_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    echo "[$CURRENT_TIME] Bloco atual: $CURRENT_BLOCK"
    
    FOUND=0
    ANNOUNCED_VALIDATORS=()
    
    for i in "${!ISM_VALIDATORS[@]}"; do
        VALIDATOR="${ISM_VALIDATORS[$i]}"
        VALIDATOR_PADDED=$(printf "0x%064s" "${VALIDATOR:2}" | tr ' ' '0')
        
        ANNOUNCEMENTS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
            "Announcement(address indexed validator, string storageLocation, string[] domains)" \
            --address "$VALIDATOR_ANNOUNCE" \
            --topic1 "$VALIDATOR_PADDED" \
            --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
        
        if [ -n "$ANNOUNCEMENTS" ] && [ "$ANNOUNCEMENTS" != "" ]; then
            if [[ ! " ${ANNOUNCED_VALIDATORS[@]} " =~ " ${VALIDATOR} " ]]; then
                echo "   ✅ NOVO: $VALIDATOR está anunciado!"
                ANNOUNCED_VALIDATORS+=("$VALIDATOR")
                FOUND=$((FOUND + 1))
            fi
        fi
    done
    
    if [ $FOUND -ge $THRESHOLD ]; then
        echo ""
        echo "   🎉 QUORUM ATINGIDO! ($FOUND >= $THRESHOLD)"
        echo "   ✅ O relayer agora pode buscar checkpoints!"
        echo "   ✅ Mensagens podem ser entregues!"
        echo ""
    else
        echo "   Status: $FOUND de $THRESHOLD validadores anunciados"
        if [ $FOUND -gt 0 ]; then
            echo "   Validadores anunciados:"
            for VAL in "${ANNOUNCED_VALIDATORS[@]}"; do
                echo "      - $VAL"
            done
        fi
    fi
    
    echo ""
    sleep "$INTERVAL"
done

