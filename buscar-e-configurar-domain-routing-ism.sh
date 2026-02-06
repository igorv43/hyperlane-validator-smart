#!/bin/bash

WARP_ROUTE="0x224a4419D7FA69D3bEbAbce574c7c84B48D829b4"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
PRIVATE_KEY="0xe6802d288e10e94a9e7910793b6a58328f4011ab622d19ad2636ce28264812e5"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"

echo "========================================="
echo "🔍 BUSCANDO DOMAINROUTINGISM CRIADO"
echo "========================================="
echo ""

# Lista de transações que criaram DomainRoutingISM
TX_HASHES=(
    "0x3c50e8b38b2fad4413507da28036569af5806b4ceaf4a6f852fced39d363d4cc"
    "0x365512b425f4674665ed0f5d607858fb06e5883bf69a1930b40bbb9adc6004d5"
    "0x2384444bce596663baed7b027eaee8329fa44607a04136f038596d1a5fba57e1"
    "0x081b54fc05f8a38ad6addb1552241c6822a54501cd461d824f250c8fc2822d8e"
)

echo "Verificando transações do factory..."
echo ""

# Para cada transação, tentar obter o endereço
for TX_HASH in "${TX_HASHES[@]}"; do
    echo "Verificando: $TX_HASH"
    
    # Obter bloco da transação
    TX_BLOCK=$(cast tx "$TX_HASH" --rpc-url "$RPC" 2>/dev/null | grep -i "blockNumber" | grep -oE "[0-9]+" | head -1)
    
    if [ -z "$TX_BLOCK" ]; then
        continue
    fi
    
    # Buscar logs do factory nesse bloco
    FROM_BLOCK=$((TX_BLOCK - 1))
    TO_BLOCK=$((TX_BLOCK + 1))
    
    LOGS=$(cast logs --from-block "$FROM_BLOCK" --to-block "$TO_BLOCK" \
        --address "$FACTORY" \
        --rpc-url "$RPC" 2>&1)
    
    # Tentar extrair endereços
    ADDRESSES=$(echo "$LOGS" | grep -oE "0x[a-fA-F0-9]{40}" | sort -u | grep -v "$FACTORY" | grep -v "$OWNER")
    
    for ADDR in $ADDRESSES; do
        # Verificar se é DomainRoutingISM
        TYPE=$(cast call "$ADDR" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "0")
        TYPE_DEC=$(printf "%d" "$TYPE" 2>/dev/null || echo "0")
        
        if [ "$TYPE_DEC" = "1" ]; then
            # Verificar owner
            ISM_OWNER=$(cast call "$ADDR" "owner()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n' || echo "")
            if [ "$ISM_OWNER" = "$OWNER" ]; then
                echo "   ✅ Encontrado DomainRoutingISM: $ADDR"
                echo ""
                echo "Configurando..."
                
                # Verificar se está configurado para Terra Classic
                ISM_FOR_TERRA=$(cast call "$ADDR" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
                
                if [ -z "$ISM_FOR_TERRA" ] || [ "$ISM_FOR_TERRA" = "0x0000000000000000000000000000000000000000" ]; then
                    echo "   Configurando para Terra Classic..."
                    cast send "$ADDR" "set(uint32,address)" "$TERRA_DOMAIN" "$TERRA_ISM" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
                    echo "   ✅ Configurado!"
                fi
                
                echo ""
                echo "Configurando Warp Route..."
                cast send "$WARP_ROUTE" "setInterchainSecurityModule(address)" "$ADDR" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" >/dev/null 2>&1
                echo "   ✅ Warp Route configurado!"
                echo ""
                
                echo "Verificando configuração final..."
                FINAL_ISM=$(cast call "$WARP_ROUTE" "interchainSecurityModule()(address)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                FINAL_ISM_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM" 2>/dev/null)
                FINAL_MODULE_TYPE=$(cast call "$FINAL_ISM" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                FINAL_TYPE_DEC=$(printf "%d" "$FINAL_MODULE_TYPE" 2>/dev/null || echo "0")
                
                echo "ISM final: $FINAL_ISM_CHECKSUM (tipo $FINAL_TYPE_DEC)"
                
                if [ "$FINAL_TYPE_DEC" = "1" ]; then
                    FINAL_ISM_FOR_TERRA=$(cast call "$FINAL_ISM" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                    FINAL_ISM_FOR_TERRA_CHECKSUM=$(cast --to-checksum-address "$FINAL_ISM_FOR_TERRA" 2>/dev/null)
                    echo "ISM Terra Classic: $FINAL_ISM_FOR_TERRA_CHECKSUM"
                    
                    if [ "$FINAL_ISM_FOR_TERRA_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
                        echo ""
                        echo "✅ CONFIGURAÇÃO CORRETA!"
                        exit 0
                    fi
                fi
                
                exit 0
            fi
        fi
    done
done

echo "⚠️  Não foi possível encontrar DomainRoutingISM automaticamente"
echo ""
echo "Por favor, verifique no Etherscan:"
echo "   https://sepolia.etherscan.io/address/$FACTORY#events"
echo ""
echo "E informe o endereço do DomainRoutingISM criado"

