#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  IDENTIFICAR CONTA ATA QUE PRECISA DE SOL                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Recipient do Solana (dos logs)
RECIPIENT="BirXd4QDxfq2vx9LGqgXXSgZrjT81rhoFGUbQRWDEf1j"
RELAYER_ADDRESS="C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 INFORMAÇÕES DAS CONTAS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Relayer (signer principal - account_index: 0):"
echo "  $RELAYER_ADDRESS"
echo "  Saldo atual: $(solana balance $RELAYER_ADDRESS --url https://api.testnet.solana.com 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1) SOL"
echo ""

echo "Recipient (destinatário da mensagem):"
echo "  $RECIPIENT"
echo "  Saldo atual: $(solana balance $RECIPIENT --url https://api.testnet.solana.com 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo '0') SOL"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 ANÁLISE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "O erro 'account_index: 5' indica que a 5ª conta na transação não tem SOL."
echo "Essa conta é a Associated Token Account (ATA) que está sendo criada."
echo ""
echo "A ATA é derivada do recipient e do mint token. O problema é que quando"
echo "o relayer tenta criar a ATA, ela precisa de SOL para rent exemption."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 SOLUÇÃO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "OPÇÃO 1: Transferir SOL para o RECIPIENT"
echo "  O recipient pode precisar de SOL para que a ATA seja criada:"
echo "  solana transfer $RECIPIENT 0.1 --url https://api.testnet.solana.com"
echo ""

echo "OPÇÃO 2: O relayer deveria transferir SOL automaticamente"
echo "  O problema é que o relayer não está fazendo isso. Isso pode ser"
echo "  um bug na versão 1.7.0 do Hyperlane."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 PRÓXIMOS PASSOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1. Tentar transferir 0.1 SOL para o recipient:"
echo "   solana transfer $RECIPIENT 0.1 --url https://api.testnet.solana.com"
echo ""
echo "2. Reiniciar o relayer"
echo ""
echo "3. Monitorar se o erro persiste"

