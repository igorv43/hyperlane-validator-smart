#!/bin/bash

set -e

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"

echo "========================================="
echo "🔍 BUSCANDO DOMAINROUTINGISM CRIADO"
echo "========================================="
echo ""

# Se o endereço foi fornecido, usar
if [ -n "$DOMAIN_ROUTING_ISM" ]; then
    NEW_ISM="$DOMAIN_ROUTING_ISM"
    echo "✅ Usando DomainRoutingISM fornecido: $NEW_ISM"
else
    echo "⚠️  DomainRoutingISM não fornecido"
    echo ""
    echo "Por favor, verifique a transação no Etherscan:"
    echo "   https://sepolia.etherscan.io/tx/0x3c50e8b38b2fad4413507da28036569af5806b4ceaf4a6f852fced39d363d4cc"
    echo ""
    echo "E informe o endereço do DomainRoutingISM criado:"
    read -p "> " NEW_ISM
fi

if [ -z "$NEW_ISM" ]; then
    echo "❌ Endereço do DomainRoutingISM não fornecido"
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

echo ""
echo "Verificando DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

# Verificar se é DomainRoutingISM
MODULE_TYPE=$(cast call "$NEW_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" != "1" ]; then
    echo "⚠️  O contrato não é DomainRoutingISM (tipo: $TYPE_DEC)"
    read -p "Continuar mesmo assim? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar se está configurado para Terra Classic
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')

if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
    ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
    echo "✅ DomainRoutingISM já configurado para Terra Classic: $ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$ISM_FOR_TERRA_CHECKSUM" != "$TERRA_ISM_CHECKSUM" ]; then
        echo "⚠️  Mas aponta para ISM diferente do esperado"
    fi
else
    echo "⚠️  DomainRoutingISM não está configurado para Terra Classic"
    echo "   Configurando agora..."
    
    if [ -z "$PRIVATE_KEY" ]; then
        echo "❌ PRIVATE_KEY não configurada"
        exit 1
    fi
    
    cast send "$NEW_ISM" \
        "set(uint32,address)" \
        "$TERRA_DOMAIN" \
        "$TERRA_ISM" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC"
    
    echo "✅ Terra Classic configurado!"
fi

echo ""
echo "Configurando Warp Route para usar DomainRoutingISM..."
echo ""

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY não configurada"
    exit 1
fi

cast send "$WARP_ROUTE" \
    "setInterchainSecurityModule(address)" \
    "$NEW_ISM_CHECKSUM" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC"

echo "✅ Warp Route configurado!"

echo ""
echo "========================================="
echo "✅ VERIFICAÇÃO FINAL"
echo "========================================="
echo ""

FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)

FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM final: $FINAL_ISM_CHECKSUM"
echo "Tipo: $FINAL_TYPE_DEC"

if [ "$FINAL_TYPE_DEC" = "1" ]; then
    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
    
    echo "ISM para Terra Classic (1325): $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
        echo "   O Warp Route agora está configurado como no Solana"
    fi
fi

echo ""
echo "========================================="

