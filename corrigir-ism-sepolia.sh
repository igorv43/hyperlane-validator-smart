#!/bin/bash

set -e

echo "========================================="
echo "🔧 CORRIGIR ISM DO WARP ROUTE SEPOLIA"
echo "   (Seguindo padrão do Solana)"
echo "========================================="
echo ""

# CONFIGURAÇÕES
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"

echo "📍 Warp Route Sepolia: $WARP_ROUTE"
echo "📍 Domain Terra Classic: $TERRA_DOMAIN"
echo ""

# Verificar se TERRA_ISM está configurado
if [ -z "$TERRA_ISM" ]; then
    echo "1️⃣ Obtendo ISM do Terra Classic..."
    echo ""
    
    # Tentar obter via API
    TERRA_MAILBOX="0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd"
    TERRA_LCD="https://lcd.luncblaze.com"
    
    QUERY_BASE64=$(echo -n "{\"interchain_security_module\":{}}" | base64 -w 0)
    QUERY_URL="$TERRA_LCD/cosmwasm/wasm/v1/contract/$TERRA_MAILBOX/smart/$QUERY_BASE64"
    
    RESPONSE=$(curl -s "$QUERY_URL" 2>/dev/null)
    
    if echo "$RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
        TERRA_ISM=$(echo "$RESPONSE" | jq -r '.data' 2>/dev/null)
        if [ -n "$TERRA_ISM" ] && [ "$TERRA_ISM" != "null" ] && [ "$TERRA_ISM" != "" ]; then
            echo "   ✅ ISM do Terra Classic obtido: $TERRA_ISM"
        fi
    fi
    
    if [ -z "$TERRA_ISM" ] || [ "$TERRA_ISM" = "null" ]; then
        echo "   ⚠️  Não foi possível obter via API"
        echo ""
        echo "   💡 Você precisa fornecer o ISM do Terra Classic"
        echo "   O ISM do Terra Classic é o endereço do contrato ISM no Terra Classic"
        echo "   que contém os validadores: 0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0"
        echo ""
        read -p "   Digite o endereço do ISM do Terra Classic: " TERRA_ISM
        
        if [ -z "$TERRA_ISM" ]; then
            echo "   ❌ ISM do Terra Classic não fornecido"
            exit 1
        fi
    fi
fi

TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

echo ""
echo "📍 ISM do Terra Classic: $TERRA_ISM_CHECKSUM"
echo ""

# Verificar PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ]; then
    echo "2️⃣ Configurando Private Key..."
    echo ""
    echo "   ⚠️  PRIVATE_KEY não está configurada"
    echo "   Você precisa da private key do owner do Warp Route"
    echo ""
    read -sp "   Digite a private key (não será exibida): " PRIVATE_KEY
    echo ""
    
    if [ -z "$PRIVATE_KEY" ]; then
        echo "   ❌ Private key não fornecida"
        exit 1
    fi
fi

# Obter endereço do owner
OWNER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null | tr -d '\n')

if [ -z "$OWNER_ADDR" ]; then
    echo "❌ Erro ao obter endereço da private key"
    exit 1
fi

OWNER_CHECKSUM=$(cast --to-checksum-address "$OWNER_ADDR" 2>/dev/null)

echo "📍 Owner: $OWNER_CHECKSUM"
echo ""

