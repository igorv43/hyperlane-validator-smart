#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  OBTER ENDEREÇO DO RELAYER NO SOLANA E VERIFICAR SALDO                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se há variável de ambiente
if [ -f "../.env" ]; then
    export $(grep -v '^#' ../.env | xargs)
fi

SOLANA_KEY="${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}"

if [ -z "$SOLANA_KEY" ] || [ "$SOLANA_KEY" = "" ]; then
    echo "❌ HYP_CHAINS_SOLANATESTNET_SIGNER_KEY não está definida no .env"
    echo ""
    echo "Por favor, adicione a chave privada do Solana no arquivo .env:"
    echo "  HYP_CHAINS_SOLANATESTNET_SIGNER_KEY=your_private_key_here"
    exit 1
fi

echo "✅ Chave do Solana encontrada"
echo ""

# Tentar obter endereço público usando solana-keygen ou python
if command -v solana-keygen &> /dev/null; then
    echo "📋 Obtendo endereço público da chave privada..."
    # Criar arquivo temporário com a chave
    TEMP_KEYFILE=$(mktemp)
    echo "$SOLANA_KEY" > "$TEMP_KEYFILE"
    
    # Tentar obter o endereço
    ADDRESS=$(solana-keygen pubkey "$TEMP_KEYFILE" 2>/dev/null)
    rm -f "$TEMP_KEYFILE"
    
    if [ ! -z "$ADDRESS" ]; then
        echo "✅ Endereço do relayer no Solana: $ADDRESS"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 Verificando saldo..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        BALANCE=$(solana balance "$ADDRESS" --url https://api.testnet.solana.com 2>/dev/null)
        
        if [ ! -z "$BALANCE" ]; then
            echo "$BALANCE"
            echo ""
            
            # Extrair valor numérico
            SOL_AMOUNT=$(echo "$BALANCE" | grep -oE '[0-9]+\.[0-9]+' | head -1)
            
            if [ ! -z "$SOL_AMOUNT" ]; then
                # Comparar com 0.1 (mínimo recomendado)
                if (( $(echo "$SOL_AMOUNT < 0.1" | bc -l) )); then
                    echo "⚠️  ATENÇÃO: Saldo insuficiente!"
                    echo "   Saldo atual: $SOL_AMOUNT SOL"
                    echo "   Recomendado: 0.1 SOL (mínimo)"
                    echo ""
                    echo "🔧 Para adicionar SOL:"
                    echo "   solana transfer $ADDRESS 0.1 --url https://api.testnet.solana.com"
                else
                    echo "✅ Saldo suficiente: $SOL_AMOUNT SOL"
                fi
            fi
        else
            echo "⚠️  Não foi possível verificar saldo"
        fi
    else
        echo "⚠️  Não foi possível obter endereço da chave"
        echo ""
        echo "💡 Alternativa: Use a chave privada diretamente para obter o endereço"
        echo "   ou verifique se a chave está no formato correto"
    fi
else
    echo "⚠️  solana-keygen não está disponível"
    echo ""
    echo "💡 Para obter o endereço, você pode:"
    echo "   1. Usar solana-keygen pubkey <keyfile>"
    echo "   2. Usar uma ferramenta online de conversão"
    echo "   3. Verificar nos logs do relayer"
fi

echo ""

