#!/bin/bash

echo "========================================="
echo "🔍 VERIFICAÇÃO DETALHADA DE ISM E CHECKPOINTS"
echo "========================================="
echo ""

SEPOLIA_RPC="https://1rpc.io/sepolia"
MAILBOX_SEPOLIA="0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766"
MESSAGE_ID="0x0a067dda3182caf21401732b58dc2a34c796bbb8a3e01ed398cf8942bf78edfa"

# 1. Verificar ISM do mailbox
echo "1️⃣ Verificando ISM do Mailbox Sepolia..."
ISM=$(cast call "$MAILBOX_SEPOLIA" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')

if [ -n "$ISM" ] && [ "$ISM" != "0x0000000000000000000000000000000000000000" ]; then
    echo "   ✅ ISM: $ISM"
    
    # Verificar se é um DomainRoutingISM
    echo ""
    echo "2️⃣ Verificando tipo de ISM..."
    
    # Tentar obter o ISM para o domínio 1325 (Terra Classic)
    ISM_FOR_DOMAIN=$(cast call "$ISM" "module(uint32)(address)" "1325" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_DOMAIN" ] && [ "$ISM_FOR_DOMAIN" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   ✅ ISM para Terra Classic (1325): $ISM_FOR_DOMAIN"
        ACTUAL_ISM="$ISM_FOR_DOMAIN"
    else
        echo "   ⚠️  Não é DomainRoutingISM ou não encontrado, usando ISM principal"
        ACTUAL_ISM="$ISM"
    fi
    
    echo ""
    echo "3️⃣ Verificando validadores no ISM: $ACTUAL_ISM"
    
    # Tentar diferentes métodos para obter validadores
    # Método 1: validators()
    VALIDATORS1=$(cast call "$ACTUAL_ISM" "validators()(address[])" --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
    
    # Método 2: validatorCount() e depois validatorAt(index)
    VALIDATOR_COUNT=$(cast call "$ACTUAL_ISM" "validatorCount()(uint256)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$VALIDATORS1" ] && [ "$VALIDATORS1" != "0x" ]; then
        echo "   ✅ Validadores encontrados (método validators()):"
        echo "$VALIDATORS1" | sed 's/^/      /'
    elif [ -n "$VALIDATOR_COUNT" ] && [ "$VALIDATOR_COUNT" != "0" ] && [ "$VALIDATOR_COUNT" != "0x0" ]; then
        echo "   ✅ Número de validadores: $VALIDATOR_COUNT"
        echo "   Buscando validadores individuais..."
        for i in $(seq 0 $((VALIDATOR_COUNT - 1))); do
            VAL=$(cast call "$ACTUAL_ISM" "validatorAt(uint256)(address)" "$i" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
            if [ -n "$VAL" ]; then
                echo "      [$i] $VAL"
            fi
        done
    else
        echo "   ⚠️  Não foi possível obter validadores diretamente do ISM"
        echo "   ISM pode ser de outro tipo (MessageIdMultisig, MerkleRootMultisig, etc.)"
    fi
    
    # Verificar threshold
    echo ""
    echo "4️⃣ Verificando threshold..."
    THRESHOLD=$(cast call "$ACTUAL_ISM" "threshold()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" != "0x" ]; then
        echo "   ✅ Threshold: $THRESHOLD"
    else
        echo "   ⚠️  Threshold não encontrado ou ISM não é multisig"
    fi
    
else
    echo "   ❌ ISM não encontrado"
    exit 1
fi

echo ""
echo "5️⃣ Verificando validadores anunciados no ValidatorAnnounce..."
VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"

# Buscar eventos de anúncio recentes
echo "   Buscando eventos de anúncio (últimos 1000 blocos)..."
LATEST_BLOCK=$(cast block-number --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 1000))

ANNOUNCEMENTS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
  "Announcement(address indexed validator, string storageLocation, string[] domains)" \
  --address "$VALIDATOR_ANNOUNCE" \
  --rpc-url "$SEPOLIA_RPC" 2>/dev/null)

if [ -n "$ANNOUNCEMENTS" ]; then
    echo "   ✅ Anúncios encontrados:"
    echo "$ANNOUNCEMENTS" | head -20 | sed 's/^/      /'
else
    echo "   ⚠️  Nenhum anúncio encontrado nos últimos 1000 blocos"
fi

echo ""
echo "6️⃣ Verificando logs do relayer para erros de checkpoint..."
echo ""

# Buscar erros específicos relacionados a quorum ou checkpoint
QUORUM_ERRORS=$(docker logs hpl-relayer-testnet 2>&1 | grep -iE "unable to reach quorum|could not fetch metadata|checkpoint" | tail -5)

if [ -n "$QUORUM_ERRORS" ]; then
    echo "   ⚠️  Erros encontrados:"
    echo "$QUORUM_ERRORS" | sed 's/^/      /'
    echo ""
    echo "   💡 Isso indica que o relayer não consegue obter checkpoints suficientes"
    echo "      dos validadores para formar o quorum necessário."
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "💡 PRÓXIMOS PASSOS:"
echo "   1. Verifique se os validadores estão rodando e criando checkpoints"
echo "   2. Verifique se os checkpoints estão acessíveis (S3 ou local)"
echo "   3. Verifique se o threshold do ISM está sendo atingido"
echo "   4. Se usar S3, verifique se o relayer tem acesso de leitura"

