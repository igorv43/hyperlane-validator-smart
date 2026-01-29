#!/bin/bash

################################################################################
# Script: Atualizar Blocos de Todas as Chains
# Descrição: Consulta os blocos/slots atuais de todas as chains e atualiza
#            o arquivo agent-config.docker-testnet.json automaticamente
# Autor: Hyperlane Validator Smart
# Data: 2026-01-29
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔄 ATUALIZAÇÃO AUTOMÁTICA DE BLOCOS - TODAS AS CHAINS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Diretório de trabalho
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/hyperlane/agent-config.docker-testnet.json"
TEMP_DIR="/tmp/hyperlane-blocks"

# Criar diretório temporário
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}📂 Diretório de trabalho:${NC} $SCRIPT_DIR"
echo -e "${BLUE}📄 Arquivo de configuração:${NC} $CONFIG_FILE"
echo ""

# Verificar se o arquivo de configuração existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Erro: Arquivo $CONFIG_FILE não encontrado!${NC}"
    exit 1
fi

# Verificar se jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ Erro: 'jq' não está instalado. Instale com: sudo apt install jq${NC}"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 CONSULTANDO BLOCOS ATUAIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ==============================================================================
# 1. TERRA CLASSIC TESTNET
# ==============================================================================
echo -e "${YELLOW}1️⃣  TERRA CLASSIC TESTNET${NC}"
echo "   Chain ID: 1325"
echo -n "   Consultando RPC... "

TERRA_BLOCK=""
TERRA_RPCS=(
    "https://terra-testnet-rpc.polkachu.com"
    "https://terra-testnet-rpc.publicnode.com"
    "https://rpc.pisco.terra.dev"
)

for rpc in "${TERRA_RPCS[@]}"; do
    TERRA_BLOCK=$(curl -s "$rpc/status" 2>/dev/null | jq -r '.result.sync_info.latest_block_height' 2>/dev/null || echo "")
    if [ -n "$TERRA_BLOCK" ] && [ "$TERRA_BLOCK" != "null" ]; then
        echo -e "${GREEN}✅${NC}"
        echo "   RPC usado: $rpc"
        echo -e "   ${GREEN}Bloco atual: $TERRA_BLOCK${NC}"
        echo "$TERRA_BLOCK" > "$TEMP_DIR/terra_block.txt"
        break
    fi
done

if [ -z "$TERRA_BLOCK" ] || [ "$TERRA_BLOCK" == "null" ]; then
    echo -e "${RED}❌ Falha ao consultar${NC}"
    echo -e "${YELLOW}⚠️  Usando valor padrão: 20731645${NC}"
    TERRA_BLOCK="20731645"
    echo "$TERRA_BLOCK" > "$TEMP_DIR/terra_block.txt"
fi

echo ""

# ==============================================================================
# 2. BSC TESTNET
# ==============================================================================
echo -e "${YELLOW}2️⃣  BSC TESTNET${NC}"
echo "   Chain ID: 97"
echo -n "   Consultando RPC... "

BSC_BLOCK=""
BSC_RPCS=(
    "https://bsc-testnet.drpc.org"
    "https://data-seed-prebsc-1-s1.binance.org:8545"
    "https://bsc-testnet.public.blastapi.io"
)

