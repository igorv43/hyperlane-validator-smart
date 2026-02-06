#!/bin/bash

echo "========================================="
echo "🔍 ANÁLISE COMPLETA: VALIDADORES E ISM"
echo "========================================="
echo ""

# Configurações
VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"
EVENT_TOPIC="0x7ca432a5a930e8bc77f93b6d5a42a1efa0769b43472a3f96eabd6fa824c13074"

# Validadores do ISM (identificados nos logs do relayer)
ISM_VALIDATORS=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

THRESHOLD=2

echo "📋 Validadores do ISM (precisam de $THRESHOLD de ${#ISM_VALIDATORS[@]}):"
for i in "${!ISM_VALIDATORS[@]}"; do
    echo "   [$((i+1))] ${ISM_VALIDATORS[$i]}"
done
echo ""

echo "1️⃣ Buscando TODOS os anúncios no ValidatorAnnounce..."
echo "   Contrato: $VALIDATOR_ANNOUNCE"
echo ""

# Buscar todos os anúncios
RESPONSE=$(curl -s "https://api-sepolia.etherscan.io/api?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=$VALIDATOR_ANNOUNCE&topic0=$EVENT_TOPIC&apikey=$API_KEY")

# Verificar se a resposta é válida
if echo "$RESPONSE" | jq -e '.status == "1"' >/dev/null 2>&1; then
    TOTAL=$(echo "$RESPONSE" | jq '.result | length')
    echo "   ✅ Total de anúncios encontrados: $TOTAL"
    echo ""
    
    # Extrair todos os validadores únicos que anunciaram
    echo "2️⃣ Extraindo validadores únicos que anunciaram..."
    ANNOUNCED_VALIDATORS=$(echo "$RESPONSE" | jq -r '.result | .[] | "0x\(.topics[1][-40:])"' | sort -u)
    ANNOUNCED_COUNT=$(echo "$ANNOUNCED_VALIDATORS" | wc -l)
    
    echo "   ✅ $ANNOUNCED_COUNT validador(es) único(s) encontrado(s)"
    echo ""
    
    # Verificar quais validadores do ISM estão anunciados
    echo "3️⃣ Verificando se os validadores do ISM estão anunciados..."
    echo ""
    
    FOUND=0
    for i in "${!ISM_VALIDATORS[@]}"; do
        VALIDATOR="${ISM_VALIDATORS[$i]}"
        VALIDATOR_LOWER=$(echo "$VALIDATOR" | tr '[:upper:]' '[:lower:]')
        
        if echo "$ANNOUNCED_VALIDATORS" | grep -qi "^${VALIDATOR_LOWER}$"; then
            echo "   ✅ [$((i+1))] $VALIDATOR - ANUNCIADO"
            FOUND=$((FOUND + 1))
            
            # Buscar último anúncio deste validador
            LAST_ANNOUNCE=$(echo "$RESPONSE" | jq -r ".result | map(select(.topics[1][-40:] == \"${VALIDATOR:2}\")) | sort_by(.blockNumber) | .[-1]")
            if [ -n "$LAST_ANNOUNCE" ] && [ "$LAST_ANNOUNCE" != "null" ]; then
                BLOCK=$(echo "$LAST_ANNOUNCE" | jq -r '.blockNumber')
                TX=$(echo "$LAST_ANNOUNCE" | jq -r '.transactionHash')
                echo "      📍 Último anúncio: Bloco $BLOCK"
                echo "      🔗 Tx: https://sepolia.etherscan.io/tx/$TX"
            fi
        else
            echo "   ❌ [$((i+1))] $VALIDATOR - NÃO ANUNCIADO"
        fi
        echo ""
    done
    
    echo "4️⃣ Resumo:"
    echo "   Validadores do ISM encontrados: $FOUND de ${#ISM_VALIDATORS[@]}"
    echo "   Threshold necessário: $THRESHOLD"
    
    if [ $FOUND -ge $THRESHOLD ]; then
        echo "   ✅ Quorum possível! ($FOUND >= $THRESHOLD)"
    else
        echo "   ❌ Quorum IMPOSSÍVEL! ($FOUND < $THRESHOLD)"
        echo "   ⚠️  Faltam $((THRESHOLD - FOUND)) validador(es) anunciando"
    fi
    
    echo ""
    echo "5️⃣ Listando outros validadores que anunciaram (não são do ISM):"
    echo ""
    
    OTHER_VALIDATORS=$(echo "$ANNOUNCED_VALIDATORS")
    OTHER_COUNT=0
    for VAL in $OTHER_VALIDATORS; do
        VAL_UPPER=$(echo "$VAL" | tr '[:lower:]' '[:upper:]')
        IS_ISM_VALIDATOR=false
        
        for ISM_VAL in "${ISM_VALIDATORS[@]}"; do
            if [ "$(echo "$ISM_VAL" | tr '[:upper:]' '[:lower:]')" = "$VAL" ]; then
                IS_ISM_VALIDATOR=true
                break
            fi
        done
        
        if [ "$IS_ISM_VALIDATOR" = false ]; then
            echo "   - $VAL_UPPER"
            OTHER_COUNT=$((OTHER_COUNT + 1))
            if [ $OTHER_COUNT -ge 10 ]; then
                echo "   ... (mostrando apenas os primeiros 10)"
                break
            fi
        fi
    done
    
    if [ $OTHER_COUNT -eq 0 ]; then
        echo "   (nenhum outro validador encontrado)"
    fi
    
else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // .result' 2>/dev/null)
    echo "   ❌ Erro ao buscar anúncios: $ERROR"
fi

echo ""
echo "========================================="
echo "✅ Análise concluída"
echo "========================================="
echo ""
echo "💡 INTERPRETAÇÃO:"
echo ""
echo "   Se os validadores do ISM NÃO estão anunciados:"
echo "   → Eles não estão rodando ou não anunciaram ainda"
echo "   → O relayer não consegue buscar checkpoints deles"
echo "   → Mensagens não podem ser entregues (sem quorum)"
echo ""
echo "   Se os validadores do ISM ESTÃO anunciados:"
echo "   → Verifique se os checkpoints estão acessíveis"
echo "   → Verifique se o relayer tem acesso aos checkpoints"
echo "   → Verifique a configuração do checkpointSyncer"
echo ""

