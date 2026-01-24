#!/bin/bash

TX_HASH="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"
TERRA_CHAIN_ID="rebel-2"
TERRA_RPC="https://rpc.luncblaze.com:443"
SOLANA_RPC="https://api.testnet.solana.com"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR MENSAGEM TERRA CLASSIC -> SOLANA                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Hash fornecido: $TX_HASH"
echo "   (Parece ser um hash do Solana - base58)"
echo ""

# Verificar no Solana primeiro
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verificando no Solana..."
echo ""

if command -v solana &> /dev/null; then
    SOLANA_TX=$(solana confirm "$TX_HASH" --url "$SOLANA_RPC" 2>&1)
    echo "$SOLANA_TX"
    
    if echo "$SOLANA_TX" | grep -qi "not found\|error"; then
        echo "  ⚠️  Transação não encontrada no Solana"
    else
        echo "  ✅ Transação encontrada no Solana"
    fi
else
    # Usar curl para verificar via RPC
    SOLANA_TX_JSON=$(curl -s -X POST "$SOLANA_RPC" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTransaction\",\"params\":[\"$TX_HASH\",{\"encoding\":\"json\",\"maxSupportedTransactionVersion\":0}]}" 2>&1)
    
    if echo "$SOLANA_TX_JSON" | jq -e '.result' > /dev/null 2>&1; then
        echo "  ✅ Transação encontrada no Solana"
        SLOT=$(echo "$SOLANA_TX_JSON" | jq -r '.result.slot // "N/A"' 2>/dev/null)
        BLOCK_TIME=$(echo "$SOLANA_TX_JSON" | jq -r '.result.blockTime // "N/A"' 2>/dev/null)
        echo "     Slot: $SLOT"
        echo "     Block Time: $BLOCK_TIME"
    else
        echo "  ⚠️  Transação não encontrada no Solana"
        echo "     Resposta: $(echo "$SOLANA_TX_JSON" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Buscando transação correspondente no Terra Classic..."
echo ""

# Buscar eventos recentes do Mailbox no Terra Classic
MAILBOX_TERRA="terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml"

echo "  Mailbox Terra Classic: $MAILBOX_TERRA"
echo "  Buscando eventos recentes do Mailbox..."
echo ""

# Obter bloco atual
CURRENT_HEIGHT=$(terrad query block --node "$TERRA_RPC" --chain-id "$TERRA_CHAIN_ID" 2>/dev/null | grep -oE '"height":"[0-9]+"' | head -1 | grep -oE '[0-9]+' || echo "")

if [ ! -z "$CURRENT_HEIGHT" ]; then
    echo "  Bloco atual: $CURRENT_HEIGHT"
    
    # Buscar eventos dos últimos 1000 blocos
    FROM_HEIGHT=$((CURRENT_HEIGHT - 1000))
    echo "  Buscando eventos do bloco $FROM_HEIGHT ao $CURRENT_HEIGHT..."
    
    # Buscar eventos do Mailbox
    EVENTS=$(terrad query txs \
        --events "wasm._contract_address='$MAILBOX_TERRA'" \
        --node "$TERRA_RPC" \
        --chain-id "$TERRA_CHAIN_ID" \
        --limit 10 \
        --output json 2>&1)
    
    if echo "$EVENTS" | jq -e '.txs' > /dev/null 2>&1; then
        COUNT=$(echo "$EVENTS" | jq '.txs | length' 2>/dev/null || echo "0")
        echo "  ✅ Encontradas $COUNT transações recentes do Mailbox"
        
        # Mostrar últimas transações
        echo ""
        echo "  📋 Últimas transações do Mailbox:"
        echo "$EVENTS" | jq -r '.txs[]? | "    - Hash: \(.txhash) | Height: \(.height)"' 2>/dev/null | head -5
    else
        echo "  ⚠️  Erro ao buscar eventos: $(echo "$EVENTS" | head -3)"
    fi
else
    echo "  ⚠️  Não foi possível obter o bloco atual"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verificando validators do Terra Classic..."
echo ""

# ValidatorAnnounce do Terra Classic
VALIDATOR_ANNOUNCE_TERRA_HEX="0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"
VALIDATOR_ANNOUNCE_TERRA_BECH32="terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5"

echo "  ValidatorAnnounce: $VALIDATOR_ANNOUNCE_TERRA_BECH32"
echo ""

QUERY_VALIDATORS='{"get_announced_validators":{}}'
RESPONSE=$(terrad query wasm contract-state smart "$VALIDATOR_ANNOUNCE_TERRA_BECH32" \
    "$QUERY_VALIDATORS" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1)

if echo "$RESPONSE" | jq -e '.data.validators' > /dev/null 2>&1; then
    VALIDATORS=$(echo "$RESPONSE" | jq -r '.data.validators[]' 2>/dev/null)
    COUNT=$(echo "$VALIDATORS" | wc -l)
    echo "  ✅ $COUNT validator(s) anunciado(s) no Terra Classic:"
    echo "$VALIDATORS" | while read -r VAL; do
        echo "    • $VAL"
    done
else
    echo "  ⚠️  Erro ao consultar validators: $(echo "$RESPONSE" | head -3)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 PRÓXIMOS PASSOS:"
echo ""
echo "   1. Verificar se há validators do Terra Classic gerando checkpoints"
echo "   2. Verificar se há checkpoints no S3 para mensagens Terra->Solana"
echo "   3. Verificar se o relayer está processando mensagens Terra->Solana"
echo "   4. Verificar ISM do Solana para Terra Classic (domain 1325)"
echo ""

