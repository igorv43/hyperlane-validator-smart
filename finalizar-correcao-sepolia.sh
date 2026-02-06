#!/bin/bash

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"

echo "========================================="
echo "🔍 VERIFICANDO E FINALIZANDO CORREÇÃO"
echo "========================================="
echo ""

# Verificar se já está correto
CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
CURRENT_ISM_CHECKSUM=$(cast --to-checksum-address "$CURRENT_ISM" 2>/dev/null)
MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM atual: $CURRENT_ISM_CHECKSUM (tipo $TYPE_DEC)"
echo ""

if [ "$TYPE_DEC" = "1" ]; then
    echo "✅ Já é DomainRoutingISM!"
    
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "✅ Já está configurado corretamente para Terra Classic!"
            echo ""
            echo "✅ CONFIGURAÇÃO ESTÁ CORRETA!"
            exit 0
        else
            echo "⚠️  Aponta para: $ISM_FOR_TERRA_CHECKSUM"
            echo "   Esperado: $TERRA_ISM_CHECKSUM"
            echo ""
            echo "Atualizando..."
            cast send "$CURRENT_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC"
            echo "✅ Atualizado!"
            exit 0
        fi
    else
        echo "⚠️  Não tem Terra Classic configurado"
        echo "Adicionando..."
        cast send "$CURRENT_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC"
        echo "✅ Adicionado!"
        exit 0
    fi
fi

echo "❌ Ainda não é DomainRoutingISM"
echo ""
echo "Transações enviadas para criar DomainRoutingISM:"
echo "   1. 0x3c50e8b38b2fad4413507da28036569af5806b4ceaf4a6f852fced39d363d4cc"
echo "   2. 0x365512b425f4674665ed0f5d607858fb06e5883bf69a1930b40bbb9adc6004d5"
echo "   3. 0x2384444bce596663baed7b027eaee8329fa44607a04136f038596d1a5fba57e1"
echo "   4. 0x081b54fc05f8a38ad6addb1552241c6822a54501cd461d824f250c8fc2822d8e"
echo ""
echo "💡 Verifique no Etherscan qual transação criou o DomainRoutingISM:"
echo "   https://sepolia.etherscan.io/address/0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92#events"
echo ""
echo "   Procure pelo evento 'ModuleDeployed' e copie o endereço do contrato"
echo ""
echo "Depois execute:"
echo "   export DOMAIN_ROUTING_ISM=\"<endereco_encontrado>\""
echo "   export PRIVATE_KEY=\"$PRIVATE_KEY\""
echo "   ./continuar-correcao-sepolia.sh"

