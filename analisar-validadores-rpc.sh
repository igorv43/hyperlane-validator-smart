#!/bin/bash

echo "========================================="
echo "🔍 ANÁLISE: VALIDADORES DO ISM"
echo "========================================="
echo ""

VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
SEPOLIA_RPC="https://1rpc.io/sepolia"

# Validadores do ISM
ISM_VALIDATORS=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

THRESHOLD=2

echo "📋 Validadores do ISM (threshold: $THRESHOLD de ${#ISM_VALIDATORS[@]}):"
for i in "${!ISM_VALIDATORS[@]}"; do
    echo "   [$((i+1))] ${ISM_VALIDATORS[$i]}"
done
echo ""

echo "1️⃣ Verificando anúncios via RPC (últimos 50000 blocos)..."
echo ""

LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 50000))

echo "   Blocos: $FROM_BLOCK até $LATEST_BLOCK"
echo ""

# Buscar anúncios para cada validador do ISM
FOUND=0
for i in "${!ISM_VALIDATORS[@]}"; do
    VALIDATOR="${ISM_VALIDATORS[$i]}"
    VALIDATOR_PADDED=$(printf "0x%064s" "${VALIDATOR:2}" | tr ' ' '0')
    
    echo "   Verificando [$((i+1))] $VALIDATOR..."
    
    # Buscar eventos Announcement para este validador
    ANNOUNCEMENTS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
        "Announcement(address indexed validator, string storageLocation, string[] domains)" \
        --address "$VALIDATOR_ANNOUNCE" \
        --topic1 "$VALIDATOR_PADDED" \
        --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
    
    if [ -n "$ANNOUNCEMENTS" ] && [ "$ANNOUNCEMENTS" != "" ]; then
        echo "      ✅ ANUNCIADO!"
        FOUND=$((FOUND + 1))
        
        # Extrair informações do último anúncio
        LAST_BLOCK=$(echo "$ANNOUNCEMENTS" | grep -oP 'blockNumber: \K[0-9]+' | tail -1)
        if [ -n "$LAST_BLOCK" ]; then
            echo "      📍 Último anúncio: Bloco $LAST_BLOCK"
        fi
        
        # Tentar extrair storage location
        STORAGE=$(echo "$ANNOUNCEMENTS" | grep -oP 'storageLocation: \K[^,}]+' | tail -1)
        if [ -n "$STORAGE" ]; then
            echo "      📦 Storage: $STORAGE"
        fi
    else
        echo "      ❌ NÃO ANUNCIADO"
    fi
    echo ""
done

echo "2️⃣ Resumo:"
echo "   Validadores do ISM encontrados: $FOUND de ${#ISM_VALIDATORS[@]}"
echo "   Threshold necessário: $THRESHOLD"
echo ""

if [ $FOUND -ge $THRESHOLD ]; then
    echo "   ✅ Quorum possível! ($FOUND >= $THRESHOLD)"
    echo ""
    echo "   💡 Se o relayer ainda não consegue buscar checkpoints:"
    echo "      → Verifique se os checkpoints estão acessíveis"
    echo "      → Verifique a configuração do checkpointSyncer"
    echo "      → Verifique se allowLocalCheckpointSyncers está correto"
else
    echo "   ❌ Quorum IMPOSSÍVEL! ($FOUND < $THRESHOLD)"
    echo "   ⚠️  Faltam $((THRESHOLD - FOUND)) validador(es) anunciando"
    echo ""
    echo "   💡 Isso explica por que a mensagem não está sendo entregue:"
    echo "      → O relayer precisa de $THRESHOLD validadores assinando"
    echo "      → Apenas $FOUND validador(es) está(ão) anunciado(s)"
    echo "      → Os validadores podem não estar rodando"
    echo "      → Os validadores podem não ter anunciado ainda"
fi

echo ""
echo "3️⃣ Verificando todos os anúncios recentes (não filtrados por validador)..."
echo ""

ALL_ANNOUNCEMENTS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
    "Announcement(address indexed validator, string storageLocation, string[] domains)" \
    --address "$VALIDATOR_ANNOUNCE" \
    --rpc-url "$SEPOLIA_RPC" 2>/dev/null | head -20)

if [ -n "$ALL_ANNOUNCEMENTS" ] && [ "$ALL_ANNOUNCEMENTS" != "" ]; then
    echo "   ✅ Anúncios encontrados:"
    echo "$ALL_ANNOUNCEMENTS" | sed 's/^/      /'
    echo ""
    echo "   💡 Se há anúncios mas não dos validadores do ISM:"
    echo "      → Outros validadores estão rodando"
    echo "      → Mas os validadores do ISM específico não estão"
else
    echo "   ❌ Nenhum anúncio encontrado nos últimos 50000 blocos"
    echo ""
    echo "   ⚠️  Isso pode significar:"
    echo "      → Nenhum validador está rodando no Sepolia"
    echo "      → Ou os anúncios são muito antigos"
fi

echo ""
echo "========================================="
echo "✅ Análise concluída"
echo "========================================="

