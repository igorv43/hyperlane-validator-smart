#!/bin/bash

echo "=========================================="
echo "VERIFICANDO ISM NO CONTRATO SOLANA"
echo "=========================================="
echo ""

WARP_ROUTE="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"
TOKEN_MINT="3yhG9dDHVX6K1duf8znEcaJcuTiKSLYvfBD4xy6akxfu"
MAILBOX="75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR"
TERRA_DOMAIN="1325"
SOLANA_DOMAIN="1399811150"

echo "📋 Informações do Warp Route Solana:"
echo "----------------------------------------"
echo "Warp Route (Programa): $WARP_ROUTE"
echo "Token Mint: $TOKEN_MINT"
echo "Mailbox Solana: $MAILBOX"
echo "Terra Domain: $TERRA_DOMAIN"
echo "Solana Domain: $SOLANA_DOMAIN"
echo ""

echo "1. Verificando se o relayer detecta mensagens de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "solanatestnet" | grep -iE "(message|dispatch|nonce)" | tail -15
echo ""

echo "2. Verificando se o relayer está processando mensagens para Terra Classic..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -E "destination.*1325|domain.*1325" | tail -15
echo ""

echo "3. Verificando se há erros de ISM ou validadores..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(ism|validator|security.*module)" | grep -iE "(error|fail|not.*found|unable)" | tail -15
echo ""

echo "4. Verificando se o relayer está tentando entregar mensagens..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(deliver|relay|submit|process.*message)" | grep -i "1399811150\|solana" | tail -15
echo ""

echo "5. Verificando se há mensagens aguardando na fila..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(pool|queue|pending)" | tail -10
echo ""

echo "6. Verificando logs mais recentes do relayer..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | tail -30
echo ""

echo "=========================================="
echo "VERIFICAÇÃO CONCLUÍDA"
echo "=========================================="
echo ""
echo "📋 Se não houver mensagens sendo processadas:"
echo ""
echo "1. Verifique se há mensagens pendentes de Solana no mailbox"
echo "2. Verifique se o ISM configurado no warp route tem validadores ativos"
echo "3. Verifique se o relayer consegue acessar os checkpoints dos validadores do ISM"
echo "4. Verifique os logs para erros específicos de validação de ISM"
echo ""
