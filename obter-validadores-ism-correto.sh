#!/bin/bash

echo "========================================="
echo "🔍 OBTENDO VALIDADORES CORRETOS DO ISM"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"

# Lista de RPCs para tentar
RPCS=(
    "https://1rpc.io/sepolia"
    "https://sepolia.drpc.org"
    "https://rpc.ankr.com/eth_sepolia"
    "https://eth-sepolia-public.unifra.io"
)

echo "📍 Contrato Warp Route: $WARP_ROUTE"
echo "📍 ISM conhecido: $WARP_ISM"
echo ""

echo "1️⃣ Obtendo ISM do Warp Route..."
echo ""

ISM_OBTIDO=""
for RPC in "${RPCS[@]}"; do
    echo "   Tentando RPC: $(echo $RPC | cut -d'/' -f3)"
    ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM" ] && [ "$ISM" != "0x" ] && [ "$ISM" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_OBTIDO="$ISM"
        echo "   ✅ ISM obtido: $ISM_OBTIDO"
        break
    else
        echo "   ❌ Falhou"
    fi
done

if [ -z "$ISM_OBTIDO" ]; then
    echo "   ⚠️  Não foi possível obter via RPC, usando ISM conhecido"
    ISM_OBTIDO="$WARP_ISM"
fi

echo ""
echo "2️⃣ Obtendo validadores do ISM: $ISM_OBTIDO"
echo ""

VALIDATORS_ENCONTRADOS=()
THRESHOLD_ENCONTRADO=""

