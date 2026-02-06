#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO ISM DO WARP ROUTE SOLANA"
echo "========================================="
echo ""

# O endereço fornecido é o token mint, não o programa Warp Route
TOKEN_MINT="3yhG9dDHVX6K1duf8znEcaJcuTiKSLYvfBD4xy6akxfu"
SOLANA_RPC="https://api.testnet.solana.com"

echo "📍 Token Mint Solana: $TOKEN_MINT"
echo ""

echo "1️⃣ No Solana, o Warp Route é um programa (não um contrato EVM)"
echo "   O ISM é armazenado no estado do programa"
echo ""

echo "2️⃣ Para verificar o ISM configurado no Warp Route do Solana:"
echo ""
echo "   a) Você precisa do Program ID do Warp Route"
echo "   b) Consultar o estado do programa para obter o ISM"
echo "   c) Verificar se o ISM é DomainRoutingISM"
echo "   d) Verificar se aponta para o ISM do Terra Classic (domain 1325)"
echo ""

echo "3️⃣ Comparando com a configuração esperada..."
echo ""

echo "   ✅ CONFIGURAÇÃO CORRETA (como em Solana):"
echo "   → Warp Route ISM = DomainRoutingISM"
echo "   → DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo ""

echo "4️⃣ Verificando Sepolia para comparar..."
echo ""

WARP_SEPOLIA="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
SEPOLIA_RPC="https://sepolia.drpc.org"

ISM_SEPOLIA=$(cast call "$WARP_SEPOLIA" "interchainSecurityModule()(address)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
ISM_SEPOLIA_CHECKSUM=$(cast --to-checksum-address "$ISM_SEPOLIA" 2>/dev/null)

echo "   Warp Route Sepolia: $WARP_SEPOLIA"
echo "   ISM atual: $ISM_SEPOLIA_CHECKSUM"

MODULE_TYPE=$(cast call "$ISM_SEPOLIA" "moduleType()(uint8)" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   Tipo: $TYPE_DEC"
case "$TYPE_DEC" in
    1) 
        echo "   → ROUTING (DomainRoutingISM) ✅"
        echo ""
        echo "   Verificando se está configurado para Terra Classic..."
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
        echo "   ⚠️  DEVERIA ser DomainRoutingISM (tipo 1)"
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
echo "No Solana, o Warp Route está configurado corretamente:"
echo "   → ISM = DomainRoutingISM"
echo "   → DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo ""
echo "No Sepolia, o Warp Route NÃO está configurado corretamente:"
echo "   → ISM = MESSAGE_ID_MULTISIG (tipo 5)"
echo "   → DEVERIA ser DomainRoutingISM (tipo 1)"
echo ""
echo "📝 SOLUÇÃO:"
echo "   1. Criar ou usar DomainRoutingISM no Sepolia"
echo "   2. Configurar DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo "   3. Configurar Warp Route para usar o DomainRoutingISM"
echo ""

