#!/bin/bash

echo "==========================================="
echo "VERIFICANDO SE MENSAGEM ESTÁ NO DATABASE"
echo "==========================================="
echo ""

echo "Transaction ID da mensagem 49:"
echo "027503918779c0b4631f8dceeceafee8f39b3799325ef818f4bd73bc3e682845"
echo ""

echo "1. Verificando logs do relayer em tempo real..."
echo "-------------------------------------------"
docker logs hpl-relayer-testnet --since 2m | grep -i "destination.*97\|destinationDomain.*97" | head -10

echo ""
echo "2. Verificando se há mensagens pendentes..."
echo "-------------------------------------------"
docker logs hpl-relayer-testnet --since 2m | grep "pool_size" | tail -5

echo ""
echo "3. Verificando se há erros de parsing..."
echo "-------------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(parse.*error|failed.*parse)" | tail -10

echo ""
echo "4. Verificando se há validadores configurados para BSC..."
echo "-------------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "validator" | grep -i "bsc\|97" | tail -10

echo ""
echo "==========================================="
echo "DIAGNÓSTICO"
echo "==========================================="
echo ""
echo "Se não houver mensagens para destination 97 (BSC), o problema pode ser:"
echo ""
echo "1. ❌ O evento Dispatch não foi emitido corretamente pelo contrato"
echo "2. ❌ O relayer não está conseguindo parsear o evento Dispatch"
echo "3. ❌ A mensagem foi filtrada (mas whitelist está correta)"
echo "4. ❌ Não há validadores configurados/ativos para validar mensagens de Terra"
echo ""
echo "SOLUÇÃO: Verificar se o contrato do warp route emitiu o evento Dispatch"
echo "         na transação do Terra Classic."
echo ""
