#!/bin/bash

# Script para configurar DomainRoutingISM com o endereço fornecido
# Uso: ./configurar-com-endereco-final.sh <endereco_domain_routing_ism>

set -e

if [ -z "$1" ]; then
    echo "Uso: $0 <endereco_domain_routing_ism>"
    echo ""
    echo "Exemplo:"
    echo "  $0 0x1234567890123456789012345678901234567890"
    echo ""
    echo "Ou defina a variável:"
    echo "  export DOMAIN_ROUTING_ISM=0x1234567890123456789012345678901234567890"
    echo "  $0"
    exit 1
fi

NEW_ISM="$1"
RPC="https://sepolia.drpc.org"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"

echo "========================================="
echo "🔧 CONFIGURANDO DOMAINROUTINGISM"
echo "========================================="
echo ""

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo "DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

# Verificar se é DomainRoutingISM
TYPE=$(cast call "$NEW_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" != "1" ]; then
    echo "❌ Não é DomainRoutingISM (tipo: $TYPE_DEC)"
    exit 1
fi

echo "✅ Confirmado: É DomainRoutingISM"
echo ""

# Verificar e configurar
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Configurando para Terra Classic..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC"
    echo "✅ Configurado!"
else
    ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
    if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo "✅ Já está configurado para Terra Classic"
    else
        echo "Atualizando para Terra Classic..."
        cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC"
        echo "✅ Atualizado!"
    fi
fi

echo ""
echo "Configurando Warp Route..."
cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$NEW_ISM_CHECKSUM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC"
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
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    
    echo "ISM para Terra Classic (1325): $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
        echo "   O Warp Route agora está configurado como no Solana:"
        echo "   → ISM = DomainRoutingISM"
        echo "   → DomainRoutingISM.module(1325) = ISM do Terra Classic"
    else
        echo ""
        echo "⚠️  Configuração pode estar incorreta"
        echo "   Esperado: $TERRA_ISM_CHECKSUM"
        echo "   Obtido: $FINAL_ISM_FOR_TERRA_CHECKSUM"
    fi
else
    echo ""
    echo "❌ ISM não é DomainRoutingISM (tipo $FINAL_TYPE_DEC)"
fi

echo ""
echo "========================================="

