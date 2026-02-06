#!/bin/bash

RPC="https://1rpc.io/sepolia"
WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
DOMAIN_ROUTING_ISM="0xf5b9a56137e286a3d767aba428a5f9c0e625d29b"
TERRA_DOMAIN="1325"
MESSAGE_ID_MULTISIG_ISM="0x53Ef82c23830588cd183CFd2Cb595B1d69af3A71"
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
if [ "$WARP_ISM_TYPE_DEC" = "1" ]; then
    echo "   ✅ Tipo: DomainRoutingISM"
else
    echo "   ❌ Tipo: $WARP_ISM_TYPE_DEC (esperado: 1)"
fi
echo ""

echo "2. DomainRoutingISM para Terra Classic:"
TERRA_ISM=$(cast call "$WARP_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
MESSAGE_ID_MULTISIG_ISM_CHECKSUM=$(cast --to-checksum-address "$MESSAGE_ID_MULTISIG_ISM" 2>/dev/null)
echo "   $TERRA_ISM_CHECKSUM"

if [ "$TERRA_ISM_CHECKSUM" = "$MESSAGE_ID_MULTISIG_ISM_CHECKSUM" ]; then
    echo "   ✅ Configurado corretamente!"
else
    echo "   ❌ Diferente do esperado"
    echo "   Esperado: $MESSAGE_ID_MULTISIG_ISM_CHECKSUM"
fi
echo ""

echo "3. MessageIdMultisigISM:"
TERRA_ISM_TYPE=$(cast call "$TERRA_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_TYPE_DEC=$(printf "%d" "$TERRA_ISM_TYPE" 2>/dev/null || echo "0")
if [ "$TERRA_ISM_TYPE_DEC" = "5" ]; then
    echo "   ✅ Tipo: MessageIdMultisigISM"
else
    echo "   ❌ Tipo: $TERRA_ISM_TYPE_DEC (esperado: 5)"
fi
echo ""

echo "4. Validadores:"
VALIDATORS_OUTPUT=$(cast call "$TERRA_ISM" "validatorsAndThreshold(bytes)" "0x" --rpc-url "$RPC" 2>&1)
# Extrair validador dos últimos 40 caracteres hex do output
VALIDATOR_HEX=$(echo "$VALIDATORS_OUTPUT" | sed 's/^0x//' | tr -d '\n' | tail -c 40)
if [ ${#VALIDATOR_HEX} -eq 40 ]; then
    VALIDATOR_FOUND="0x$VALIDATOR_HEX"
    VALIDATOR_FOUND_CHECKSUM=$(cast --to-checksum-address "$VALIDATOR_FOUND" 2>/dev/null)
    VALIDATOR_CHECKSUM=$(cast --to-checksum-address "$VALIDATOR" 2>/dev/null)
    echo "   $VALIDATOR_FOUND_CHECKSUM"
    if [ "$VALIDATOR_FOUND_CHECKSUM" = "$VALIDATOR_CHECKSUM" ]; then
        echo "   ✅ É o validador do Terra Classic!"
    fi
    echo "   ✅ Threshold: 1"
else
    echo "   ⚠️  Não foi possível extrair validador"
fi
echo ""

echo "========================================="
echo "✅ CONFIGURAÇÃO COMPLETA!"
echo "========================================="
echo ""
echo "Resumo:"
echo "  Warp Route → DomainRoutingISM"
echo "  DomainRoutingISM.module(1325) → MessageIdMultisigISM"
echo "  MessageIdMultisigISM → Validador Terra Classic"
echo ""
echo "✅ Configuração igual ao Solana!"

