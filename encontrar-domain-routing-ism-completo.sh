#!/bin/bash

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"

echo "========================================="
echo "🔍 BUSCANDO DOMAINROUTINGISM"
echo "========================================="
echo ""

# Verificar se já está configurado
CURRENT_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
MODULE_TYPE=$(cast call "$CURRENT_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TYPE_DEC=$(printf "%d" "$MODULE_TYPE" 2>/dev/null || echo "0")

if [ "$TYPE_DEC" = "1" ]; then
    ISM_FOR_TERRA=$(cast call "$CURRENT_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
    if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
        ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
        if [ "$ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
            echo "✅ Já está configurado corretamente!"
            exit 0
        fi
    fi
fi

echo "Buscando DomainRoutingISM criado recentemente..."
echo ""

# Buscar eventos ModuleDeployed do factory
LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FROM_BLOCK=$((LATEST_BLOCK - 500))

echo "Buscando eventos de $FROM_BLOCK até $LATEST_BLOCK..."
echo ""

# Tentar buscar eventos usando a assinatura
EVENT_SIG="0x9ead1e8752d06495979d851a64b37d5670b1cc60b5901298b3f41eea356c78ef"  # ModuleDeployed(DomainRoutingIsm)

# Buscar logs com o tópico do evento
LOGS=$(cast logs --from-block "$FROM_BLOCK" --to-block latest \
    --address "$FACTORY" \
    --topic0 "$EVENT_SIG" \
    --rpc-url "$RPC" 2>&1)

# Tentar extrair endereços
ADDRESSES=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | sort -u | grep -v "$FACTORY" | grep -v "$OWNER")

NEW_ISM=""

for ADDR in $ADDRESSES; do
    if [ -z "$ADDR" ] || [ "$ADDR" = "0x0000000000000000000000000000000000000000" ]; then
        continue
    fi
    
    echo "Verificando: $ADDR"
    
    # Verificar se é DomainRoutingISM
    TYPE=$(cast call "$ADDR" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
    TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")
    
    if [ "$TYPE_DEC" = "1" ]; then
        # Verificar owner
        ISM_OWNER=$(cast call "$ADDR" "owner()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "")
        if [ "$ISM_OWNER" = "$OWNER" ]; then
            echo "   ✅ Encontrado DomainRoutingISM: $ADDR"
            NEW_ISM="$ADDR"
            break
        fi
    fi
done

if [ -z "$NEW_ISM" ]; then
    echo ""
    echo "⚠️  Não foi possível encontrar automaticamente"
    echo ""
    echo "💡 Verifique no Etherscan:"
    echo "   https://sepolia.etherscan.io/address/$FACTORY#events"
    echo ""
    echo "   Procure pelo evento 'ModuleDeployed' nas transações recentes"
    echo ""
    echo "Transações que criaram DomainRoutingISM:"
    echo "   - 0x3c50e8b38b2fad4413507da28036569af5806b4ceaf4a6f852fced39d363d4cc"
    echo "   - 0x365512b425f4674665ed0f5d607858fb06e5883bf69a1930b40bbb9adc6004d5"
    echo "   - 0x2384444bce596663baed7b027eaee8329fa44607a04136f038596d1a5fba57e1"
    echo "   - 0x081b54fc05f8a38ad6addb1552241c6822a54501cd461d824f250c8fc2822d8e"
    echo "   - 0xfd22455ad73172df7a832f146c1b89f852e41f52b86ea82943263df687159f6c"
    echo ""
    exit 1
fi

NEW_ISM_CHECKSUM=$(cast --to-checksum-address "$NEW_ISM" 2>/dev/null)
echo ""
echo "✅ Usando DomainRoutingISM: $NEW_ISM_CHECKSUM"
echo ""

# Verificar e configurar
ISM_FOR_TERRA=$(cast call "$NEW_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)

if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Configurando para Terra Classic..."
    cast send "$NEW_ISM" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
    echo "✅ Configurado!"
fi

echo ""
echo "Configurando Warp Route..."
cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$NEW_ISM_CHECKSUM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
echo "✅ Warp Route configurado!"
echo ""

echo "Verificando configuração final..."
FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)
FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")

echo "ISM: $FINAL_ISM_CHECKSUM (tipo $FINAL_TYPE_DEC)"

if [ "$FINAL_TYPE_DEC" = "1" ]; then
    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
    echo "ISM Terra Classic: $FINAL_ISM_FOR_TERRA_CHECKSUM"
    
    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
        echo ""
        echo "✅ CONFIGURAÇÃO CORRETA!"
        echo "   O Warp Route agora está configurado como no Solana"
    fi
fi

