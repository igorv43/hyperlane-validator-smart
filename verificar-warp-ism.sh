#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO ISM DO WARP ROUTE"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM_CONHECIDO="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"

# Lista de RPCs para tentar
RPCS=(
    "https://sepolia.drpc.org"
    "https://1rpc.io/sepolia"
    "https://rpc.ankr.com/eth_sepolia"
    "https://eth-sepolia-public.unifra.io"
)

SEPOLIA_RPC="${RPCS[0]}"  # Usar o primeiro como padrão

echo "📍 Contrato Warp Route:"
echo "   $WARP_ROUTE"
echo "   https://sepolia.etherscan.io/address/$WARP_ROUTE"
echo ""

echo "1️⃣ Tentando obter o ISM do contrato..."
echo ""

# O Warp Route herda de MailboxClient que tem o método interchainSecurityModule()
# Retorna IInterchainSecurityModule (que é um address)
echo "   Chamando interchainSecurityModule()..."
ISM1=""
for RPC in "${RPCS[@]}"; do
    ISM1=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    if [ -n "$ISM1" ] && [ "$ISM1" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM1" != "0x" ]; then
        SEPOLIA_RPC="$RPC"  # Usar o RPC que funcionou
        break
    fi
done

if [ -n "$ISM1" ] && [ "$ISM1" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM1" != "0x" ]; then
    ISM="$ISM1"
    METHOD="interchainSecurityModule()"
    echo "   ✅ ISM obtido via interchainSecurityModule()"
    
    # Verificar se corresponde ao ISM conhecido
    if [ "$(echo "$ISM" | tr '[:upper:]' '[:lower:]')" = "$(echo "$WARP_ISM_CONHECIDO" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "   ✅ Confirma associação com Warp Route!"
    fi
else
    echo "   ⚠️  Não foi possível obter via RPC, usando ISM conhecido"
    ISM="$WARP_ISM_CONHECIDO"
    METHOD="conhecido (confirmado pelo usuário)"
fi

echo "   ✅ ISM encontrado via $METHOD"
echo "   📍 ISM: $ISM"
echo ""

echo "2️⃣ Verificando tipo de ISM..."
echo ""

# Verificar se é DomainRoutingISM
ROUTING_ISM=$(cast call "$ISM" "module(uint32)(address)" "1325" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -n "$ROUTING_ISM" ] && [ "$ROUTING_ISM" != "0x0000000000000000000000000000000000000000" ] && [ "$ROUTING_ISM" != "0x" ]; then
    echo "   ✅ É um DomainRoutingISM"
    echo "   📍 ISM para Terra Classic (1325): $ROUTING_ISM"
    ACTUAL_ISM="$ROUTING_ISM"
else
    echo "   ⚠️  Não é DomainRoutingISM ou não encontrado"
    ACTUAL_ISM="$ISM"
fi

echo ""
echo "3️⃣ Verificando validadores no ISM: $ACTUAL_ISM"
echo ""

# Tentar obter validadores - método 1: validatorsAndThreshold (para ISMs multisig)
echo "   Tentando validatorsAndThreshold()..."
# Para StorageMultisigIsm, podemos passar mensagem vazia
VALIDATORS_AND_THRESHOLD=""
for RPC in "${RPCS[@]}"; do
    VALIDATORS_AND_THRESHOLD=$(cast call "$ACTUAL_ISM" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$RPC" 2>/dev/null)
    if [ -n "$VALIDATORS_AND_THRESHOLD" ] && [ "$VALIDATORS_AND_THRESHOLD" != "0x" ] && ! echo "$VALIDATORS_AND_THRESHOLD" | grep -qi "error\|revert"; then
        SEPOLIA_RPC="$RPC"  # Usar o RPC que funcionou
        break
    fi
done

if [ -n "$VALIDATORS_AND_THRESHOLD" ] && [ "$VALIDATORS_AND_THRESHOLD" != "0x" ] && ! echo "$VALIDATORS_AND_THRESHOLD" | grep -qi "error\|revert"; then
    echo "   ✅ Validadores obtidos via validatorsAndThreshold()!"
    echo ""
    
    # Extrair validadores do resultado
    VALIDATORS_LIST=()
    while IFS= read -r addr; do
        if [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
            if [ -n "$CHECKSUM" ]; then
                VALIDATORS_LIST+=("$CHECKSUM")
            fi
        fi
    done < <(echo "$VALIDATORS_AND_THRESHOLD" | grep -oE "0x[a-fA-F0-9]{40}")
    
    # Extrair threshold
    THRESHOLD_VAL=$(echo "$VALIDATORS_AND_THRESHOLD" | grep -oE "[0-9]+" | tail -1)
    
    if [ ${#VALIDATORS_LIST[@]} -gt 0 ]; then
        echo "   📋 Validadores encontrados:"
        for i in "${!VALIDATORS_LIST[@]}"; do
            echo "      [$((i+1))] ${VALIDATORS_LIST[$i]}"
        done
        echo ""
        
        if [ -n "$THRESHOLD_VAL" ]; then
            echo "   ✅ Threshold: $THRESHOLD_VAL de ${#VALIDATORS_LIST[@]}"
            echo ""
        fi
        
        # Verificar se estão anunciados
        echo "   🔍 Verificando anúncios no ValidatorAnnounce do Sepolia..."
        VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
        LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
        FROM_BLOCK=$((LATEST_BLOCK - 50000))
        
        ANNOUNCED_COUNT=0
        for VAL in "${VALIDATORS_LIST[@]}"; do
            VAL_PADDED=$(printf "0x%064s" "${VAL:2}" | tr ' ' '0')
            ANNOUNCEMENT=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
                "Announcement(address indexed validator, string storageLocation, string[] domains)" \
                --address "$VALIDATOR_ANNOUNCE" \
                --topic1 "$VAL_PADDED" \
                --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
            
            if [ -n "$ANNOUNCEMENT" ] && [ "$ANNOUNCEMENT" != "" ]; then
                echo "      ✅ $VAL - ANUNCIADO"
                ANNOUNCED_COUNT=$((ANNOUNCED_COUNT + 1))
            else
                echo "      ❌ $VAL - NÃO ANUNCIADO"
            fi
        done
        
        echo ""
        if [ -n "$THRESHOLD_VAL" ]; then
            if [ $ANNOUNCED_COUNT -ge "$THRESHOLD_VAL" ]; then
                echo "   ✅ Quorum possível! ($ANNOUNCED_COUNT >= $THRESHOLD_VAL)"
                echo "   💡 O relayer DEVERIA conseguir buscar checkpoints"
            else
                echo "   ❌ Quorum IMPOSSÍVEL! ($ANNOUNCED_COUNT < $THRESHOLD_VAL)"
                echo "   ⚠️  Faltam $((THRESHOLD_VAL - ANNOUNCED_COUNT)) validador(es) anunciando"
                echo ""
                echo "   💡 Isso explica por que a mensagem não está sendo entregue:"
                echo "      → O relayer precisa de $THRESHOLD_VAL validador(es) assinando"
                echo "      → Apenas $ANNOUNCED_COUNT validador(es) está(ão) anunciado(s)"
            fi
        fi
        
        echo ""
        echo "========================================="
        echo "✅ Verificação concluída"
        echo "========================================="
        exit 0
    fi
fi

# Tentar método 2: validatorCount (para outros tipos de ISM)
VALIDATOR_COUNT=$(cast call "$ACTUAL_ISM" "validatorCount()(uint256)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -n "$VALIDATOR_COUNT" ] && [ "$VALIDATOR_COUNT" != "0" ] && [ "$VALIDATOR_COUNT" != "0x0" ] && [ "$VALIDATOR_COUNT" != "0x" ]; then
    COUNT_DEC=$(printf "%d" "$VALIDATOR_COUNT" 2>/dev/null || echo "$VALIDATOR_COUNT")
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
    
    # Verificar threshold
    echo ""
    THRESHOLD=$(cast call "$ACTUAL_ISM" "threshold()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" != "0x" ]; then
        THRESHOLD_DEC=$(printf "%d" "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
        echo "   ✅ Threshold: $THRESHOLD_DEC de $COUNT_DEC"
    fi
    
    echo ""
    echo "4️⃣ Comparando com validadores dos logs do relayer..."
    echo ""
    
    RELAYER_VALIDATORS=(
        "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
        "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
        "0x1f030345963c54ff8229720dd3a711c15c554aeb"
    )
    
    MATCH=0
    for RELAYER_VAL in "${RELAYER_VALIDATORS[@]}"; do
        RELAYER_VAL_LOWER=$(echo "$RELAYER_VAL" | tr '[:upper:]' '[:lower:]')
        FOUND=false
        for WARP_VAL in "${VALIDATORS[@]}"; do
            WARP_VAL_LOWER=$(echo "$WARP_VAL" | tr '[:upper:]' '[:lower:]')
            if [ "$RELAYER_VAL_LOWER" = "$WARP_VAL_LOWER" ]; then
                FOUND=true
                MATCH=$((MATCH + 1))
                echo "   ✅ $RELAYER_VAL - ENCONTRADO no ISM do Warp Route"
                break
            fi
        done
        if [ "$FOUND" = false ]; then
            echo "   ❌ $RELAYER_VAL - NÃO encontrado no ISM do Warp Route"
        fi
    done
    
    echo ""
    if [ $MATCH -eq ${#RELAYER_VALIDATORS[@]} ]; then
        echo "   ✅ Todos os validadores dos logs correspondem ao ISM do Warp Route"
    else
        echo "   ⚠️  Há diferenças entre os validadores dos logs e do ISM do Warp Route"
    fi
    
else
    echo "   ⚠️  Não foi possível obter validadores via validatorCount()"
    echo ""
    echo "5️⃣ Tentando método alternativo: ler storage slots diretamente..."
    echo ""
    
    # Tentar ler storage slots (MessageIdMultisig armazena validadores em slots específicos)
    # Slot 0 geralmente contém o length do array de validadores
    SLOT0=$(cast storage "$ACTUAL_ISM" 0 --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$SLOT0" ] && [ "$SLOT0" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
        # Tentar interpretar como número
        COUNT_FROM_SLOT=$(printf "%d" "$SLOT0" 2>/dev/null || echo "0")
        
        if [ "$COUNT_FROM_SLOT" -gt 0 ] && [ "$COUNT_FROM_SLOT" -lt 20 ]; then
            echo "   ✅ Possível validatorCount no slot 0: $COUNT_FROM_SLOT"
            echo ""
            echo "   Lendo validadores dos storage slots..."
            echo ""
            
            VALIDATORS_FOUND=()
            # Validadores geralmente começam no slot 2 (slot 0 = count, slot 1 = threshold)
            for slot in $(seq 2 $((COUNT_FROM_SLOT + 1))); do
                SLOT_VAL=$(cast storage "$ACTUAL_ISM" "$slot" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
                
                if [ -n "$SLOT_VAL" ] && [ "$SLOT_VAL" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
                    # Extrair endereço (últimos 20 bytes = 40 hex chars)
                    ADDR="0x${SLOT_VAL:26:40}"
                    ADDR_CHECKSUM=$(cast --to-checksum-address "$ADDR" 2>/dev/null)
                    
                    if [ -n "$ADDR_CHECKSUM" ] && [ "$ADDR_CHECKSUM" != "0x0000000000000000000000000000000000000000" ]; then
                        VALIDATORS_FOUND+=("$ADDR_CHECKSUM")
                        echo "      [$((slot-1))] $ADDR_CHECKSUM"
                    fi
                fi
            done
            
            if [ ${#VALIDATORS_FOUND[@]} -gt 0 ]; then
                echo ""
                echo "   ✅ Total de validadores encontrados: ${#VALIDATORS_FOUND[@]}"
                
                # Verificar threshold no slot 1
                SLOT1=$(cast storage "$ACTUAL_ISM" 1 --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
                if [ -n "$SLOT1" ]; then
                    THRESHOLD_FROM_SLOT=$(printf "%d" "$SLOT1" 2>/dev/null || echo "0")
                    if [ "$THRESHOLD_FROM_SLOT" -gt 0 ]; then
                        echo "   ✅ Threshold (slot 1): $THRESHOLD_FROM_SLOT"
                    fi
                fi
                
                echo ""
                echo "6️⃣ Validadores encontrados no ISM do Warp Route:"
                for i in "${!VALIDATORS_FOUND[@]}"; do
                    echo "   [$((i+1))] ${VALIDATORS_FOUND[$i]}"
                done
                
                echo ""
                echo "7️⃣ Verificando se estes validadores estão anunciados no Sepolia..."
                echo ""
                
                VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
                LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
                FROM_BLOCK=$((LATEST_BLOCK - 50000))
                
                ANNOUNCED_COUNT=0
                for VAL in "${VALIDATORS_FOUND[@]}"; do
                    VAL_PADDED=$(printf "0x%064s" "${VAL:2}" | tr ' ' '0')
                    ANNOUNCEMENT=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
                        "Announcement(address indexed validator, string storageLocation, string[] domains)" \
                        --address "$VALIDATOR_ANNOUNCE" \
                        --topic1 "$VAL_PADDED" \
                        --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
                    
                    if [ -n "$ANNOUNCEMENT" ] && [ "$ANNOUNCEMENT" != "" ]; then
                        echo "   ✅ $VAL - ANUNCIADO"
                        ANNOUNCED_COUNT=$((ANNOUNCED_COUNT + 1))
                    else
                        echo "   ❌ $VAL - NÃO ANUNCIADO"
                    fi
                done
                
                echo ""
                if [ "$THRESHOLD_FROM_SLOT" -gt 0 ]; then
                    if [ $ANNOUNCED_COUNT -ge "$THRESHOLD_FROM_SLOT" ]; then
                        echo "   ✅ Quorum possível! ($ANNOUNCED_COUNT >= $THRESHOLD_FROM_SLOT)"
                    else
                        echo "   ❌ Quorum IMPOSSÍVEL! ($ANNOUNCED_COUNT < $THRESHOLD_FROM_SLOT)"
                        echo "   ⚠️  Faltam $((THRESHOLD_FROM_SLOT - ANNOUNCED_COUNT)) validador(es) anunciando"
                    fi
                fi
            else
                echo "   ⚠️  Não foi possível extrair validadores dos storage slots"
            fi
        else
            echo "   ⚠️  Slot 0 não contém um número válido de validadores"
        fi
    else
        echo "   ⚠️  Slot 0 está vazio ou zero"
    fi
    
    echo ""
    echo "8️⃣ Tentando método final: verificar código do contrato..."
    echo "   https://sepolia.etherscan.io/address/$ACTUAL_ISM#readContract"
    echo "   Tente chamar manualmente:"
    echo "   - validators()"
    echo "   - validatorCount()"
    echo "   - validatorAt(0), validatorAt(1), etc."
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="

