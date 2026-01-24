#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  SOLUÇÃO FINAL: ADICIONAR SOL AO RELAYER                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Carregar .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

SOLANA_KEY="${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}"

if [ -z "$SOLANA_KEY" ]; then
    echo "❌ Chave do Solana não encontrada no .env"
    exit 1
fi

echo "✅ Chave do Solana encontrada"
echo ""

# Tentar obter endereço de múltiplas formas
ADDRESS=""

# Método 1: Verificar se já temos salvo
if [ -f "/tmp/solana-relayer-address.txt" ]; then
    ADDRESS=$(cat /tmp/solana-relayer-address.txt 2>/dev/null)
    if [ ! -z "$ADDRESS" ] && [ ${#ADDRESS} -gt 20 ]; then
        echo "✅ Endereço encontrado em cache: $ADDRESS"
    else
        ADDRESS=""
    fi
fi

# Método 2: Tentar criar keypair temporário e obter endereço
if [ -z "$ADDRESS" ] && command -v solana-keygen &> /dev/null; then
    echo "📋 Tentando obter endereço usando solana-keygen..."
    
    # Limpar chave (remover 0x)
    CLEAN_KEY=$(echo "$SOLANA_KEY" | sed 's/^0x//' | tr -d ' ' | tr -d '"' | tr -d "'")
    
    if [ ${#CLEAN_KEY} -eq 64 ]; then
        # Converter hex para binário
        echo "$CLEAN_KEY" | xxd -r -p > /tmp/solana_seed_temp.bin 2>/dev/null
        
        if [ -f "/tmp/solana_seed_temp.bin" ]; then
            # Criar keypair a partir do seed
            solana-keygen new --no-bip39-passphrase --force --seed /tmp/solana_seed_temp.bin --outfile /tmp/solana_temp_keypair.json 2>/dev/null
            
            if [ -f "/tmp/solana_temp_keypair.json" ]; then
                ADDRESS=$(solana-keygen pubkey /tmp/solana_temp_keypair.json 2>/dev/null)
                
                if [ ! -z "$ADDRESS" ] && [ ${#ADDRESS} -gt 20 ]; then
                    echo "✅ Endereço obtido: $ADDRESS"
                    echo "$ADDRESS" > /tmp/solana-relayer-address.txt
                fi
                
                # Limpar
                rm -f /tmp/solana_temp_keypair.json
            fi
            
            rm -f /tmp/solana_seed_temp.bin
        fi
    fi
fi

# Se ainda não temos, pedir ao usuário
if [ -z "$ADDRESS" ] || [ ${#ADDRESS} -lt 20 ]; then
    echo ""
    echo "⚠️  Não foi possível obter o endereço automaticamente"
    echo ""
    echo "Por favor, obtenha o endereço manualmente:"
    echo "  1. Use: solana-keygen pubkey <keypair.json>"
    echo "  2. Ou use uma ferramenta online"
    echo ""
    read -p "Digite o endereço do relayer no Solana: " ADDRESS
    
    if [ -z "$ADDRESS" ] || [ ${#ADDRESS} -lt 20 ]; then
        echo "❌ Endereço inválido"
        exit 1
    fi
    
    echo "$ADDRESS" > /tmp/solana-relayer-address.txt
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 VERIFICANDO SALDO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v solana &> /dev/null; then
    BALANCE=$(solana balance "$ADDRESS" --url https://api.testnet.solana.com 2>&1)
    
    if echo "$BALANCE" | grep -q "SOL"; then
        echo "$BALANCE"
        echo ""
        
        SOL_AMOUNT=$(echo "$BALANCE" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        
        if [ ! -z "$SOL_AMOUNT" ]; then
            NEEDS_FUNDS=$(echo "$SOL_AMOUNT 0.1" | awk '{if ($1 < $2) print "yes"; else print "no"}')
            
            if [ "$NEEDS_FUNDS" = "yes" ]; then
                echo "⚠️  SALDO INSUFICIENTE: $SOL_AMOUNT SOL"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🔧 ADICIONAR SOL"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "Opção 1: Usar faucet do Solana testnet"
                echo "  https://faucet.solana.com/"
                echo "  Endereço: $ADDRESS"
                echo ""
                echo "Opção 2: Transferir de outra conta"
                echo "  solana transfer $ADDRESS 0.1 --url https://api.testnet.solana.com --allow-unfunded-recipient"
                echo ""
                echo "Depois de adicionar SOL, execute:"
                echo "  cd teste-relayer && docker compose -f docker-compose-relayer-only.yml restart relayer"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📋 MONITORAR LOGS"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "Após adicionar SOL, monitore os logs:"
                echo "  docker logs -f hpl-relayer-testnet-local | grep -i 'solana\|insufficient\|rent'"
            else
                echo "✅ SALDO SUFICIENTE: $SOL_AMOUNT SOL"
                echo ""
                echo "Se o problema persistir, verifique os logs do relayer:"
                echo "  docker logs hpl-relayer-testnet-local | grep -i error"
            fi
        fi
    else
        echo "⚠️  Erro ao verificar saldo:"
        echo "$BALANCE"
        echo ""
        echo "Verifique manualmente:"
        echo "  https://explorer.solana.com/address/$ADDRESS?cluster=testnet"
    fi
else
    echo "⚠️  Solana CLI não instalado"
    echo ""
    echo "Verifique saldo manualmente:"
    echo "  https://explorer.solana.com/address/$ADDRESS?cluster=testnet"
    echo ""
    echo "Ou instale Solana CLI:"
    echo "  sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 RESUMO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Endereço do relayer: $ADDRESS"
echo "Explorer: https://explorer.solana.com/address/$ADDRESS?cluster=testnet"
echo ""

