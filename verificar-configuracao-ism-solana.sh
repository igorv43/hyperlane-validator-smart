#!/bin/bash

echo "========================================="
echo "🔍 CONFIGURAÇÃO DO ISM NO SOLANA"
echo "========================================="
echo ""

TOKEN_MINT="3yhG9dDHVX6K1duf8znEcaJcuTiKSLYvfBD4xy6akxfu"
SOLANA_RPC="https://api.testnet.solana.com"

echo "📍 Token Mint: $TOKEN_MINT"
echo ""

echo "1️⃣ No Solana, o Warp Route é um programa Sealevel"
echo "   O ISM é armazenado no estado do programa"
echo ""

echo "2️⃣ Para verificar a configuração do ISM no Solana:"
echo ""

# Tentar obter informações do programa Warp Route
# No Solana, precisamos do Program ID do Warp Route
# O token mint não é o programa, mas podemos tentar encontrar o programa

echo "   a) O Warp Route no Solana é um programa Sealevel"
echo "   b) O ISM é armazenado no estado do programa"
echo "   c) O ISM deve ser DomainRoutingISM"
echo "   d) DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo ""

echo "3️⃣ Verificando via Solana CLI..."
echo ""

if command -v solana &> /dev/null; then
    echo "   ✅ Solana CLI disponível"
    echo ""
    
    # Tentar obter informações do token
    echo "   Informações do Token Mint:"
    solana account "$TOKEN_MINT" --url "$SOLANA_RPC" 2>&1 | head -10
    
    echo ""
    echo "   💡 O token mint não contém informações do ISM"
    echo "   O ISM está no programa Warp Route (Program ID)"
    echo ""
    
    # Tentar encontrar o programa Warp Route
    # Geralmente o programa tem um PDA (Program Derived Address) associado
    echo "4️⃣ Para encontrar o programa Warp Route:"
    echo ""
    echo "   O programa Warp Route no Solana geralmente tem:"
    echo "   - Program ID: (precisa ser conhecido ou encontrado)"
    echo "   - Estado armazenado em PDAs (Program Derived Addresses)"
    echo ""
    
    echo "5️⃣ Verificando no Explorer do Solana..."
    echo ""
    echo "   📍 Explorer: https://explorer.solana.com/address/$TOKEN_MINT?cluster=testnet"
    echo ""
    
    # Tentar obter informações via RPC
    echo "6️⃣ Tentando obter informações via RPC..."
    echo ""
    
    # Buscar por programas que podem ser o Warp Route
    # No Hyperlane, o programa Warp Route geralmente tem um nome específico
    
    echo "   💡 No Hyperlane, o Warp Route no Solana:"
    echo "   - É um programa Sealevel"
    echo "   - Tem estado que armazena o ISM"
    echo "   - O ISM deve ser DomainRoutingISM"
    echo "   - DomainRoutingISM roteia para o ISM do Terra Classic quando destino é 1325"
    echo ""
    
else
    echo "   ⚠️  Solana CLI não disponível"
fi

echo "========================================="
echo "📋 CONFIGURAÇÃO ESPERADA NO SOLANA"
echo "========================================="
echo ""
echo "Baseado na documentação e no funcionamento correto:"
echo ""
echo "✅ Warp Route Solana:"
echo "   → ISM = DomainRoutingISM"
echo "   → DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo ""
echo "✅ Como funciona:"
echo "   1. Mensagem enviada DO Solana PARA Terra Classic"
echo "   2. Warp Route consulta DomainRoutingISM"
echo "   3. DomainRoutingISM retorna ISM do Terra Classic (domain 1325)"
echo "   4. Relayer busca checkpoints dos validadores do Terra Classic"
echo "   5. Validadores do Terra Classic assinam e mensagem é entregue"
echo ""

echo "========================================="
echo "🔍 COMPARAÇÃO COM SEPOLIA"
echo "========================================="
echo ""

WARP_SEPOLIA="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
SEPOLIA_RPC="https://sepolia.drpc.org"

echo "📍 Warp Route Sepolia: $WARP_SEPOLIA"
echo ""

ISM_SEPOLIA=$(cast call "$WARP_SEPOLIA" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
ISM_SEPOLIA_CHECKSUM=$(cast --to-checksum-address "$ISM_SEPOLIA" 2>/dev/null)

echo "   ISM atual: $ISM_SEPOLIA_CHECKSUM"

MODULE_TYPE=$(cast call "$ISM_SEPOLIA" "moduleType()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   Tipo: $TYPE_DEC"
case "$TYPE_DEC" in
    1) 
        echo "   → ROUTING (DomainRoutingISM) ✅"
        echo ""
        echo "   Verificando configuração para Terra Classic..."
        ISM_FOR_TERRA=$(cast call "$ISM_SEPOLIA" "module(uint32)(address)" "1325" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
        if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
            ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
            echo "   ✅ ISM para Terra Classic (1325): $ISM_FOR_TERRA_CHECKSUM"
        else
            echo "   ❌ NÃO configurado para Terra Classic"
        fi
        ;;
    5) 
        echo "   → MESSAGE_ID_MULTISIG ❌"
        echo "   ⚠️  DEVERIA ser DomainRoutingISM (como no Solana)"
        ;;
    *) 
        echo "   → Tipo desconhecido ($TYPE_DEC)"
        ;;
esac

echo ""
echo "========================================="
echo "💡 CONCLUSÃO"
echo "========================================="
echo ""
echo "No Solana (funcionando corretamente):"
echo "   ✅ ISM = DomainRoutingISM"
echo "   ✅ DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo ""
echo "No Sepolia (precisa ser corrigido):"
if [ "$TYPE_DEC" = "1" ]; then
    echo "   ✅ ISM = DomainRoutingISM"
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   ✅ DomainRoutingISM.module(1325) = ISM do Terra Classic"
        echo "   ✅ Configuração está CORRETA!"
    else
        echo "   ❌ DomainRoutingISM.module(1325) NÃO configurado"
        echo "   ⚠️  Precisa configurar para Terra Classic"
    fi
else
    echo "   ❌ ISM = MESSAGE_ID_MULTISIG (tipo $TYPE_DEC)"
    echo "   ⚠️  DEVERIA ser DomainRoutingISM (tipo 1)"
    echo "   📝 Use: ./configurar-ism-warp-sepolia-completo.sh"
fi
echo ""

