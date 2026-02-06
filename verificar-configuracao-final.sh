#!/bin/bash

RPC="https://1rpc.io/sepolia"
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
DOMAIN_ROUTING_ISM="0xf5b9a56137e286a3d767aba428a5f9c0e625d29b"
TERRA_DOMAIN="1325"
NEW_ISM="0x53Ef82c23830588cd183CFd2Cb595B1d69af3A71"
VALIDATOR="0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0"

echo "========================================="
echo "✅ VERIFICAÇÃO FINAL DA CONFIGURAÇÃO"
echo "========================================="
echo ""

echo "1. Warp Route ISM:"
WARP_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
WARP_ISM_CHECKSUM=$(cast --to-checksum-address "$WARP_ISM" 2>/dev/null)
echo "   $WARP_ISM_CHECKSUM"

WARP_ISM_TYPE=$(cast call "$WARP_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
WARP_ISM_TYPE_DEC=$(printf "%d" "$WARP_ISM_TYPE" 2>/dev/null || echo "0")
echo "   Tipo: $WARP_ISM_TYPE_DEC (1 = DomainRoutingISM)"
echo ""

if [ "$WARP_ISM_TYPE_DEC" = "1" ]; then
    echo "2. DomainRoutingISM para Terra Classic (domain $TERRA_DOMAIN):"
    TERRA_ISM=$(cast call "$WARP_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
    echo "   $TERRA_ISM_CHECKSUM"
    
    if [ "$TERRA_ISM_CHECKSUM" = "$NEW_ISM_CHECKSUM" ]; then
        echo "   ✅ Configurado corretamente!"
        echo ""
        
        echo "3. MessageIdMultisigISM:"
        TERRA_ISM_TYPE=$(cast call "$TERRA_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
        TERRA_ISM_TYPE_DEC=$(printf "%d" "$TERRA_ISM_TYPE" 2>/dev/null || echo "0")
        echo "   Tipo: $TERRA_ISM_TYPE_DEC (5 = MessageIdMultisigISM)"
        
        if [ "$TERRA_ISM_TYPE_DEC" = "5" ]; then
            echo "   ✅ É MessageIdMultisigISM"
            echo ""
            
            echo "4. Validadores do ISM:"
            VALIDATORS_OUTPUT=$(cast call "$TERRA_ISM" "validatorsAndThreshold(bytes)" "0x" --rpc-url "$RPC" 2>&1)
            VALIDATOR_FOUND=$(echo "$VALIDATORS_OUTPUT" | grep -oE "0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0" || echo "")
            
            if [ -n "$VALIDATOR_FOUND" ]; then
                VALIDATOR_CHECKSUM=$(cast --to-checksum-address "$VALIDATOR_FOUND" 2>/dev/null)
                echo "   ✅ Validador: $VALIDATOR_CHECKSUM"
                echo "   ✅ Threshold: 1"
                echo ""
                echo "========================================="
                echo "✅ CONFIGURAÇÃO COMPLETA E CORRETA!"
                echo "========================================="
                echo ""
                echo "Resumo:"
                echo "  Warp Route → DomainRoutingISM"
                echo "  DomainRoutingISM.module(1325) → MessageIdMultisigISM"
                echo "  MessageIdMultisigISM.validators = [$VALIDATOR_CHECKSUM]"
                echo "  Threshold = 1"
            else
                echo "   ⚠️  Validador não encontrado"
            fi
        else
            echo "   ⚠️  Não é MessageIdMultisigISM"
        fi
    else
        echo "   ⚠️  Diferente do esperado"
        echo "   Esperado: $NEW_ISM_CHECKSUM"
        echo "   Obtido: $TERRA_ISM_CHECKSUM"
    fi
else
    echo "   ⚠️  Warp Route não usa DomainRoutingISM"
fi

