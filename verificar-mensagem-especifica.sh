#!/bin/bash

echo "=========================================="
echo "VERIFICANDO MENSAGEM ESPECÍFICA DE SOLANA"
echo "=========================================="
echo ""

DESTINATARIO="terra18lr7ujd9nsgyr49930ppaajhadzrezam70j39k"
WARP_ROUTE="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"
MAILBOX="75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR"

echo "📋 Informações:"
echo "----------------------------------------"
echo "Destinatário Terra Classic: $DESTINATARIO"
echo "Warp Route Solana: $WARP_ROUTE"
echo "Mailbox Solana: $MAILBOX"
echo ""

echo "1. Verificando última sequence processada de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep "solanatestnet" | grep -iE "sequence|nonce" | tail -5
echo ""

echo "2. Verificando se há mensagens sendo indexadas de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep "solanatestnet" | grep -iE "(dispatched|num_logs)" | tail -10
echo ""

echo "3. Verificando range de blocos sendo sincronizados..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep "solanatestnet" | grep -iE "range|block" | tail -5
echo ""

echo "4. Informações sobre sincronização de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -E "HyperlaneDomain\(solanatestnet" | tail -5
echo ""

echo "=========================================="
echo "O QUE VERIFICAR:"
echo "=========================================="
echo ""
echo "1. Se a última sequence de Solana é menor que a sequence da sua mensagem,"
echo "   significa que o relayer ainda não chegou nela."
echo ""
echo "2. Se não houver mensagens sendo detectadas (num_logs: 0), significa:"
echo "   - A mensagem foi enviada antes do relayer iniciar E"
echo "   - O relayer começou a sincronizar de um bloco posterior, OU"
echo "   - A mensagem não foi enviada através do mailbox correto"
echo ""
echo "3. Para verificar sua transação específica, você precisa:"
echo "   - Acessar o Solana Explorer"
echo "   - Verificar a transação de envio"
echo "   - Confirmar que foi enviada através do mailbox: $MAILBOX"
echo "   - Verificar o nonce/sequence da mensagem"
echo ""
echo "4. Se a mensagem já foi processada:"
echo "   - Verificar na chain Terra Classic se chegou"
echo "   - Verificar logs do relayer para mensagens já entregues"
echo ""
