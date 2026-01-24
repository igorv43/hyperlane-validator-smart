#!/bin/bash

VALIDATOR_ANNOUNCE_BSC="0xf09701B0a93210113D175461b6135a96773B5465"
BSC_RPC="https://bsc-testnet.publicnode.com"

VALIDATORS_ISM=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

echo "🔍 Consultando storage locations dos validators do ISM..."
echo ""

# Consultar usando a função correta: getAnnouncedStorageLocations(address[])
RESULT=$(cast call "$VALIDATOR_ANNOUNCE_BSC" \
    "getAnnouncedStorageLocations(address[])" \
    "[$(IFS=,; echo "${VALIDATORS_ISM[*]}")]" \
    --rpc-url "$BSC_RPC" 2>&1)

if echo "$RESULT" | grep -qi "error\|revert"; then
    echo "❌ Erro: $RESULT"
    exit 1
fi

# Decodificar como string[][]
DECODED=$(cast --abi-decode "getAnnouncedStorageLocations(address[])(string[][])" "$RESULT" 2>/dev/null)

if [ -z "$DECODED" ] || [ "$DECODED" == "()" ]; then
    echo "❌ Não foi possível decodificar"
    exit 1
fi

echo "✅ Storage locations encontradas!"
echo ""
echo "$DECODED" | jq -R 'fromjson? // .' 2>/dev/null || echo "$DECODED"

# Extrair buckets S3
echo ""
echo "📦 Buckets S3 encontrados:"
echo "$DECODED" | grep -oE "s3://[^ ]+" | nl

# Verificar se há checkpoints nesses buckets
echo ""
echo "🔍 Verificando checkpoints nos buckets encontrados..."

if command -v aws &> /dev/null; then
    SEQUENCE="12768"
    echo "$DECODED" | grep -oE "s3://[^/]+/[^ ]+" | while read -r BUCKET_PATH; do
        BUCKET=$(echo "$BUCKET_PATH" | sed -E 's|s3://([^/]+).*|\1|')
        PREFIX=$(echo "$BUCKET_PATH" | sed -E 's|s3://[^/]+/?(.*)|\1|')
        
        echo ""
        echo "Bucket: $BUCKET"
        echo "Prefix: $PREFIX"
        
        # Listar arquivos recentes
        if [ ! -z "$PREFIX" ]; then
            S3_PATH="s3://${BUCKET}/${PREFIX}/"
        else
            S3_PATH="s3://${BUCKET}/"
        fi
        
        echo "Verificando: $S3_PATH"
        FILES=$(aws s3 ls "$S3_PATH" --recursive 2>/dev/null | tail -10 | awk '{print $4}' || echo "")
        
        if [ ! -z "$FILES" ]; then
            echo "  ✅ Arquivos encontrados:"
            echo "$FILES" | head -5 | sed 's/^/    - /'
        else
            echo "  ⚠️  Nenhum arquivo encontrado"
        fi
    done
else
    echo "⚠️  AWS CLI não disponível para verificar buckets"
fi

