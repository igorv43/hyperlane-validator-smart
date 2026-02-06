#!/bin/bash

echo "========================================="
echo "🔍 CONFIGURAÇÃO COMPLETA DO ISM BSC"
echo "========================================="
echo ""

WARP_BSC="0x2144Be4477202ba2d50c9A8be3181241878cf7D8"
BSC_RPC="https://bsc-testnet.publicnode.com"
TERRA_DOMAIN="1325"

echo "📍 Warp Route BSC: $WARP_BSC"
echo ""

ISM_BSC=$(cast call "$WARP_BSC" "interchainSecurityModule()(address)" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')
ISM_BSC_CHECKSUM=$(cast --to-checksum-address "$ISM_BSC" 2>/dev/null)

echo "📍 ISM atual: $ISM_BSC_CHECKSUM"
echo ""

MODULE_TYPE=$(cast call "$ISM_BSC" "moduleType()(uint8)" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

echo "Tipo: $TYPE_DEC"
case "$TYPE_DEC" in
    1) echo "→ DomainRoutingISM ✅" ;;
    5) echo "→ MESSAGE_ID_MULTISIG ❌" ;;
    *) echo "→ Tipo desconhecido" ;;
esac

echo ""
echo "========================================="
echo "📋 DETALHES"
echo "========================================="
echo ""

if [ "$TYPE_DEC" = "5" ]; then
    echo "❌ PROBLEMA IDENTIFICADO:"
    echo ""
    echo "   O ISM do BSC é MESSAGE_ID_MULTISIG (tipo 5)"
    echo "   DEVERIA ser DomainRoutingISM (tipo 1)"
    echo ""
    echo "   Isso significa que:"
    echo "   → O ISM não roteia baseado no domain de destino"
    echo "   → Usa sempre os mesmos validadores para todos os destinos"
    echo "   → Não permite usar validadores diferentes por chain"
    echo ""
    
    echo "✅ VALIDADOR ATUAL:"
    VALIDATORS_RESULT=$(cast call "$ISM_BSC" "validatorsAndThreshold(bytes)(address[],uint8)" "0x" --rpc-url "$BSC_RPC" 2>/dev/null)
    
    if [ -n "$VALIDATORS_RESULT" ] && [ "$VALIDATORS_RESULT" != "0x" ]; then
        VALIDATOR=$(echo "$VALIDATORS_RESULT" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
        VALIDATOR_CHECKSUM=$(cast --to-checksum-address "$VALIDATOR" 2>/dev/null)
        THRESHOLD=$(echo "$VALIDATORS_RESULT" | grep -oE "[0-9]+" | tail -1)
        
        echo "   Validador: $VALIDATOR_CHECKSUM"
        echo "   Threshold: $THRESHOLD"
        echo ""
        
        if [ "$VALIDATOR_CHECKSUM" = "0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0" ]; then
            echo "   ✅ Validador está CORRETO (Terra Classic)"
        else
            echo "   ⚠️  Validador pode estar incorreto"
        fi
    fi
    
    echo ""
    echo "========================================="
    echo "💡 SOLUÇÃO"
    echo "========================================="
    echo ""
    echo "Para corrigir o BSC (como no Solana):"
    echo ""
    echo "1. Criar DomainRoutingISM no BSC"
    echo "   → Usar DomainRoutingIsmFactory"
    echo ""
    echo "2. Configurar DomainRoutingISM para Terra Classic"
    echo "   → DomainRoutingISM.set(1325, ISM_TERRA_CLASSIC)"
    echo ""
    echo "3. Configurar Warp Route para usar DomainRoutingISM"
    echo "   → WarpRoute.setInterchainSecurityModule(DomainRoutingISM)"
    echo ""
    echo "📝 Use o script: ./configurar-ism-warp-bsc-completo.sh"
    
elif [ "$TYPE_DEC" = "1" ]; then
    echo "✅ ISM é DomainRoutingISM (CORRETO)"
    echo ""
    
    ISM_FOR_TERRA=$(cast call "$ISM_BSC" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$BSC_RPC" 2>/dev/null | tr -d '\n')
    
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        echo "✅ DomainRoutingISM.module(1325) = $ISM_FOR_TERRA_CHECKSUM"
        echo ""
        echo "✅ Configuração está CORRETA (como no Solana)"
    else
        echo "❌ DomainRoutingISM.module(1325) NÃO configurado"
        echo "⚠️  Precisa configurar para Terra Classic"
    fi
fi

echo ""
echo "========================================="
echo "📊 COMPARAÇÃO: SOLANA vs BSC"
echo "========================================="
echo ""
echo "✅ Solana:"
echo "   ISM = DomainRoutingISM"
echo "   DomainRoutingISM.module(1325) = ISM do Terra Classic"
echo "   Status: ✅ Funcionando"
echo ""
echo "📊 BSC:"
if [ "$TYPE_DEC" = "1" ]; then
    echo "   ISM = DomainRoutingISM ✅"
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        echo "   DomainRoutingISM.module(1325) = ISM do Terra Classic ✅"
        echo "   Status: ✅ Configurado corretamente"
    else
        echo "   DomainRoutingISM.module(1325) = NÃO CONFIGURADO ❌"
        echo "   Status: ⚠️  Precisa configurar Terra Classic"
    fi
else
    echo "   ISM = MESSAGE_ID_MULTISIG ❌"
    echo "   Status: ❌ Precisa reconfigurar"
fi
echo ""