# Verificar owner
WARP_OWNER=$(cast call "$WARP_ROUTE" "owner()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
WARP_OWNER_CHECKSUM=$(cast --to-checksum-address "$WARP_OWNER" 2>/dev/null)

if [ "$WARP_OWNER_CHECKSUM" != "$OWNER_CHECKSUM" ]; then
    echo "⚠️  AVISO: O endereço da private key ($OWNER_CHECKSUM)"
    echo "   não corresponde ao owner do Warp Route ($WARP_OWNER_CHECKSUM)"
    echo ""
    read -p "   Continuar mesmo assim? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "3️⃣ Verificando ISM atual do Warp Route..."
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
echo "4️⃣ Criando DomainRoutingISM..."
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "   ✅ ISM atual já é DomainRoutingISM"
    
    # Verificar se está configurado para Terra Classic
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "   ✅ Já está configurado corretamente para Terra Classic!"
            echo "   ISM para Terra Classic: $ISM_FOR_TERRA_CHECKSUM"
            echo ""
            echo "   ✅ Configuração já está correta! Nada a fazer."
            exit 0
        else
            echo "   ⚠️  DomainRoutingISM existe mas aponta para: $ISM_FOR_TERRA_CHECKSUM"
            echo "   Precisa atualizar para: $TERRA_ISM_CHECKSUM"
            echo ""
            read -p "   Executar transação para atualizar? (s/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                echo "   Enviando transação..."
                cast send "$CURRENT_ISM" \
                    "set(uint32,address)" \
                    "$TERRA_DOMAIN" \
                    "$TERRA_ISM" \
                    --private-key "$PRIVATE_KEY" \
                    --rpc-url "$RPC"
                
                echo ""
                echo "   ✅ DomainRoutingISM atualizado!"
            else
                echo "   ❌ Cancelado"
                exit 0
            fi
        fi
    else
        echo "   ⚠️  DomainRoutingISM existe mas não tem configuração para Terra Classic"
        echo "   Adicionando configuração..."
        echo ""
        read -p "   Executar transação para adicionar Terra Classic? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo "   Enviando transação..."
            cast send "$CURRENT_ISM" \
                "set(uint32,address)" \
                "$TERRA_DOMAIN" \
                "$TERRA_ISM" \
                --private-key "$PRIVATE_KEY" \
                --rpc-url "$RPC"
            
            echo ""
            echo "   ✅ Terra Classic adicionado ao DomainRoutingISM!"
        else
            echo "   ❌ Cancelado"
            exit 0
        fi
    fi
else
    echo "   ⚠️  ISM atual NÃO é DomainRoutingISM (tipo $TYPE_DEC)"
    echo "   Criando novo DomainRoutingISM..."
    echo ""
    
    echo "   Factory: $DOMAIN_ROUTING_ISM_FACTORY"
    echo "   Domains: [$TERRA_DOMAIN]"
    echo "   Modules: [$TERRA_ISM_CHECKSUM]"
    echo "   Owner: $OWNER_CHECKSUM"
    echo ""
    
    read -p "   Executar transação para criar DomainRoutingISM? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "   Criando DomainRoutingISM..."
        echo "   (Isso pode levar alguns segundos...)"
        
        # Criar DomainRoutingISM
        TX_OUTPUT=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
            "deploy(uint32[],address[],address)" \
            "[$TERRA_DOMAIN]" \
            "[$TERRA_ISM]" \
            "$OWNER_ADDR" \
            --private-key "$PRIVATE_KEY" \
            --rpc-url "$RPC" 2>&1)
        
        # Tentar extrair hash da transação
        TX_HASH=$(echo "$TX_OUTPUT" | grep -oE "0x[a-fA-F0-9]{64}" | head -1)
        
        if [ -n "$TX_HASH" ]; then
            echo "   ✅ Transação enviada: $TX_HASH"
            echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
            echo ""
            echo "   ⚠️  O DomainRoutingISM é criado via evento"
            echo "   Você precisa verificar o evento 'Deployed' na transação"
            echo "   para obter o endereço do DomainRoutingISM criado"
            echo ""
        else
            echo "   ⚠️  Transação enviada, mas não foi possível extrair o hash"
            echo "   Verifique no Etherscan usando seu endereço: $OWNER_CHECKSUM"
            echo ""
        fi
        
        echo "   Digite o endereço do DomainRoutingISM criado:"
        read -p "   > " NEW_ISM
        
        if [ -z "$NEW_ISM" ]; then
            echo "   ❌ Endereço do DomainRoutingISM não fornecido"
            exit 1
        fi
        
        NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
        echo ""
        echo "   ✅ DomainRoutingISM: $NEW_ISM_CHECKSUM"
        echo ""
        
        echo "5️⃣ Configurando Warp Route para usar DomainRoutingISM..."
        echo ""
        read -p "   Executar transação para configurar Warp Route? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo "   Enviando transação..."
            cast send "$WARP_ROUTE" \
                "setInterchainSecurityModule(address)" \
                "$NEW_ISM_CHECKSUM" \
                --private-key "$PRIVATE_KEY" \
                --rpc-url "$RPC"
            
            echo ""
            echo "   ✅ Warp Route configurado!"
        else
            echo "   ❌ Cancelado"
            exit 0
        fi
    else
        echo "   ❌ Cancelado"
        exit 0
    fi
fi

echo ""
echo "========================================="
echo "✅ CONFIGURAÇÃO CONCLUÍDA"
echo "========================================="
echo ""
echo "Verificando configuração final..."
echo ""

FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)

echo "   ISM do Warp Route: $FINAL_ISM_CHECKSUM"

FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$FINAL_TYPE_DEC" = "1" ]; then
    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
    
    echo "   Tipo: DomainRoutingISM (1) ✅"
    echo "   ISM para Terra Classic (1325): $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "   ✅ Configuração está CORRETA!"
        echo ""
        echo "   O Warp Route agora está configurado como no Solana:"
        echo "   → ISM = DomainRoutingISM"
        echo "   → DomainRoutingISM.module(1325) = ISM do Terra Classic"
    else
        echo ""
        echo "   ⚠️  Configuração pode estar incorreta"
        echo "   Esperado: $TERRA_ISM_CHECKSUM"
        echo "   Obtido: $FINAL_ISM_FOR_TERRA_CHECKSUM"
    fi
else
    echo "   ⚠️  ISM não é DomainRoutingISM (tipo $FINAL_TYPE_DEC)"
fi

echo ""
echo "========================================="

