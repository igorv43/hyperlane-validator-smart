#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR CHECKPOINTS NOS BUCKETS S3 (CORRIGIDO)                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

BUCKETS=(
    "hyperlane-testnet4-bsctestnet-validator-0"
    "hyperlane-testnet4-bsctestnet-validator-1"
    "hyperlane-testnet4-bsctestnet-validator-2"
)

SEQUENCE="12768"

for BUCKET in "${BUCKETS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Bucket: $BUCKET"
    echo ""
    
    # Verificar na raiz do bucket (sem prefixo)
    S3_PATH="s3://${BUCKET}/"
    
    echo "Verificando: $S3_PATH"
    
    if ! command -v aws &> /dev/null; then
        # Usar curl para verificar via URL pública
        URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/"
        echo "  Usando URL pública: $URL"
        
        # Buscar checkpoint específico
        CHECKPOINT_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/checkpoint_${SEQUENCE}_with_id.json"
        echo "  Verificando: $CHECKPOINT_URL"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CHECKPOINT_URL" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "  ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE!"
            echo "     URL: $CHECKPOINT_URL"
            
            # Baixar e mostrar informações
            CONTENT=$(curl -s "$CHECKPOINT_URL" 2>/dev/null || echo "")
            if [ ! -z "$CONTENT" ]; then
                echo "     Tamanho: $(echo "$CONTENT" | wc -c) bytes"
                echo "     Preview: $(echo "$CONTENT" | head -c 200)..."
            fi
        else
            echo "  ⚠️  Checkpoint para sequence $SEQUENCE não encontrado (HTTP $HTTP_CODE)"
        fi
        
        # Listar últimos checkpoints
        echo ""
        echo "  📋 Últimos checkpoints (via URL pública):"
        LIST_URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/?list-type=2&max-keys=20"
        LIST_XML=$(curl -s "$LIST_URL" 2>/dev/null || echo "")
        
        if [ ! -z "$LIST_XML" ]; then
            echo "$LIST_XML" | grep -oE "<Key>[^<]+</Key>" | sed 's/<Key>//;s/<\/Key>//' | grep -i checkpoint | tail -10 | sed 's/^/    - /'
        fi
    else
        # Usar AWS CLI
        FILES=$(aws s3 ls "$S3_PATH" 2>/dev/null | grep -i checkpoint | sort -k4 -V | tail -20 || echo "")
        
        if [ ! -z "$FILES" ]; then
            echo "  ✅ Arquivos encontrados:"
            echo "$FILES" | tail -10 | while read -r LINE; do
                DATE=$(echo "$LINE" | awk '{print $1" "$2}')
                SIZE=$(echo "$LINE" | awk '{print $3}')
                FILE=$(echo "$LINE" | awk '{print $4}')
                echo "    📄 $FILE ($DATE, $SIZE bytes)"
            done
            
            # Verificar checkpoint específico
            CHECKPOINT_FILE="checkpoint_${SEQUENCE}_with_id.json"
            if echo "$FILES" | grep -q "$CHECKPOINT_FILE"; then
                echo ""
                echo "  ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE!"
                echo "     Arquivo: $CHECKPOINT_FILE"
            else
                # Verificar formato alternativo
                CHECKPOINT_FILE2="checkpoint_${SEQUENCE}.json"
                if echo "$FILES" | grep -q "$CHECKPOINT_FILE2"; then
                    echo ""
                    echo "  ✅ CHECKPOINT ENCONTRADO para sequence $SEQUENCE!"
                    echo "     Arquivo: $CHECKPOINT_FILE2"
                else
                    echo ""
                    echo "  ⚠️  Checkpoint para sequence $SEQUENCE não encontrado"
                    
                    # Mostrar sequences mais próximas
                    echo "  📊 Sequences próximas encontradas:"
                    echo "$FILES" | grep -oE "checkpoint_[0-9]+" | grep -oE "[0-9]+" | sort -n | awk -v seq="$SEQUENCE" '
                        {
                            diff = ($1 > seq) ? ($1 - seq) : (seq - $1)
                            if (diff < 100 || NR <= 5) print "    - " $1 " (diff: " diff ")"
                        }' | head -5
                fi
            fi
        else
            echo "  ⚠️  Nenhum arquivo encontrado"
        fi
    fi
    echo ""
done

