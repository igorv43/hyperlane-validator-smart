#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO WARP ROUTE DO SOLANA"
echo "========================================="
echo ""

WARP_SOLANA="3yhG9dDHVX6K1duf8znEcaJcuTiKSLYvfBD4xy6akxfu"
SOLANA_RPC="https://api.testnet.solana.com"

echo "📍 Warp Route Solana: $WARP_SOLANA"
echo ""

echo "1️⃣ Obtendo informações do contrato Solana..."
echo ""

# No Solana, precisamos usar a CLI do Solana ou RPC direto
# Vamos tentar obter dados do contrato

echo "   Tentando obter dados do programa..."
echo ""

# Verificar se solana CLI está disponível
if command -v solana &> /dev/null; then
    echo "   ✅ Solana CLI disponível"
    echo ""
    
    # Obter informações da conta
    echo "   Informações da conta:"
    solana account "$WARP_SOLANA" --url "$SOLANA_RPC" 2>/dev/null | head -20
    
    echo ""
    echo "   Tentando obter dados do programa..."
    
    # Tentar obter dados via RPC direto
    curl -s -X POST "$SOLANA_RPC" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAccountInfo\",\"params\":[\"$WARP_SOLANA\",{\"encoding\":\"jsonParsed\"}]}" \
        | jq '.' 2>/dev/null | head -50
    
else
    echo "   ⚠️  Solana CLI não disponível, usando RPC direto"
    echo ""
    
    # Tentar obter dados via RPC
    echo "   Obtendo informações da conta via RPC..."
    curl -s -X POST "$SOLANA_RPC" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAccountInfo\",\"params\":[\"$WARP_SOLANA\",{\"encoding\":\"jsonParsed\"}]}" \
        | jq '.result.value.data' 2>/dev/null | head -30
fi

echo ""
echo "2️⃣ Verificando ISM configurado..."
echo ""

# No Solana, o ISM pode estar armazenado no estado do programa
# Vamos tentar diferentes métodos para obter

echo "   💡 No Solana, o ISM pode ser obtido via:"
echo "      - Estado do programa Warp Route"
echo "      - Método específico do programa"
echo ""

echo "3️⃣ Verificando no Explorer do Solana..."
echo ""
echo "   📍 Explorer: https://explorer.solana.com/address/$WARP_SOLANA?cluster=testnet"
echo ""

echo "========================================="
echo "💡 INFORMAÇÕES IMPORTANTES"
echo "========================================="
echo ""
echo "Para Warp Routes sintéticos no Solana:"
echo ""
echo "1. O ISM deve ser configurado como DomainRoutingISM"
echo "2. O DomainRoutingISM deve apontar para o ISM do Terra Classic"
echo "   quando o destino é Terra Classic (domain 1325)"
echo ""
echo "4️⃣ Comparando com Sepolia..."
echo ""

WARP_SEPOLIA="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
SEPOLIA_RPC="https://sepolia.drpc.org"

echo "   Warp Route Sepolia: $WARP_SEPOLIA"
echo ""

# Obter ISM do Sepolia
ISM_SEPOLIA=$(cast call "$WARP_SEPOLIA" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
ISM_SEPOLIA_CHECKSUM=$(cast --to-checksum-address "$ISM_SEPOLIA" 2>/dev/null)

echo "   ISM do Sepolia: $ISM_SEPOLIA_CHECKSUM"

MODULE_TYPE=$(cast call "$ISM_SEPOLIA" "moduleType()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   Tipo: $TYPE_DEC"
case "$TYPE_DEC" in
    1) echo "   → ROUTING (DomainRoutingISM)" ;;
    5) echo "   → MESSAGE_ID_MULTISIG" ;;
    *) echo "   → Tipo desconhecido" ;;
esac

if [ "$TYPE_DEC" = "1" ]; then
    ISM_FOR_TERRA=$(cast call "$ISM_SEPOLIA" "module(uint32)(address)" "1325" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        echo "   ISM para Terra Classic (1325): $ISM_FOR_TERRA_CHECKSUM"
    fi
fi

echo ""
echo "========================================="

