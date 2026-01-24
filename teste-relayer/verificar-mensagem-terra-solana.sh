#!/bin/bash

TX_HASH="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"
TERRA_CHAIN_ID="rebel-2"
TERRA_RPC="https://rpc.luncblaze.com:443"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR MENSAGEM TERRA CLASSIC -> SOLANA                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Hash da transação: $TX_HASH"
echo ""

# Verificar transação no Terra Classic
echo "🔍 Verificando transação no Terra Classic..."
echo ""

TX_INFO=$(terrad query tx "$TX_HASH" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1)

if echo "$TX_INFO" | grep -qi "error\|not found"; then
    echo "❌ Transação não encontrada ou erro:"
    echo "$TX_INFO"
    exit 1
fi

echo "✅ Transação encontrada!"
echo ""

# Extrair informações da transação
HEIGHT=$(echo "$TX_INFO" | jq -r '.height // "N/A"' 2>/dev/null || echo "N/A")
TIMESTAMP=$(echo "$TX_INFO" | jq -r '.timestamp // "N/A"' 2>/dev/null || echo "N/A")
CODE=$(echo "$TX_INFO" | jq -r '.tx_response.code // "N/A"' 2>/dev/null || echo "N/A")

echo "  Bloco: $HEIGHT"
echo "  Timestamp: $TIMESTAMP"
echo "  Código: $CODE"
echo ""

# Verificar eventos da transação
echo "📊 Eventos da transação:"
echo "$TX_INFO" | jq -r '.tx_response.events[]? | select(.type == "wasm" or .type == "message") | "  \(.type): \(.attributes[]? | select(.key == "action" or .key == "message_id" or .key == "sequence") | "\(.key)=\(.value)")"' 2>/dev/null | head -20

# Procurar por eventos do Hyperlane Mailbox
echo ""
echo "🔍 Eventos do Hyperlane Mailbox:"
echo "$TX_INFO" | jq -r '.tx_response.events[]? | select(.type == "wasm") | .attributes[]? | select(.key == "message_id" or .key == "sequence" or .key == "destination" or .key == "nonce") | "  \(.key): \(.value)"' 2>/dev/null

# Extrair message_id e sequence se disponível
MESSAGE_ID=$(echo "$TX_INFO" | jq -r '.tx_response.events[]? | select(.type == "wasm") | .attributes[]? | select(.key == "message_id") | .value' 2>/dev/null | head -1)
SEQUENCE=$(echo "$TX_INFO" | jq -r '.tx_response.events[]? | select(.type == "wasm") | .attributes[]? | select(.key == "sequence") | .value' 2>/dev/null | head -1)
DESTINATION=$(echo "$TX_INFO" | jq -r '.tx_response.events[]? | select(.type == "wasm") | .attributes[]? | select(.key == "destination") | .value' 2>/dev/null | head -1)

echo ""
if [ ! -z "$MESSAGE_ID" ] && [ "$MESSAGE_ID" != "null" ]; then
    echo "✅ Message ID encontrado: $MESSAGE_ID"
fi
if [ ! -z "$SEQUENCE" ] && [ "$SEQUENCE" != "null" ]; then
    echo "✅ Sequence encontrado: $SEQUENCE"
fi
if [ ! -z "$DESTINATION" ] && [ "$DESTINATION" != "null" ]; then
    echo "✅ Destination encontrado: $DESTINATION"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar se há validators do Terra Classic gerando checkpoints
echo "🔍 Verificando validators do Terra Classic..."
echo ""

# Ler configuração do agent-config
MAILBOX_TERRA=$(grep -A 5 "terraclassictestnet" /home/lunc/hyperlane-validator-smart/hyperlane/agent-config.docker-testnet.json | grep "mailbox" | head -1 | grep -oE '"[^"]+"' | head -1 | tr -d '"')

if [ ! -z "$MAILBOX_TERRA" ]; then
    echo "  Mailbox Terra Classic: $MAILBOX_TERRA"
    
    # Verificar ValidatorAnnounce do Terra Classic
    VALIDATOR_ANNOUNCE_TERRA=$(grep -A 5 "terraclassictestnet" /home/lunc/hyperlane-validator-smart/hyperlane/agent-config.docker-testnet.json | grep "validatorAnnounce" | head -1 | grep -oE '"[^"]+"' | head -1 | tr -d '"')
    
    if [ ! -z "$VALIDATOR_ANNOUNCE_TERRA" ]; then
        echo "  ValidatorAnnounce Terra Classic: $VALIDATOR_ANNOUNCE_TERRA"
        echo ""
        echo "  Consultando validators anunciados..."
        
        # Converter hex para bech32 se necessário
        if [[ "$VALIDATOR_ANNOUNCE_TERRA" == 0x* ]]; then
            # Converter hex para bech32 (precisa de ferramenta de conversão)
            echo "  ⚠️  Endereço em hex, precisa converter para bech32"
        else
            QUERY_VALIDATORS='{"get_announced_validators":{}}'
            RESPONSE=$(terrad query wasm contract-state smart "$VALIDATOR_ANNOUNCE_TERRA" \
                "$QUERY_VALIDATORS" \
                --chain-id "$TERRA_CHAIN_ID" \
                --node "$TERRA_RPC" \
                --output json 2>&1)
            
            if echo "$RESPONSE" | jq -e '.data.validators' > /dev/null 2>&1; then
                VALIDATORS=$(echo "$RESPONSE" | jq -r '.data.validators[]' 2>/dev/null)
                COUNT=$(echo "$VALIDATORS" | wc -l)
                echo "  ✅ $COUNT validator(s) anunciado(s)"
            else
                echo "  ⚠️  Erro ao consultar validators"
            fi
        fi
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar configuração do Solana
echo "🔍 Verificando configuração do Solana..."
echo ""

SOLANA_DOMAIN=$(grep -A 10 "solanatestnet" /home/lunc/hyperlane-validator-smart/hyperlane/agent-config.docker-testnet.json | grep "domain" | head -1 | grep -oE '[0-9]+' | head -1)

if [ ! -z "$SOLANA_DOMAIN" ]; then
    echo "  Domain Solana: $SOLANA_DOMAIN"
fi

echo ""
echo "📊 PRÓXIMOS PASSOS:"
echo "   1. Verificar se há validators do Terra Classic gerando checkpoints"
echo "   2. Verificar se há checkpoints para esta sequence no S3"
echo "   3. Verificar se o relayer está processando mensagens Terra->Solana"
echo "   4. Verificar ISM do Solana para Terra Classic"
echo ""

