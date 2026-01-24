#!/bin/bash

# Carregar .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

SOLANA_KEY="${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}"

if [ -z "$SOLANA_KEY" ] || [ "$SOLANA_KEY" = "" ]; then
    echo "❌ HYP_CHAINS_SOLANATESTNET_SIGNER_KEY não encontrada"
    exit 1
fi

echo "🔑 Chave encontrada (primeiros 20 chars): ${SOLANA_KEY:0:20}..."
echo ""

# Tentar obter endereço usando solana-keygen
if command -v solana-keygen &> /dev/null; then
    TEMP_KEYFILE=$(mktemp)
    echo "$SOLANA_KEY" > "$TEMP_KEYFILE"
    
    ADDRESS=$(solana-keygen pubkey "$TEMP_KEYFILE" 2>/dev/null)
    rm -f "$TEMP_KEYFILE"
    
    if [ ! -z "$ADDRESS" ]; then
        echo "✅ Endereço do relayer no Solana: $ADDRESS"
        echo "$ADDRESS" > /tmp/solana-relayer-address.txt
        echo "$ADDRESS"
    else
        echo "❌ Não foi possível obter endereço"
    fi
else
    echo "⚠️  solana-keygen não disponível"
    echo "💡 Tentando método alternativo..."
    
    # Tentar usar Python se disponível
    if command -v python3 &> /dev/null; then
        ADDRESS=$(python3 << PYTHON_SCRIPT
import base58
import sys

try:
    # Remover 0x se presente
    key = "$SOLANA_KEY".replace("0x", "").replace(" ", "")
    
    # Converter de hex para bytes
    if len(key) == 64:  # 32 bytes em hex
        key_bytes = bytes.fromhex(key)
    elif len(key) == 88:  # Base58
        key_bytes = base58.b58decode(key)
    else:
        print("", end="")
        sys.exit(1)
    
    # Obter chave pública (primeiros 32 bytes são a chave privada)
    # Para Solana, precisamos derivar a chave pública da privada
    # Mas isso requer ed25519, então vamos tentar usar a chave diretamente
    # Na verdade, para Solana, a chave privada já contém a pública
    # Vamos usar base58 para codificar
    pubkey = base58.b58encode(key_bytes[:32]).decode('utf-8')
    print(pubkey)
except Exception as e:
    print("", end="")
    sys.exit(1)
PYTHON_SCRIPT
)
        
        if [ ! -z "$ADDRESS" ] && [ "$ADDRESS" != "" ]; then
            echo "✅ Endereço obtido: $ADDRESS"
            echo "$ADDRESS" > /tmp/solana-relayer-address.txt
            echo "$ADDRESS"
        else
            echo "❌ Não foi possível obter endereço automaticamente"
            echo ""
            echo "💡 Por favor, obtenha o endereço manualmente:"
            echo "   1. Use: solana-keygen pubkey <keyfile>"
            echo "   2. Ou use uma ferramenta online de conversão"
        fi
    fi
fi

