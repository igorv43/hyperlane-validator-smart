#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  DIAGNÓSTICO: MENSAGEM TERRA CLASSIC -> SOLANA NÃO CHEGOU                ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

TERRA_CHAIN_ID="rebel-2"
TERRA_RPC="https://rpc.luncblaze.com:443"
VALIDATOR_ANNOUNCE_TERRA="terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5"
SOLANA_DOMAIN=1399811150
TERRA_DOMAIN=1325

echo "🔍 PASSO 1: Verificar Validators do Terra Classic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

QUERY_VALIDATORS='{"get_announced_validators":{}}'
RESPONSE=$(terrad query wasm contract-state smart "$VALIDATOR_ANNOUNCE_TERRA" \
    "$QUERY_VALIDATORS" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1)

if echo "$RESPONSE" | jq -e '.data.validators' > /dev/null 2>&1; then
    VALIDATORS=$(echo "$RESPONSE" | jq -r '.data.validators[]' 2>/dev/null)
    COUNT=$(echo "$VALIDATORS" | wc -l)
    echo "✅ $COUNT validator(s) anunciado(s) no Terra Classic:"
    echo "$VALIDATORS" | while read -r VAL; do
        echo "  • $VAL"
        
        # Verificar storage locations
        VAL_CLEAN=$(echo "$VAL" | sed 's/^0x//')
        QUERY_STORAGE="{\"get_announce_storage_locations\":{\"validators\":[\"$VAL_CLEAN\"]}}"
        STORAGE_RESPONSE=$(terrad query wasm contract-state smart "$VALIDATOR_ANNOUNCE_TERRA" \
            "$QUERY_STORAGE" \
            --chain-id "$TERRA_CHAIN_ID" \
            --node "$TERRA_RPC" \
            --output json 2>&1)
        
        if echo "$STORAGE_RESPONSE" | jq -e '.data.storage_locations' > /dev/null 2>&1; then
            STORAGE=$(echo "$STORAGE_RESPONSE" | jq -r '.data.storage_locations[0][1][0] // "N/A"' 2>/dev/null)
            if [ "$STORAGE" != "null" ] && [ "$STORAGE" != "N/A" ]; then
                echo "    → Storage: $STORAGE"
            fi
        fi
    done
else
    echo "❌ Erro ao consultar validators: $(echo "$RESPONSE" | head -3)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 2: Verificar Checkpoints no S3 (Terra Classic -> Solana)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar storage location do validator
VALIDATOR_HEX="8804770d6a346210c0fd011258fdf3ab0a5bb0d0"
QUERY_STORAGE="{\"get_announce_storage_locations\":{\"validators\":[\"$VALIDATOR_HEX\"]}}"
STORAGE_RESPONSE=$(terrad query wasm contract-state smart "$VALIDATOR_ANNOUNCE_TERRA" \
    "$QUERY_STORAGE" \
    --chain-id "$TERRA_CHAIN_ID" \
    --node "$TERRA_RPC" \
    --output json 2>&1)

if echo "$STORAGE_RESPONSE" | jq -e '.data.storage_locations' > /dev/null 2>&1; then
    STORAGE=$(echo "$STORAGE_RESPONSE" | jq -r '.data.storage_locations[0][1][0] // "N/A"' 2>/dev/null)
    
    if [ "$STORAGE" != "null" ] && [ "$STORAGE" != "N/A" ]; then
        echo "✅ Storage location encontrada: $STORAGE"
        
        # Extrair bucket S3
        if [[ "$STORAGE" == s3://* ]]; then
            BUCKET=$(echo "$STORAGE" | sed -E 's|s3://([^/]+).*|\1|')
            PREFIX=$(echo "$STORAGE" | sed -E 's|s3://[^/]+/?(.*)|\1|')
            
            echo "  Bucket: $BUCKET"
            echo "  Prefix: $PREFIX"
            echo ""
            
            # Verificar checkpoints recentes
            if [ ! -z "$PREFIX" ]; then
                S3_PATH="s3://${BUCKET}/${PREFIX}/"
            else
                S3_PATH="s3://${BUCKET}/"
            fi
            
            echo "  Verificando checkpoints em: $S3_PATH"
            
            if command -v aws &> /dev/null; then
                FILES=$(aws s3 ls "$S3_PATH" --recursive 2>/dev/null | grep -i checkpoint | tail -10 || echo "")
                if [ ! -z "$FILES" ]; then
                    echo "  ✅ Checkpoints encontrados:"
                    echo "$FILES" | awk '{print "    - " $4 " (" $1 " " $2 ")"}'
                else
                    echo "  ⚠️  Nenhum checkpoint encontrado"
                fi
            else
                # Tentar via URL pública
                if [ ! -z "$PREFIX" ]; then
                    URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/${PREFIX}/"
                else
                    URL="https://${BUCKET}.s3.us-east-1.amazonaws.com/"
                fi
                echo "  URL pública: $URL"
                echo "  ⚠️  AWS CLI não disponível para listar arquivos"
            fi
        fi
    else
        echo "  ⚠️  Storage location não encontrada ou inválida"
    fi
else
    echo "❌ Erro ao consultar storage locations"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PASSO 3: Verificar ISM do Solana para Terra Classic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  Domain Terra Classic: $TERRA_DOMAIN"
echo "  Domain Solana: $SOLANA_DOMAIN"
echo ""
echo "  ⚠️  Para verificar o ISM do Solana, é necessário:"
echo "     1. Consultar o Mailbox do Solana"
echo "     2. Verificar o ISM configurado para domain $TERRA_DOMAIN"
echo "     3. Verificar se há validators do Terra Classic no ISM do Solana"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMO E PRÓXIMOS PASSOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Possíveis causas da mensagem não chegar:"
echo ""
echo "1. ❌ Validator do Terra Classic não está gerando checkpoints"
echo "   → Verificar logs do validator"
echo "   → Verificar se há checkpoints no S3"
echo ""
echo "2. ❌ Relayer não está processando mensagens Terra->Solana"
echo "   → Verificar logs do relayer"
echo "   → Verificar se o relayer está configurado para Solana"
echo ""
echo "3. ❌ ISM do Solana não tem validators do Terra Classic"
echo "   → Verificar ISM do Solana para domain $TERRA_DOMAIN"
echo "   → Verificar se os validators estão anunciados no Solana"
echo ""
echo "4. ❌ Quorum não está sendo atingido"
echo "   → Verificar threshold do ISM"
echo "   → Verificar quantos validators têm checkpoints"
echo ""

