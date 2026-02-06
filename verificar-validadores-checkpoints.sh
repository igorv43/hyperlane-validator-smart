#!/bin/bash

echo "========================================="
echo "🔍 VERIFICAÇÃO DE VALIDADORES E CHECKPOINTS"
echo "========================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configurações
SEPOLIA_RPC="https://1rpc.io/sepolia"
VALIDATOR_ANNOUNCE_SEPOLIA="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
MESSAGE_ID="0x0a067dda3182caf21401732b58dc2a34c796bbb8a3e01ed398cf8942bf78edfa"
SEQUENCE="865851"
ORIGIN_DOMAIN="11155111"  # Sepolia
DESTINATION_DOMAIN="1325"  # Terra Classic

echo "📋 Informações da Mensagem:"
echo "   Message ID: $MESSAGE_ID"
echo "   Sequência: $SEQUENCE"
echo "   Origem: Sepolia ($ORIGIN_DOMAIN)"
echo "   Destino: Terra Classic ($DESTINATION_DOMAIN)"
echo ""

# 1. Verificar validadores anunciados no Sepolia
echo "1️⃣ Verificando validadores anunciados no Sepolia..."
echo "   Contrato: $VALIDATOR_ANNOUNCE_SEPOLIA"
echo ""

# Tentar obter eventos de anúncio
echo "   Buscando eventos de anúncio..."
ANNOUNCED=$(cast logs --from-block 10180000 --to-block latest \
  "Announcement(address indexed validator, string storageLocation, string[] domains)" \
  --address "$VALIDATOR_ANNOUNCE_SEPOLIA" \
  --rpc-url "$SEPOLIA_RPC" 2>/dev/null | head -20)

if [ -n "$ANNOUNCED" ]; then
    echo -e "${GREEN}✅ Validadores encontrados:${NC}"
    echo "$ANNOUNCED"
else
    echo -e "${RED}❌ Nenhum validador encontrado ou erro ao buscar${NC}"
fi

echo ""

# 2. Verificar ISM configurado
echo "2️⃣ Verificando ISM configurado para Sepolia → Terra Classic..."
MAILBOX_SEPOLIA="0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766"

# Obter ISM do mailbox
ISM=$(cast call "$MAILBOX_SEPOLIA" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null)

if [ -n "$ISM" ] && [ "$ISM" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}✅ ISM encontrado: $ISM${NC}"
    
    # Verificar tipo de ISM
    echo "   Verificando tipo de ISM..."
    
    # Tentar obter validadores do ISM (se for multisig)
    VALIDATORS=$(cast call "$ISM" "validators()(address[])" --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
    if [ -n "$VALIDATORS" ]; then
        echo -e "${GREEN}   Validadores no ISM:${NC}"
        echo "$VALIDATORS"
    fi
    
    # Verificar threshold
    THRESHOLD=$(cast call "$ISM" "threshold()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null)
    if [ -n "$THRESHOLD" ]; then
        echo "   Threshold necessário: $THRESHOLD"
    fi
else
    echo -e "${RED}❌ ISM não encontrado ou não configurado${NC}"
fi

echo ""

# 3. Verificar logs do relayer para problemas de checkpoint
echo "3️⃣ Verificando logs do relayer para problemas de checkpoint/metadata..."
echo ""

# Buscar erros relacionados a checkpoint ou metadata
CHECKPOINT_ERRORS=$(docker logs hpl-relayer-testnet 2>&1 | grep -iE "checkpoint|metadata|quorum|unable to reach" | tail -10)

if [ -n "$CHECKPOINT_ERRORS" ]; then
    echo -e "${YELLOW}⚠️  Problemas encontrados nos logs:${NC}"
    echo "$CHECKPOINT_ERRORS"
else
    echo -e "${GREEN}✅ Nenhum erro de checkpoint encontrado nos logs recentes${NC}"
fi

echo ""

# 4. Verificar se o relayer está tentando processar a mensagem
echo "4️⃣ Verificando se o relayer está processando a mensagem..."
echo ""

MESSAGE_LOGS=$(docker logs hpl-relayer-testnet 2>&1 | grep -iE "$SEQUENCE|0a067dda" | tail -10)

if [ -n "$MESSAGE_LOGS" ]; then
    echo -e "${GREEN}✅ Logs encontrados para a mensagem:${NC}"
    echo "$MESSAGE_LOGS"
else
    echo -e "${YELLOW}⚠️  Nenhum log específico encontrado para esta mensagem${NC}"
fi

echo ""

# 5. Verificar configuração do relayer para checkpoints
echo "5️⃣ Verificando configuração do relayer..."
echo ""

if [ -f "hyperlane/relayer.testnet.json" ]; then
    ALLOW_LOCAL=$(jq -r '.allowLocalCheckpointSyncers // "not set"' hyperlane/relayer.testnet.json 2>/dev/null)
    echo "   allowLocalCheckpointSyncers: $ALLOW_LOCAL"
    
    if [ "$ALLOW_LOCAL" = "false" ]; then
        echo -e "${GREEN}   ✅ Relayer configurado para usar checkpoints externos (S3)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Relayer pode estar usando checkpoints locais${NC}"
    fi
else
    echo -e "${RED}   ❌ Arquivo de configuração não encontrado${NC}"
fi

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="

