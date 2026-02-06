#!/bin/bash

set -e

# CONFIGURAÇÕES
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"

# Verificar variáveis
if [ -z "$TERRA_ISM" ]; then
    echo "❌ TERRA_ISM não configurado"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY não configurada"
    exit 1
fi

TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
OWNER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null | tr -d '\n')
OWNER_CHECKSUM=$(cast --to-checksum-address "$OWNER_ADDR" 2>/dev/null)

echo "========================================="
echo "🔧 CORRIGINDO ISM DO WARP ROUTE SEPOLIA"
echo "========================================="
echo ""
echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM Terra Classic: $TERRA_ISM_CHECKSUM"
echo "📍 Owner: $OWNER_CHECKSUM"
echo ""

# Verificar ISM atual
CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
CURRENT_ISM_CHECKSUM=$(cast --to-checksum-address "$CURRENT_ISM" 2>/dev/null)

MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM atual: $CURRENT_ISM_CHECKSUM (tipo $TYPE_DEC)"
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "✅ ISM já é DomainRoutingISM"
    
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "✅ Já está configurado corretamente!"
            exit 0
        else
            echo "Atualizando DomainRoutingISM..."
            cast send "$CURRENT_ISM" \
                "set(uint32,address)" \
                "$TERRA_DOMAIN" \
                "$TERRA_ISM" \
                --private-key "$PRIVATE_KEY" \
                --rpc-url "$RPC"
            echo "✅ DomainRoutingISM atualizado!"
        fi
    else
        echo "Adicionando Terra Classic ao DomainRoutingISM..."
        cast send "$CURRENT_ISM" \
            "set(uint32,address)" \
            "$TERRA_DOMAIN" \
            "$TERRA_ISM" \
            --private-key "$PRIVATE_KEY" \
            --rpc-url "$RPC"
        echo "✅ Terra Classic adicionado!"
    fi
else
    echo "Criando DomainRoutingISM..."
    
    # Criar DomainRoutingISM
    TX_OUTPUT=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
        "deploy(uint32[],address[],address)" \
        "[$TERRA_DOMAIN]" \
        "[$TERRA_ISM]" \
        "$OWNER_ADDR" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC" 2>&1)
    
    echo "$TX_OUTPUT"
    
    # Tentar extrair endereço do evento
    NEW_ISM=$(echo "$TX_OUTPUT" | grep -i "deployed\|address" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
    
    if [ -z "$NEW_ISM" ]; then
        echo ""
        echo "⚠️  Não foi possível extrair endereço automaticamente"
        echo "Verifique a transação no Etherscan e informe o endereço:"
        read -p "> " NEW_ISM
    fi
    
    if [ -z "$NEW_ISM" ]; then
        echo "❌ Endereço do DomainRoutingISM não fornecido"
        exit 1
    fi
    
    NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
    echo ""
    echo "✅ DomainRoutingISM criado: $NEW_ISM_CHECKSUM"
    echo ""
    
    echo "Configurando Warp Route..."
    cast send "$WARP_ROUTE" \
        "setInterchainSecurityModule(address)" \
        "$NEW_ISM_CHECKSUM" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC"
    
    echo "✅ Warp Route configurado!"
fi

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

