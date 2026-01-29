#!/bin/bash

MESSAGE_ID="0x7a21bc732cadf3a39f4bdd33f0d33b49801e56f876d8998056d86b1e7f482f66"
MESSAGE_ID_SHORT="7a21bc73"

echo "=========================================="
echo "BUSCANDO MESSAGE ID: $MESSAGE_ID"
echo "=========================================="
echo ""

echo "1. Procurando message ID completo nos logs..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "$MESSAGE_ID" | head -20
if [ $? -ne 0 ]; then
    echo "❌ Message ID completo não encontrado nos logs"
fi
echo ""

echo "2. Procurando message ID parcial (primeiros bytes)..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "$MESSAGE_ID_SHORT" | head -20
if [ $? -ne 0 ]; then
    echo "❌ Message ID parcial não encontrado nos logs"
fi
echo ""

echo "3. Procurando mensagens processadas de Solana..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(message|dispatch|deliver|submit)" | grep -i "solana\|1399811150" | tail -20
echo ""

echo "4. Verificando se há mensagens sendo ignoradas pela whitelist..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(whitelist|blacklist|filter|skip)" | tail -10
echo ""

echo "5. Verificando erros de validação de mensagens..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(validation.*fail|invalid.*message|reject|discard)" | tail -10
echo ""

echo "=========================================="
echo "ANÁLISE"
echo "=========================================="
echo ""
echo "Se a mensagem não foi encontrada nos logs, pode ser:"
echo ""
echo "1. ❌ Mensagem foi enviada ANTES do relayer iniciar"
echo "   Solução: O relayer precisa sincronizar desde o início ou desde"
echo "   o bloco onde a mensagem foi enviada"
echo ""
echo "2. ❌ Mensagem foi filtrada pela whitelist"
echo "   Verifique: originDomain, destinationDomain, sender, recipient"
echo ""
echo "3. ❌ Mensagem não tem checkpoints assinados pelos validadores"
echo "   O relayer detecta a mensagem mas não consegue obter checkpoints"
echo "   dos validadores configurados no ISM"
echo ""
echo "4. ✅ Mensagem foi processada com sucesso"
echo "   Verificar se chegou no destino (Terra Classic)"
echo ""