# Método 1: validators() - variável pública
echo "   Método 1: Tentando validators()..."
for RPC in "${RPCS[@]}"; do
    RESULT=$(cast call "$ISM_OBTIDO" "validators()(address[])" --rpc-url "$RPC" 2>/dev/null)
    
    if [ -n "$RESULT" ] && [ "$RESULT" != "0x" ] && ! echo "$RESULT" | grep -qi "error\|revert"; then
        echo "   ✅ Sucesso com RPC: $(echo $RPC | cut -d'/' -f3)"
        echo ""
        echo "   Validadores encontrados:"
        
        # Extrair endereços do resultado
        echo "$RESULT" | grep -oE "0x[a-fA-F0-9]{40}" | while read addr; do
            CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
            if [ -n "$CHECKSUM" ]; then
                VALIDATORS_ENCONTRADOS+=("$CHECKSUM")
                echo "      - $CHECKSUM"
            fi
        done
        
        # Obter threshold
        THRESHOLD=$(cast call "$ISM_OBTIDO" "threshold()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
        if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" != "0x" ]; then
            THRESHOLD_DEC=$(printf "%d" "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
            THRESHOLD_ENCONTRADO="$THRESHOLD_DEC"
            echo ""
            echo "   ✅ Threshold: $THRESHOLD_DEC"
        fi
        
        break
    fi
done

# Método 2: validatorsAndThreshold() se método 1 falhou
if [ ${#VALIDATORS_ENCONTRADOS[@]} -eq 0 ]; then
    echo ""
    echo "   Método 2: Tentando validatorsAndThreshold(bytes)..."
    for RPC in "${RPCS[@]}"; do
        RESULT=$(cast call "$ISM_OBTIDO" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$RPC" 2>/dev/null)
        
        if [ -n "$RESULT" ] && [ "$RESULT" != "0x" ] && ! echo "$RESULT" | grep -qi "error\|revert"; then
            echo "   ✅ Sucesso com RPC: $(echo $RPC | cut -d'/' -f3)"
            echo ""
            echo "   Resultado:"
            echo "$RESULT" | sed 's/^/      /'
            echo ""
            
            # Tentar extrair validadores
            echo "$RESULT" | grep -oE "0x[a-fA-F0-9]{40}" | while read addr; do
                CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
                if [ -n "$CHECKSUM" ]; then
                    echo "      - $CHECKSUM"
                fi
            done
            
            break
        fi
    done
fi

# Método 3: Tentar ler storage slots
if [ ${#VALIDATORS_ENCONTRADOS[@]} -eq 0 ]; then
    echo ""
    echo "   Método 3: Lendo storage slots..."
    
    for RPC in "${RPCS[@]}"; do
        SLOT0=$(cast storage "$ISM_OBTIDO" 0 --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
        
        if [ -n "$SLOT0" ] && [ "$SLOT0" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
            COUNT=$(printf "%d" "$SLOT0" 2>/dev/null || echo "0")
            
            if [ "$COUNT" -gt 0 ] && [ "$COUNT" -lt 20 ]; then
                echo "   ✅ Possível validatorCount no slot 0: $COUNT"
                echo ""
                echo "   Lendo validadores dos slots..."
                
                for slot in $(seq 2 $((COUNT + 1))); do
                    SLOT_VAL=$(cast storage "$ISM_OBTIDO" "$slot" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                    
                    if [ -n "$SLOT_VAL" ] && [ "$SLOT_VAL" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
                        ADDR="0x${SLOT_VAL:26:40}"
                        CHECKSUM=$(cast --to-checksum-address "$ADDR" 2>/dev/null)
                        
                        if [ -n "$CHECKSUM" ] && [ "$CHECKSUM" != "0x0000000000000000000000000000000000000000" ]; then
                            VALIDATORS_ENCONTRADOS+=("$CHECKSUM")
                            echo "      [$((slot-1))] $CHECKSUM"
                        fi
                    fi
                done
                
                # Ler threshold do slot 1
                SLOT1=$(cast storage "$ISM_OBTIDO" 1 --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                if [ -n "$SLOT1" ]; then
                    THRESHOLD_FROM_SLOT=$(printf "%d" "$SLOT1" 2>/dev/null || echo "0")
                    if [ "$THRESHOLD_FROM_SLOT" -gt 0 ]; then
                        THRESHOLD_ENCONTRADO="$THRESHOLD_FROM_SLOT"
                        echo ""
                        echo "   ✅ Threshold (slot 1): $THRESHOLD_FROM_SLOT"
                    fi
                fi
                
                break
            fi
        fi
    done
fi

echo ""
echo "========================================="
echo "📊 RESULTADO FINAL"
echo "========================================="
echo ""

if [ ${#VALIDATORS_ENCONTRADOS[@]} -gt 0 ]; then
    echo "✅ VALIDADORES ENCONTRADOS:"
    for i in "${!VALIDATORS_ENCONTRADOS[@]}"; do
        echo "   [$((i+1))] ${VALIDATORS_ENCONTRADOS[$i]}"
    done
    echo ""
    
    if [ -n "$THRESHOLD_ENCONTRADO" ]; then
        echo "✅ Threshold: $THRESHOLD_ENCONTRADO de ${#VALIDATORS_ENCONTRADOS[@]}"
    fi
    
    echo ""
    echo "🔍 Verificando se estão anunciados no Sepolia..."
    echo ""
    
    VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
    LATEST_BLOCK=$(cast block-number --rpc-url "${RPCS[0]}" 2>/dev/null | tr -d '\n')
    FROM_BLOCK=$((LATEST_BLOCK - 50000))
    
    ANNOUNCED=0
    for VAL in "${VALIDATORS_ENCONTRADOS[@]}"; do
        VAL_PADDED=$(printf "0x%064s" "${VAL:2}" | tr ' ' '0')
        ANNOUNCEMENT=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
            "Announcement(address indexed validator, string storageLocation, string[] domains)" \
            --address "$VALIDATOR_ANNOUNCE" \
            --topic1 "$VAL_PADDED" \
            --rpc-url "${RPCS[0]}" 2>/dev/null)
        
        if [ -n "$ANNOUNCEMENT" ] && [ "$ANNOUNCEMENT" != "" ]; then
            echo "   ✅ $VAL - ANUNCIADO"
            ANNOUNCED=$((ANNOUNCED + 1))
        else
            echo "   ❌ $VAL - NÃO ANUNCIADO"
        fi
    done
    
    echo ""
    if [ -n "$THRESHOLD_ENCONTRADO" ]; then
        if [ $ANNOUNCED -ge "$THRESHOLD_ENCONTRADO" ]; then
            echo "   ✅ Quorum possível! ($ANNOUNCED >= $THRESHOLD_ENCONTRADO)"
        else
            echo "   ❌ Quorum IMPOSSÍVEL! ($ANNOUNCED < $THRESHOLD_ENCONTRADO)"
            echo "   ⚠️  Faltam $((THRESHOLD_ENCONTRADO - ANNOUNCED)) validador(es) anunciando"
        fi
    fi
else
    echo "❌ NÃO FOI POSSÍVEL OBTER VALIDADORES AUTOMATICAMENTE"
    echo ""
    echo "💡 Use o Etherscan para obter manualmente:"
    echo "   https://sepolia.etherscan.io/address/$ISM_OBTIDO#readContract"
    echo ""
    echo "   Tente os métodos:"
    echo "   - validators()"
    echo "   - validatorsAndThreshold(bytes) com '0x'"
    echo "   - threshold()"
fi

echo ""
echo "========================================="

