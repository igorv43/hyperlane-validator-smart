#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO CONFIGURAÇÃO DO ISM DO WARP"
echo "========================================="
echo ""

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
TERRA_DOMAIN="1325"
SEPOLIA_DOMAIN="11155111"
RPC="https://sepolia.drpc.org"

echo "📍 Warp Route: $WARP_ROUTE"
echo "📍 ISM atual: $WARP_ISM"
echo ""

echo "1️⃣ Verificando tipo do ISM atual..."
echo ""

# Verificar moduleType do ISM
MODULE_TYPE=$(cast call "$WARP_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
if [ -n "$MODULE_TYPE" ] && [ "$MODULE_TYPE" != "0x" ]; then
    TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "$MODULE_TYPE")
    echo "   Module Type: $TYPE_DEC"
    case "$TYPE_DEC" in
        1) echo "   → ROUTING" ;;
        2) echo "   → AGGREGATION" ;;
        3) echo "   → LEGACY_MULTISIG" ;;
        4) echo "   → MERKLE_ROOT_MULTISIG" ;;
        5) echo "   → MESSAGE_ID_MULTISIG" ;;
        *) echo "   → Tipo desconhecido" ;;
    esac
else
    echo "   ⚠️  Não foi possível obter moduleType"
fi

echo ""
echo "2️⃣ Verificando se é DomainRoutingISM..."
echo ""

# Tentar obter ISM para Terra Classic (destination domain)
# DomainRoutingISM usa origin domain, mas vamos tentar
ISM_FOR_TERRA=$(cast call "$WARP_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')

if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ] && [ "$ISM_FOR_TERRA" != "0x" ]; then
    echo "   ✅ É DomainRoutingISM!"
    echo "   📍 ISM para Terra Classic (domain $TERRA_DOMAIN): $ISM_FOR_TERRA"
    echo ""
    
    echo "3️⃣ Obtendo validadores do ISM do Terra Classic..."
    VALIDATORS_RESULT=$(cast call "$ISM_FOR_TERRA" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$RPC" 2>/dev/null)
    
    if [ -n "$VALIDATORS_RESULT" ] && [ "$VALIDATORS_RESULT" != "0x" ]; then
        echo "   ✅ Validadores obtidos!"
        echo "$VALIDATORS_RESULT" | grep -oE "0x[a-fA-F0-9]{40}" | while read addr; do
            CHECKSUM=$(cast --to-checksum-address "$addr" 2>/dev/null)
            echo "      - $CHECKSUM"
        done
    fi
else
    echo "   ⚠️  NÃO é DomainRoutingISM ou não encontrou ISM para Terra Classic"
    echo ""
    echo "   💡 SEGUINDO A DOCUMENTAÇÃO:"
    echo "      O ISM do Warp sintético deve ser um DomainRoutingISM"
    echo "      que aponta para o ISM do Terra Classic quando o destino é Terra Classic"
    echo ""
    echo "   📝 CONFIGURAÇÃO CORRETA:"
    echo "      Warp Route ISM → DomainRoutingISM"
    echo "      DomainRoutingISM.module(1325) → ISM do Terra Classic"
    echo ""
    echo "   ⚠️  O ISM atual ($WARP_ISM) pode não estar configurado corretamente"
    echo "      Ele deveria ser um DomainRoutingISM que roteia para o ISM do Terra Classic"
fi

echo ""
echo "========================================="
echo "💡 SOLUÇÃO"
echo "========================================="
echo ""
echo "Para mensagens Sepolia → Terra Classic funcionarem:"
echo ""
echo "1. O ISM do Warp Route no Sepolia deve ser um DomainRoutingISM"
echo "2. O DomainRoutingISM deve ter configurado:"
echo "   → module(1325) = ISM do Terra Classic"
echo ""
echo "3. O ISM do Terra Classic deve ter os validadores corretos:"
echo "   → Validadores do Terra Classic"
echo "   → Devem estar anunciados no ValidatorAnnounce do Terra Classic"
echo ""
echo "4. O relayer deve buscar checkpoints do Terra Classic"
echo "   (não do Sepolia) quando os validadores são do Terra Classic"
echo ""

