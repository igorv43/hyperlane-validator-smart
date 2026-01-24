#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR E CORRIGIR PROBLEMA DE SOL NO SOLANA                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Carregar .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

SOLANA_KEY="${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}"

if [ -z "$SOLANA_KEY" ] || [ "$SOLANA_KEY" = "" ]; then
    echo "❌ HYP_CHAINS_SOLANATESTNET_SIGNER_KEY não encontrada no .env"
    echo ""
    echo "Por favor, adicione a chave privada do Solana no arquivo .env"
    exit 1
fi

echo "✅ Chave do Solana encontrada"
echo ""

# Tentar obter endereço usando múltiplos métodos
ADDRESS=""

# Método 1: solana-keygen
if command -v solana-keygen &> /dev/null; then
    echo "📋 Tentando obter endereço usando solana-keygen..."
    TEMP_KEYFILE=$(mktemp)
    echo "$SOLANA_KEY" > "$TEMP_KEYFILE"
    ADDRESS=$(solana-keygen pubkey "$TEMP_KEYFILE" 2>/dev/null)
    rm -f "$TEMP_KEYFILE"
    
    if [ ! -z "$ADDRESS" ] && [ ${#ADDRESS} -gt 20 ]; then
        echo "✅ Endereço obtido: $ADDRESS"
    else
        ADDRESS=""
    fi
fi

# Método 2: Verificar se já temos o endereço salvo
if [ -z "$ADDRESS" ] && [ -f "/tmp/solana-relayer-address.txt" ]; then
    ADDRESS=$(cat /tmp/solana-relayer-address.txt 2>/dev/null)
    if [ ! -z "$ADDRESS" ]; then
        echo "✅ Endereço encontrado em cache: $ADDRESS"
    fi
fi

# Se ainda não temos o endereço, pedir ao usuário
if [ -z "$ADDRESS" ] || [ ${#ADDRESS} -lt 20 ]; then
    echo "⚠️  Não foi possível obter o endereço automaticamente"
    echo ""
    echo "Por favor, forneça o endereço público do relayer no Solana:"
    read -p "Endereço Solana: " ADDRESS
    
    if [ -z "$ADDRESS" ] || [ ${#ADDRESS} -lt 20 ]; then
        echo "❌ Endereço inválido"
        exit 1
    fi
    
    # Salvar para uso futuro
    echo "$ADDRESS" > /tmp/solana-relayer-address.txt
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 VERIFICANDO SALDO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v solana &> /dev/null; then
    BALANCE_OUTPUT=$(solana balance "$ADDRESS" --url https://api.testnet.solana.com 2>&1)
    
    if echo "$BALANCE_OUTPUT" | grep -q "SOL"; then
        echo "$BALANCE_OUTPUT"
        echo ""
        
        # Extrair valor numérico
        SOL_AMOUNT=$(echo "$BALANCE_OUTPUT" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        
        if [ ! -z "$SOL_AMOUNT" ]; then
            # Usar awk para comparação de float
            NEEDS_FUNDS=$(echo "$SOL_AMOUNT 0.1" | awk '{if ($1 < $2) print "yes"; else print "no"}')
            
            if [ "$NEEDS_FUNDS" = "yes" ]; then
                echo "⚠️  SALDO INSUFICIENTE!"
                echo "   Saldo atual: $SOL_AMOUNT SOL"
                echo "   Recomendado: 0.1 SOL (mínimo)"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🔧 ADICIONAR SOL"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "Execute o seguinte comando para adicionar SOL:"
                echo ""
                echo "  solana transfer $ADDRESS 0.1 --url https://api.testnet.solana.com --allow-unfunded-recipient"
                echo ""
                echo "Ou use uma faucet do Solana testnet:"
                echo "  https://faucet.solana.com/"
                echo ""
                echo "Depois de adicionar SOL, reinicie o relayer:"
                echo "  cd teste-relayer && docker compose -f docker-compose-relayer-only.yml restart relayer"
            else
                echo "✅ SALDO SUFICIENTE: $SOL_AMOUNT SOL"
                echo ""
                echo "Se o problema persistir, verifique:"
                echo "  1. Se a chave privada está correta"
                echo "  2. Se o relayer está usando a chave correta"
                echo "  3. Logs do relayer para outros erros"
            fi
        fi
    else
        echo "⚠️  Erro ao verificar saldo:"
        echo "$BALANCE_OUTPUT"
    fi
else
    echo "⚠️  Solana CLI não está instalado"
    echo ""
    echo "Para verificar saldo, instale o Solana CLI:"
    echo "  sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
    echo ""
    echo "Ou verifique manualmente no explorer:"
    echo "  https://explorer.solana.com/address/$ADDRESS?cluster=testnet"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 RESUMO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Endereço do relayer no Solana: $ADDRESS"
echo "Salvo em: /tmp/solana-relayer-address.txt"
echo ""

