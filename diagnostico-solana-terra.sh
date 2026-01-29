#!/bin/bash

echo "=========================================="
echo "DIAGNÓSTICO: Solana -> Terra Classic / BSC"
echo "=========================================="
echo ""

echo "1. Verificando configuração do relayer..."
echo "----------------------------------------"
docker exec hpl-relayer-testnet cat /etc/hyperlane/relayer.testnet.json | jq '.whitelist' 2>/dev/null || echo "Erro ao ler configuração"
echo ""

echo "2. Verificando se Solana está nas chains do relayer..."
echo "----------------------------------------"
docker exec hpl-relayer-testnet cat /etc/hyperlane/relayer.testnet.json | jq '.relayChains' 2>/dev/null || echo "Erro ao ler relayChains"
echo ""

echo "3. Verificando logs de mensagens de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "solanatestnet" | grep -iE "(message|checkpoint|deliver)" | tail -10
echo ""

echo "4. Verificando se há checkpoints de Solana sendo procurados..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(checkpoint.*1399811150|1399811150.*checkpoint|solana.*checkpoint)" | tail -10
echo ""

echo "5. Verificando validadores anunciados para Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(validator.*announce|announce.*solana)" | tail -10
echo ""

echo "6. Verificando erros relacionados a Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "solana" | grep -iE "(error|warn|fail)" | tail -10
echo ""

echo "7. Verificando pool de mensagens de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "solanatestnet" | grep -iE "(pool|processing)" | tail -10
echo ""

echo "8. Verificando configuração de checkpoint syncer..."
echo "----------------------------------------"
docker exec hpl-relayer-testnet cat /etc/hyperlane/relayer.testnet.json | jq '.allowLocalCheckpointSyncers' 2>/dev/null || echo "Erro ao ler configuração"
echo ""

echo "=========================================="
echo "DIAGNÓSTICO CONCLUÍDO"
echo "=========================================="
