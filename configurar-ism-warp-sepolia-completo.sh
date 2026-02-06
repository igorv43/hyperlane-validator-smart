#!/bin/bash

set -e

echo "========================================="
echo "🔧 CONFIGURAR ISM DO WARP ROUTE SEPOLIA"
echo "   (Seguindo padrão do Solana)"
echo "========================================="
echo ""

# CONFIGURAÇÕES
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
DOMAIN_ROUTING_ISM_FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
RPC="https://sepolia.drpc.org"

# Verificar variáveis de ambiente
if [ -z "$TERRA_ISM" ]; then
    echo "❌ ERRO: TERRA_ISM não está configurado!"
    echo ""
    echo "   Execute primeiro:"
    echo "   ./obter-ism-terraclassic.sh"
    echo ""
    echo "   Depois configure:"
    echo "   export TERRA_ISM=<endereco_ism_terra_classic>"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ ERRO: PRIVATE_KEY não está configurada!"
    echo ""
    echo "   Configure:"
    echo "   export PRIVATE_KEY=<sua_private_key>"
    echo ""
    echo "   ⚠️  A private key deve ser do owner do Warp Route"
    exit 1
fi

# Obter endereço do owner
OWNER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null | tr -d '\n')

if [ -z "$OWNER_ADDR" ]; then
    echo "❌ Erro ao obter endereço da private key"
    exit 1
fi

TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
OWNER_CHECKSUM=$(cast --to-checksum-address "$OWNER_ADDR" 2>/dev/null)

echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM do Terra Classic: $TERRA_ISM_CHECKSUM"
echo "📍 Domain Terra Classic: $TERRA_DOMAIN"
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

echo "1️⃣ Verificando ISM atual do Warp Route..."
echo ""

CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
CURRENT_ISM_CHECKSUM=$(cast --to-checksum-address "$CURRENT_ISM" 2>/dev/null)

echo "   ISM atual: $CURRENT_ISM_CHECKSUM"

MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "   Tipo: $TYPE_DEC"
case "$TYPE_DEC" in
    1) echo "   → ROUTING (DomainRoutingISM)" ;;
    5) echo "   → MESSAGE_ID_MULTISIG" ;;
    *) echo "   → Tipo desconhecido" ;;
esac

echo ""
echo "2️⃣ Verificando se precisa criar DomainRoutingISM..."
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
            echo "3️⃣ Atualizando DomainRoutingISM..."
            echo ""
            
            read -p "   Executar transação para atualizar? (s/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
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
    echo "   Precisa criar novo DomainRoutingISM"
    echo ""
    
    echo "3️⃣ Criando novo DomainRoutingISM..."
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
        
        # Criar DomainRoutingISM
        TX_HASH=$(cast send "$DOMAIN_ROUTING_ISM_FACTORY" \
            "deploy(uint32[],address[],address)" \
            "[$TERRA_DOMAIN]" \
            "[$TERRA_ISM]" \
            "$OWNER_ADDR" \
            --private-key "$PRIVATE_KEY" \
            --rpc-url "$RPC" 2>&1 | grep -oE "0x[a-fA-F0-9]{64}" | head -1)
        
        if [ -z "$TX_HASH" ]; then
            echo "   ⚠️  Não foi possível obter hash da transação"
            echo "   Verifique a transação no Etherscan"
            echo ""
            read -p "   Digite o endereço do DomainRoutingISM criado: " NEW_ISM
        else
            echo "   ✅ Transação enviada: $TX_HASH"
            echo "   https://sepolia.etherscan.io/tx/$TX_HASH"
            echo ""
            echo "   ⚠️  O DomainRoutingISM é criado via evento"
            echo "   Verifique o evento 'Deployed' na transação para obter o endereço"
            echo ""
            read -p "   Digite o endereço do DomainRoutingISM criado: " NEW_ISM
        fi
        
        if [ -z "$NEW_ISM" ]; then
            echo "   ❌ Endereço do DomainRoutingISM não fornecido"
            exit 1
        fi
        
        NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
        echo ""
        echo "   ✅ DomainRoutingISM criado: $NEW_ISM_CHECKSUM"
        echo ""
        
        echo "4️⃣ Configurando Warp Route para usar DomainRoutingISM..."
        echo ""
        
        read -p "   Executar transação para configurar Warp Route? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
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
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    
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

