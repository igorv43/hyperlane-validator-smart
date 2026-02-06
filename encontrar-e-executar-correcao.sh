#!/bin/bash

set -e

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"

echo "========================================="
echo "🔍 ENCONTRANDO E CONFIGURANDO DOMAINROUTINGISM"
echo "========================================="
echo ""

echo "1️⃣ Verificando se já existe DomainRoutingISM configurado..."
echo ""

# Verificar ISM atual do Warp Route
CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
CURRENT_ISM_CHECKSUM=$(cast --to-checksum-address "$CURRENT_ISM" 2>/dev/null)

MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" = "1" ]; then
    echo "   ✅ ISM atual já é DomainRoutingISM: $CURRENT_ISM_CHECKSUM"
    
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
        
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "   ✅ Já está configurado corretamente para Terra Classic!"
            echo ""
            echo "   ✅ CONFIGURAÇÃO JÁ ESTÁ CORRETA!"
            exit 0
        else
            echo "   ⚠️  Precisa atualizar para: $TERRA_ISM_CHECKSUM"
            echo "   Atualizando..."
            cast send "$CURRENT_ISM" \
                "set(uint32,address)" \
                "$TERRA_DOMAIN" \
                "$TERRA_ISM" \
                --private-key "$PRIVATE_KEY" \
                --rpc-url "$RPC"
            echo "   ✅ Atualizado!"
            exit 0
        fi
    else
        echo "   ⚠️  Não tem Terra Classic configurado, adicionando..."
        cast send "$CURRENT_ISM" \
            "set(uint32,address)" \
            "$TERRA_DOMAIN" \
            "$TERRA_ISM" \
            --private-key "$PRIVATE_KEY" \
            --rpc-url "$RPC"
        echo "   ✅ Terra Classic adicionado!"
        exit 0
    fi
fi

echo "   ❌ ISM atual não é DomainRoutingISM (tipo $TYPE_DEC)"
echo ""

echo "2️⃣ Buscando DomainRoutingISM criado recentemente..."
echo ""

# Tentar encontrar verificando transações recentes do owner
# Ou verificar se há algum DomainRoutingISM que tenha o módulo configurado

# Como não conseguimos obter o endereço automaticamente, vamos criar um novo
# ou pedir para o usuário verificar no Etherscan

echo "   ⚠️  Não foi possível encontrar o DomainRoutingISM automaticamente"
echo ""
echo "   Opções:"
echo "   a) Criar um novo DomainRoutingISM"
echo "   b) Informar o endereço do DomainRoutingISM criado"
echo ""
echo "   Verifique no Etherscan:"
echo "   https://sepolia.etherscan.io/tx/0x3c50e8b38b2fad4413507da28036569af5806b4ceaf4a6f852fced39d363d4cc"
echo ""
read -p "   Criar novo DomainRoutingISM? (s/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo ""
    echo "3️⃣ Criando novo DomainRoutingISM..."
    echo ""
    
    DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
    
    echo "   Enviando transação..."
    TX_OUTPUT=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
        "deploy(uint32[],address[],address)" \
        "[$TERRA_DOMAIN]" \
        "[$TERRA_ISM]" \
        "$OWNER" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC" 2>&1)
    
    TX_HASH=$(echo "$TX_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)
    
    if [ -n "$TX_HASH" ]; then
        echo "   ✅ Transação enviada: $TX_HASH"
        echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
        echo ""
        echo "   ⚠️  Verifique a transação no Etherscan para obter o endereço"
        echo "   do DomainRoutingISM criado e execute novamente este script"
        echo "   com: export DOMAIN_ROUTING_ISM=<endereco>"
        exit 0
    fi
else
    echo ""
    read -p "   Digite o endereço do DomainRoutingISM: " NEW_ISM
    
    if [ -z "$NEW_ISM" ]; then
        echo "   ❌ Endereço não fornecido"
        exit 1
    fi
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)

echo ""
echo "4️⃣ Verificando DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

# Verificar se é DomainRoutingISM
MODULE_TYPE=$(cast call "$NEW_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" != "1" ]; then
    echo "   ⚠️  O contrato não é DomainRoutingISM (tipo: $TYPE_DEC)"
    exit 1
fi

echo "   ✅ É DomainRoutingISM"

# Verificar se está configurado para Terra Classic
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "   ⚠️  Não está configurado para Terra Classic"
    echo "   Configurando..."
    cast send "$NEW_ISM" \
        "set(uint32,address)" \
        "$TERRA_DOMAIN" \
        "$TERRA_ISM" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC"
    echo "   ✅ Configurado!"
fi

echo ""
echo "5️⃣ Configurando Warp Route..."
echo ""

cast send "$WARP_ROUTE" \
    "setInterchainSecurityModule(address)" \
    "$NEW_ISM_CHECKSUM" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC"

echo "   ✅ Warp Route configurado!"

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
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    
    echo "ISM para Terra Classic (1325): $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
        echo "   O Warp Route agora está configurado como no Solana"
    fi
fi

echo ""
echo "========================================="

