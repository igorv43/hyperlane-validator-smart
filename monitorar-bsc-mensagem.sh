#!/bin/bash

if [ -z "$1" ]; then
    echo "❌ Uso: $0 <message_id_ou_primeiros_bytes>"
    echo "Exemplo: $0 0xabc123..."
    echo "Exemplo: $0 abc123"
    exit 1
fi

MESSAGE_ID="$1"
# Remove 0x se existir
MESSAGE_ID_CLEAN="${MESSAGE_ID#0x}"

echo "=========================================="
echo "MONITORANDO MENSAGEM DO BSC"
echo "Message ID: $MESSAGE_ID"
echo "=========================================="
echo ""

echo "1. Procurando message ID nos logs..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "$MESSAGE_ID_CLEAN" | tail -20
if [ $? -ne 0 ]; then
    echo "❌ Message ID não encontrado nos logs ainda"
fi
echo ""

echo "2. Verificando últimas mensagens processadas do BSC..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(dispatch.*bsc|message.*bsc|bsc.*message)" | tail -10
echo ""

echo "3. Verificando sincronização do BSC..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "bsctestnet" | grep -iE "(sequence|block)" | tail -10
echo ""

echo "4. Verificando pool de mensagens..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -i "pool_size" | tail -5
echo ""

echo "5. Verificando se há erros com BSC..."
echo "----------------------------------------"
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(error|fail|warn)" | grep -i "bsc" | tail -10
echo ""

echo "=========================================="
echo "PRÓXIMOS PASSOS"
echo "=========================================="
echo ""
echo "✅ Se a mensagem aparecer nos logs:"
echo "   - Verifique se o relayer está buscando checkpoints"
echo "   - Verifique se submeteu para Terra Classic"
echo ""
echo "❌ Se a mensagem NÃO aparecer:"
echo "   - Verifique se a transação foi confirmada no BSC"
echo "   - Aguarde mais tempo para sincronização"
echo "   - Verifique se o bloco da transação é >= 86149783"
echo ""
echo "Para monitorar em tempo real:"
echo "  docker logs hpl-relayer-testnet -f | grep -iE \"(bsc|$MESSAGE_ID_CLEAN)\""
echo ""
