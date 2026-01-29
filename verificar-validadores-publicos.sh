#!/bin/bash

echo "🔍 VERIFICANDO VALIDADORES PÚBLICOS DO HYPERLANE"
echo "=================================================="
echo ""

# Validadores públicos do Hyperlane para BSC
VALIDATORS=(
    "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
    "0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"
    "0x1f030345963c54ff8229720dd3a711c15c554aeb"
)

RPC_URL="https://bsc-testnet.publicnode.com"
VALIDATOR_ANNOUNCE="0xf09701B0a93210113D175461b6135a96773B5465"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}📋 Validadores a verificar:${NC}"
for i in "${!VALIDATORS[@]}"; do
    echo "  $((i+1)). ${VALIDATORS[$i]}"
done
echo ""
echo "=================================================="
echo ""

# Verificar se cast está instalado
if ! command -v cast &> /dev/null; then
    echo "❌ 'cast' não encontrado. Por favor instale Foundry."
    exit 1
fi

# Função para verificar anúncio do validador
check_validator_announce() {
    local validator=$1
    local index=$2
    
    echo -e "${BLUE}[$((index+1))/3] Verificando validador: ${validator}${NC}"
    echo ""
    
    # getAnnouncedStorageLocations(address[]) no ValidatorAnnounce
    # Signature: getAnnouncedStorageLocations(address[])
    
    # Construir calldata manualmente
    # getAnnouncedStorageLocations(address[]) = 0x843f6f9d
    
    # Usar cast para chamar diretamente
    echo "   🔍 Buscando storage locations anunciadas..."
    
    # Tentar buscar eventos de announcement
    # Evento Announcement: keccak256("Announcement(address,string,string)")
    ANNOUNCEMENT_TOPIC="0x4862b421c27e5dfe2d78825305c85eea0c99ebf1cfd4ff45e6b79d6ea4a7d445"
    
    # Buscar os últimos 10000 blocos
    LATEST_BLOCK=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)
    FROM_BLOCK=$((LATEST_BLOCK - 10000))
    
    if [ -z "$LATEST_BLOCK" ]; then
        echo -e "   ${RED}❌ Não foi possível obter o bloco mais recente${NC}"
        echo ""
        return
    fi
    
    echo "   📍 Buscando eventos do bloco $FROM_BLOCK até $LATEST_BLOCK..."
    
    # Buscar eventos de Announcement para este validador
    EVENTS=$(cast logs \
        --from-block "$FROM_BLOCK" \
        --to-block "$LATEST_BLOCK" \
        --address "$VALIDATOR_ANNOUNCE" \
        "Announcement(address indexed validator, string storageLocation, string signature)" \
        --rpc-url "$RPC_URL" 2>/dev/null | grep -i "${validator:2}" | head -1)
    
    if [ -n "$EVENTS" ]; then
        echo -e "   ${GREEN}✅ Validador fez announcement recentemente!${NC}"
        echo "   📦 Eventos encontrados nos últimos 10000 blocos"
    else
        echo -e "   ${YELLOW}⚠️  Nenhum announcement recente encontrado${NC}"
        echo "   ℹ️  Validador pode não estar ativo no testnet"
    fi
    
    echo ""
}

# Verificar cada validador
for i in "${!VALIDATORS[@]}"; do
    check_validator_announce "${VALIDATORS[$i]}" "$i"
done

echo "=================================================="
echo ""
echo -e "${YELLOW}📊 ANÁLISE:${NC}"
echo ""

# Verificar a última mensagem detectada pelo relayer
echo "Verificando relayer logs para validadores..."
docker logs hpl-relayer-testnet 2>&1 | grep -A 2 "List of validators" | tail -10

echo ""
echo "=================================================="
echo ""
echo -e "${YELLOW}🔍 DIAGNÓSTICO:${NC}"
echo ""

# Contar quantos validators foram encontrados
FOUND_COUNT=0
for validator in "${VALIDATORS[@]}"; do
    LATEST_BLOCK=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)
    FROM_BLOCK=$((LATEST_BLOCK - 10000))
    
    EVENTS=$(cast logs \
        --from-block "$FROM_BLOCK" \
        --to-block "$LATEST_BLOCK" \
        --address "$VALIDATOR_ANNOUNCE" \
        "Announcement(address indexed validator, string storageLocation, string signature)" \
        --rpc-url "$RPC_URL" 2>/dev/null | grep -i "${validator:2}" | wc -l)
    
    if [ "$EVENTS" -gt 0 ]; then
        FOUND_COUNT=$((FOUND_COUNT + 1))
    fi
done

if [ "$FOUND_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ PROBLEMA: Nenhum validador público encontrou announcements recentes${NC}"
    echo ""
    echo "   Isso significa que os validadores públicos do Hyperlane provavelmente"
    echo "   NÃO ESTÃO ATIVOS no BSC testnet, ou não fizeram announcements recentemente."
    echo ""
    echo -e "${YELLOW}📝 SOLUÇÃO RECOMENDADA:${NC}"
    echo ""
    echo "   Reconfigurar o ISM do seu warp BSC para usar SEU validador:"
    echo "   • Validador: 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0"
    echo "   • S3: hyperlane-validator-signatures-igorverasvalidador-terraclassic"
    echo "   • Threshold: 1"
    echo ""
    echo "   Isso garantirá que mensagens BSC → Terra funcionem como Terra → BSC funciona."
    echo ""
elif [ "$FOUND_COUNT" -lt 2 ]; then
    echo -e "${YELLOW}⚠️  ATENÇÃO: Apenas $FOUND_COUNT validador(es) ativo(s)${NC}"
    echo ""
    echo "   Threshold necessário: 2 de 3"
    echo "   Validadores ativos: $FOUND_COUNT"
    echo ""
    echo "   Suas mensagens BSC → Terra podem não ser entregues porque"
    echo "   não há validadores suficientes para alcançar quorum."
    echo ""
else
    echo -e "${GREEN}✅ BOAS NOTÍCIAS: $FOUND_COUNT validadores ativos encontrados!${NC}"
    echo ""
    echo "   Suas mensagens BSC → Terra devem ser entregues."
    echo "   Se ainda não chegaram, aguarde alguns minutos."
    echo ""
fi

echo "=================================================="
echo ""

# Verificar se há mensagens pendentes no relayer
PENDING=$(docker logs hpl-relayer-testnet 2>&1 | grep "Unable to reach quorum" | grep "origin: bsctestnet" | tail -3)

if [ -n "$PENDING" ]; then
    echo -e "${YELLOW}⏳ MENSAGENS PENDENTES:${NC}"
    echo ""
    echo "$PENDING" | grep -o "id: 0x[a-f0-9]*" | head -5
    echo ""
fi

echo "Para monitorar em tempo real:"
echo -e "${BLUE}docker logs hpl-relayer-testnet -f | grep -E '(0xc3c2066f|0xab8c5e49)'${NC}"
echo ""
