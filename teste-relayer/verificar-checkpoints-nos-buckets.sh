#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR CHECKPOINTS NOS BUCKETS S3 ENCONTRADOS                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

BUCKETS=(
    "s3://hyperlane-testnet4-bsctestnet-validator-0/us-east-1"
    "s3://hyperlane-testnet4-bsctestnet-validator-1/us-east-1"
    "s3://hyperlane-testnet4-bsctestnet-validator-2/us-east-1"
)

SEQUENCE="12768"  # Mensagem que estamos rastreando

if ! command -v aws &> /dev/null; then
    echo "⚠️  AWS CLI não está instalado. Não é possível verificar buckets S3."
    echo ""
    echo "📋 Buckets encontrados:"
    for BUCKET in "${BUCKETS[@]}"; do
        echo "  • $BUCKET"
    done
    exit 0
fi

echo "🔍 Verificando checkpoints para sequence $SEQUENCE..."
echo ""

for BUCKET_PATH in "${BUCKETS[@]}"; do
    BUCKET=$(echo "$BUCKET_PATH" | sed -E 's|s3://([^/]+).*|\1|')
    PREFIX=$(echo "$BUCKET_PATH" | sed -E 's|s3://[^/]+/?(.*)|\1|')
    
    echo "Bucket: $BUCKET"
    echo "Prefix: $PREFIX"
    
    if [ ! -z "$PREFIX" ]; then
        S3_PATH="s3://${BUCKET}/${PREFIX}/"
    else
        S3_PATH="s3://${BUCKET}/"
    fi
    
    echo "Verificando: $S3_PATH"
    
    # Listar arquivos recentes
    FILES=$(aws s3 ls "$S3_PATH" --recursive 2>/dev/null | tail -20 | awk '{print $4}' || echo "")
    
    if [ ! -z "$FILES" ]; then
        echo "  ✅ Arquivos encontrados:"
        echo "$FILES" | head -10 | sed 's/^/    - /'
        
        # Verificar se há checkpoint para a sequence específica
        CHECKPOINT_FILE=$(echo "$FILES" | grep -i "checkpoint.*${SEQUENCE}" || echo "")
        if [ ! -z "$CHECKPOINT_FILE" ]; then
            echo "  ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE:"
            echo "    - $CHECKPOINT_FILE"
        else
            echo "  ⚠️  Nenhum checkpoint encontrado para sequence $SEQUENCE"
        fi
    else
        echo "  ⚠️  Nenhum arquivo encontrado ou bucket não acessível"
    fi
    echo ""
done

