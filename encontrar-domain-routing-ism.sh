#!/bin/bash

FACTORY="0xD2a0c68ed92D1Eb3C699D2808b06dd7b70367F92"
OWNER="0x133fD7F7094DBd17b576907d052a5aCBd48dB526"
TERRA_DOMAIN="1325"
TERRA_ISM="0xb401ac66cb7f60a4958ca2cdf695f03d2a4a86c3"
RPC="https://sepolia.drpc.org"
BLOCK="10186037"

echo "Buscando DomainRoutingISM criado..."
echo ""

# Tentar buscar eventos Deployed do factory
echo "1. Buscando eventos Deployed..."
cast logs --from-block $((BLOCK - 10)) --to-block $((BLOCK + 10)) \
    --address "$FACTORY" \
    --rpc-url "$RPC" 2>&1 | grep -i "deployed\|address" | head -20

echo ""
echo "2. Verificando se o factory tem método para listar ISMs..."
echo ""

# Tentar diferentes métodos do factory
METHODS=("deployedIsms" "getDeployedIsms" "isms" "deployedContracts")

for METHOD in "${METHODS[@]}"; do
    RESULT=$(cast call "$FACTORY" "${METHOD}()(address[])" --rpc-url "$RPC" 2>/dev/null)
    if [ -n "$RESULT" ] && [ "$RESULT" != "0x" ]; then
        echo "   ✅ Método $METHOD retornou:"
        echo "$RESULT" | grep -oE "0x[a-fA-F0-9]{40}" | while read addr; do
            echo "      $addr"
            # Verificar se é DomainRoutingISM e se está configurado para Terra Classic
            TYPE=$(cast call "$addr" "moduleType()(uint8)" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
            if [ "$TYPE" = "0x01" ] || [ "$TYPE" = "1" ]; then
                ISM_FOR_TERRA=$(cast call "$addr" "module(uint32)(address)" "$TERRA_DOMAIN" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
                if [ -n "$ISM_FOR_TERRA" ] && [ "$ISM_FOR_TERRA" != "0x0000000000000000000000000000000000000000" ]; then
                    ISM_CHECKSUM=$(cast --to-checksum-address "$ISM_FOR_TERRA" 2>/dev/null)
                    TERRA_ISM_CHECKSUM=$(cast --to-checksum-address "$TERRA_ISM" 2>/dev/null)
                    if [ "$ISM_CHECKSUM" = "$TERRA_ISM_CHECKSUM" ]; then
                        echo "      ✅ É o DomainRoutingISM correto! ($addr)"
                        echo "$addr"
                        exit 0
                    fi
                fi
            fi
        done
    fi
done

echo ""
echo "3. Tentando calcular endereço baseado no nonce do factory..."
echo ""

# Tentar calcular baseado no nonce
FACTORY_NONCE=$(cast nonce "$FACTORY" --rpc-url "$RPC" 2>/dev/null | tr -d '\n')
echo "   Factory nonce: $FACTORY_NONCE"

echo ""
echo "4. Verificando contratos criados recentemente pelo owner..."
echo ""

# Verificar se há algum DomainRoutingISM criado recentemente que tenha o módulo configurado
# Vamos tentar verificar alguns endereços possíveis ou buscar em um range

