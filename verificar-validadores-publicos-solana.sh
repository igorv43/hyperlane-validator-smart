#!/bin/bash

echo "=========================================="
echo "VERIFICANDO VALIDADORES PÚBLICOS DE SOLANA"
echo "=========================================="
echo ""

# Informações do Solana Testnet
SOLANA_VALIDATOR_ANNOUNCE="8qNYSi9EP1xSnRjtMpyof88A26GBbdcrsa61uSaHiwx3"
SOLANA_MAILBOX="75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR"
TERRA_DOMAIN="1325"

echo "1. Configuração do Solana Testnet:"
echo "----------------------------------------"
echo "ValidatorAnnounce: $SOLANA_VALIDATOR_ANNOUNCE"
echo "Mailbox: $SOLANA_MAILBOX"
echo "Terra Classic Domain: $TERRA_DOMAIN"
echo ""

echo "2. Verificando logs do relayer para validadores anunciados..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(validator.*announce|announce.*validator|fetching.*validator)" | tail -20
echo ""

echo "3. Verificando se o relayer está procurando checkpoints de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(checkpoint.*solana|solana.*checkpoint|domain.*1399811150)" | tail -20
echo ""

echo "4. Verificando configuração do ISM no agent-config..."
echo "----------------------------------------"
docker exec hpl-relayer-testnet cat /app/config/agent-config.json | jq '.chains.terraclassictestnet.interchainSecurityModule' 2>/dev/null
echo ""

echo "5. Verificando configuração do ISM no agent-config para Solana..."
echo "----------------------------------------"
docker exec hpl-relayer-testnet cat /app/config/agent-config.json | jq '.chains.solanatestnet.interchainSecurityModule' 2>/dev/null
echo ""

echo "6. Verificando se há mensagens pendentes de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "solanatestnet" | grep -iE "(dispatched|message|nonce)" | tail -20
echo ""

echo "7. Verificando erros relacionados a checkpoints..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(checkpoint.*error|checkpoint.*fail|checkpoint.*not.*found)" | tail -10
echo ""

echo "8. Verificando se o relayer está tentando buscar checkpoints do S3..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(s3|bucket|checkpoint.*fetch)" | tail -15
echo ""

echo "=========================================="
echo "VERIFICAÇÃO CONCLUÍDA"
echo "=========================================="
echo ""
echo "📋 Próximos passos:"
echo ""
echo "Se não houver validadores anunciados:"
echo "  → Verificar documentação do Hyperlane: https://docs.hyperlane.xyz"
echo "  → Verificar lista de validadores: https://github.com/hyperlane-xyz/hyperlane-registry"
echo ""
echo "Se houver validadores mas não estão funcionando:"
echo "  → Verificar configuração do ISM"
echo "  → Verificar se o relayer tem acesso aos checkpoints dos validadores"
echo ""
