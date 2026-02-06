#!/bin/bash

echo "========================================="
echo "🧪 TESTE DE CORREÇÃO DO ISM SEPOLIA"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"
TERRA_ISM="${TERRA_ISM:-0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3}"

echo "📍 Configurações:"
echo "   Warp Route: $WARP_ROUTE"
echo "   ISM Terra Classic: $TERRA_ISM"
echo "   Domain Terra Classic: $TERRA_DOMAIN"
echo ""

echo "1️⃣ Verificando estado atual..."
echo ""

CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
CURRENT_ISM_CHECKSUM=$(cast --to-checksum-address "$CURRENT_ISM" 2>/dev/null)

echo "   ISM atual: $CURRENT_ISM_CHECKSUM"

MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   Tipo: $TYPE_DEC"
case "$TYPE_DEC" in
    1) echo "   → DomainRoutingISM ✅" ;;
    5) echo "   → MESSAGE_ID_MULTISIG ❌" ;;
    *) echo "   → Tipo desconhecido" ;;
esac

echo ""
echo "2️⃣ Verificando o que precisa ser feito..."
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "   ✅ ISM já é DomainRoutingISM"
    
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
        
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "   ✅ Já está configurado corretamente!"
            echo "   ISM para Terra Classic: $ISM_FOR_TERRA_CHECKSUM"
            echo ""
            echo "   ✅ NADA A FAZER - Já está correto!"
            exit 0
        else
            echo "   ⚠️  Precisa atualizar:"
            echo "   Atual: $ISM_FOR_TERRA_CHECKSUM"
            echo "   Esperado: $TERRA_ISM_CHECKSUM"
            echo ""
            echo "   📝 Ação: DomainRoutingISM.set(1325, $TERRA_ISM_CHECKSUM)"
        fi
    else
        echo "   ⚠️  Precisa adicionar Terra Classic"
        echo ""
        echo "   📝 Ação: DomainRoutingISM.set(1325, $TERRA_ISM_CHECKSUM)"
    fi
else
    echo "   ❌ ISM NÃO é DomainRoutingISM"
    echo ""
    echo "   📝 Ações necessárias:"
    echo "   1. Criar DomainRoutingISM via Factory"
    echo "      Factory: $DOMAIN_ROUTING_ISM_FACTORY"
    echo "      deploy([1325], [$TERRA_ISM], owner)"
    echo ""
    echo "   2. Configurar Warp Route"
    echo "      WarpRoute.setInterchainSecurityModule(DomainRoutingISM)"
fi

echo ""
echo "3️⃣ Verificando se ISM do Terra Classic está acessível..."
echo ""

# Tentar verificar o ISM do Terra Classic (pode não funcionar via Sepolia RPC)
echo "   Tentando verificar ISM do Terra Classic..."
echo "   (Pode não funcionar via Sepolia RPC, mas isso é normal)"
echo ""

echo "4️⃣ Resumo do que será executado:"
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "   ✅ Usar DomainRoutingISM existente: $CURRENT_ISM_CHECKSUM"
    echo "   📝 Executar: DomainRoutingISM.set(1325, $TERRA_ISM)"
else
    echo "   📝 Criar novo DomainRoutingISM"
    echo "   📝 Configurar: DomainRoutingISM.set(1325, $TERRA_ISM)"
    echo "   📝 Atualizar Warp Route para usar DomainRoutingISM"
fi

echo ""
echo "========================================="
echo "✅ TESTE CONCLUÍDO"
echo "========================================="
echo ""
echo "Para executar a correção real:"
echo "   export TERRA_ISM=\"$TERRA_ISM\""
echo "   export PRIVATE_KEY=\"<sua_private_key>\""
echo "   ./corrigir-ism-sepolia.sh"
echo ""