for rpc in "${BSC_RPCS[@]}"; do
    if command -v cast &> /dev/null; then
        BSC_BLOCK=$(cast block-number --rpc-url "$rpc" 2>/dev/null || echo "")
    else
        # Fallback para curl + jq
        BSC_BLOCK=$(curl -s "$rpc" -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | \
            jq -r '.result' 2>/dev/null | xargs printf "%d\n" 2>/dev/null || echo "")
    fi
    
    if [ -n "$BSC_BLOCK" ] && [ "$BSC_BLOCK" != "null" ] && [ "$BSC_BLOCK" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        echo "   RPC usado: $rpc"
        echo -e "   ${GREEN}Bloco atual: $BSC_BLOCK${NC}"
        echo "$BSC_BLOCK" > "$TEMP_DIR/bsc_block.txt"
        break
    fi
done

if [ -z "$BSC_BLOCK" ] || [ "$BSC_BLOCK" == "null" ] || [ "$BSC_BLOCK" -le 0 ] 2>/dev/null; then
    echo -e "${RED}❌ Falha ao consultar${NC}"
    echo -e "${YELLOW}⚠️  Usando valor padrão: 87295507${NC}"
    BSC_BLOCK="87295507"
    echo "$BSC_BLOCK" > "$TEMP_DIR/bsc_block.txt"
fi

echo ""

# ==============================================================================
# 3. SOLANA TESTNET
# ==============================================================================
echo -e "${YELLOW}3️⃣  SOLANA TESTNET${NC}"
echo "   Domain ID: 1399811150"
echo -n "   Consultando RPC... "

SOLANA_SLOT=""
SOLANA_RPCS=(
    "https://api.testnet.solana.com"
    "https://solana-testnet.rpc.extrnode.com"
)

for rpc in "${SOLANA_RPCS[@]}"; do
    SOLANA_SLOT=$(curl -s "$rpc" -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' 2>/dev/null | \
        jq -r '.result' 2>/dev/null || echo "")
    
    if [ -n "$SOLANA_SLOT" ] && [ "$SOLANA_SLOT" != "null" ] && [ "$SOLANA_SLOT" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        echo "   RPC usado: $rpc"
        echo -e "   ${GREEN}Slot atual: $SOLANA_SLOT${NC}"
        echo "$SOLANA_SLOT" > "$TEMP_DIR/solana_slot.txt"
        break
    fi
done

if [ -z "$SOLANA_SLOT" ] || [ "$SOLANA_SLOT" == "null" ] || [ "$SOLANA_SLOT" -le 0 ] 2>/dev/null; then
    echo -e "${RED}❌ Falha ao consultar${NC}"
    echo -e "${YELLOW}⚠️  Usando valor padrão: 384872978${NC}"
    SOLANA_SLOT="384872978"
    echo "$SOLANA_SLOT" > "$TEMP_DIR/solana_slot.txt"
fi

echo ""

# ==============================================================================
# 4. SEPOLIA (ETHEREUM TESTNET)
# ==============================================================================
echo -e "${YELLOW}4️⃣  SEPOLIA${NC}"
echo "   Chain ID: 11155111"
echo -n "   Consultando RPC... "

SEPOLIA_BLOCK=""
SEPOLIA_RPCS=(
    "https://1rpc.io/sepolia"
    "https://rpc.ankr.com/eth_sepolia"
    "https://sepolia.drpc.org"
    "https://eth-sepolia-public.unifra.io"
)

for rpc in "${SEPOLIA_RPCS[@]}"; do
    if command -v cast &> /dev/null; then
        SEPOLIA_BLOCK=$(cast block-number --rpc-url "$rpc" 2>/dev/null || echo "")
    else
        # Fallback para curl + jq
        SEPOLIA_BLOCK=$(curl -s "$rpc" -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | \
            jq -r '.result' 2>/dev/null | xargs printf "%d\n" 2>/dev/null || echo "")
    fi
    
    if [ -n "$SEPOLIA_BLOCK" ] && [ "$SEPOLIA_BLOCK" != "null" ] && [ "$SEPOLIA_BLOCK" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        echo "   RPC usado: $rpc"
        echo -e "   ${GREEN}Bloco atual: $SEPOLIA_BLOCK${NC}"
        echo "$SEPOLIA_BLOCK" > "$TEMP_DIR/sepolia_block.txt"
        break
    fi
done

if [ -z "$SEPOLIA_BLOCK" ] || [ "$SEPOLIA_BLOCK" == "null" ] || [ "$SEPOLIA_BLOCK" -le 0 ] 2>/dev/null; then
    echo -e "${RED}❌ Falha ao consultar${NC}"
    echo -e "${YELLOW}⚠️  Usando valor padrão: 10150017${NC}"
    SEPOLIA_BLOCK="10150017"
    echo "$SEPOLIA_BLOCK" > "$TEMP_DIR/sepolia_block.txt"
fi

echo ""

# ==============================================================================
# RESUMO DOS BLOCOS CONSULTADOS
# ==============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 RESUMO DOS BLOCOS CONSULTADOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TERRA=$(cat "$TEMP_DIR/terra_block.txt")
BSC=$(cat "$TEMP_DIR/bsc_block.txt")
SOLANA=$(cat "$TEMP_DIR/solana_slot.txt")
SEPOLIA=$(cat "$TEMP_DIR/sepolia_block.txt")

echo -e "${GREEN}✅ Terra Classic Testnet:${NC} $TERRA"
echo -e "${GREEN}✅ BSC Testnet:${NC}          $BSC"
echo -e "${GREEN}✅ Solana Testnet:${NC}       $SOLANA"
echo -e "${GREEN}✅ Sepolia:${NC}              $SEPOLIA"
echo ""

# ==============================================================================
# ATUALIZAR ARQUIVO DE CONFIGURAÇÃO
# ==============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  💾 ATUALIZANDO ARQUIVO DE CONFIGURAÇÃO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Criar backup do arquivo original
BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${BLUE}📋 Backup criado:${NC} $BACKUP_FILE"
echo ""

# Atualizar usando jq
jq --arg terra "$TERRA" \
   --arg bsc "$BSC" \
   --arg solana "$SOLANA" \
   --arg sepolia "$SEPOLIA" \
   '.chains.terraclassictestnet.index.from = ($terra | tonumber) |
    .chains.bsctestnet.index.from = ($bsc | tonumber) |
    .chains.solanatestnet.index.from = ($solana | tonumber) |
    .chains.sepolia.index.from = ($sepolia | tonumber)' \
   "$CONFIG_FILE" > "$TEMP_DIR/agent-config-updated.json"

# Verificar se a atualização foi bem-sucedida
if [ $? -eq 0 ]; then
    mv "$TEMP_DIR/agent-config-updated.json" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Arquivo atualizado com sucesso!${NC}"
    echo ""
    
    # Mostrar valores atualizados
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ VALORES ATUALIZADOS NO CONFIG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo -e "${BLUE}Terra Classic Testnet:${NC}"
    jq '.chains.terraclassictestnet.index' "$CONFIG_FILE"
    echo ""
    
    echo -e "${BLUE}BSC Testnet:${NC}"
    jq '.chains.bsctestnet.index' "$CONFIG_FILE"
    echo ""
    
    echo -e "${BLUE}Solana Testnet:${NC}"
    jq '.chains.solanatestnet.index' "$CONFIG_FILE"
    echo ""
    
    echo -e "${BLUE}Sepolia:${NC}"
    jq '.chains.sepolia.index' "$CONFIG_FILE"
    echo ""
else
    echo -e "${RED}❌ Erro ao atualizar o arquivo!${NC}"
    echo -e "${YELLOW}⚠️  O backup está disponível em: $BACKUP_FILE${NC}"
    exit 1
fi

# ==============================================================================
# FINALIZAÇÃO
# ==============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎉 ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${GREEN}✅ Próximos passos:${NC}"
echo ""
echo "1. Reinicie o relayer para aplicar as mudanças:"
echo -e "   ${YELLOW}docker-compose -f docker-compose-testnet.yml restart relayer${NC}"
echo ""
echo "2. Verifique os logs:"
echo -e "   ${YELLOW}docker logs -f hpl-relayer-testnet${NC}"
echo ""
echo "3. Confirme a sincronização:"
echo -e "   ${YELLOW}docker logs hpl-relayer-testnet 2>&1 | grep 'synced'${NC}"
echo ""

# Perguntar se deseja reiniciar o relayer automaticamente
read -p "🔄 Deseja reiniciar o relayer agora? (s/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    echo ""
    echo -e "${BLUE}🔄 Reiniciando relayer...${NC}"
    docker-compose -f "$SCRIPT_DIR/docker-compose-testnet.yml" restart relayer
    echo ""
    echo -e "${GREEN}✅ Relayer reiniciado!${NC}"
    echo ""
    echo "Aguardando 10 segundos para inicialização..."
    sleep 10
    echo ""
    echo -e "${BLUE}📊 Últimos logs:${NC}"
    docker logs hpl-relayer-testnet --tail 20
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ SCRIPT FINALIZADO${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
