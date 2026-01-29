#!/bin/bash

echo "🔍 VERIFICANDO CONFIGURAÇÃO DO WARP BSC → TERRA"
echo "================================================"
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}📋 INFORMAÇÕES NECESSÁRIAS:${NC}"
echo ""
echo "Para configurar corretamente o relayer para BSC → Terra, preciso:"
echo ""
echo "1. 🏦 Endereço do seu WARP CONTRACT no BSC"
echo "2. 💰 Endereço do seu INTERCHAIN GAS PAYMASTER personalizado no BSC"
echo "3. 🔐 Endereço do seu ISM (MessageIdMultisigIsm) configurado no warp BSC"
echo "4. ✅ Endereço do VALIDADOR Terra Classic já anunciado"
echo ""
echo "============================================================"
echo ""
echo -e "${GREEN}📝 COMO OBTER ESSAS INFORMAÇÕES:${NC}"
echo ""
echo "1. WARP CONTRACT BSC:"
echo "   - É o contrato que você deployou no BSC testnet"
echo "   - Exemplo: 0x..."
echo ""
echo "2. INTERCHAIN GAS PAYMASTER:"
echo "   - Você disse que criou um personalizado para taxas do Terra"
echo "   - Deve estar associado ao seu warp"
echo ""
echo "3. ISM (Interchain Security Module):"
echo "   - É o módulo que define quais validadores são aceitos"
echo "   - Você configurou para aceitar o validador Terra Classic"
echo ""
echo "4. VALIDADOR TERRA CLASSIC:"
echo "   - Endereço: 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0"
echo "   - S3 Bucket: hyperlane-validator-signatures-igorverasvalidador-terraclassic"
echo ""
echo "============================================================"
echo ""
echo -e "${YELLOW}🔧 ARQUIVO A SER ATUALIZADO:${NC}"
echo "   hyperlane/agent-config.docker-testnet.json"
echo ""
echo "Seção 'bsctestnet' precisa ter:"
echo "  - interchainGasPaymaster: <SEU_IGP_PERSONALIZADO>"
echo "  - interchainSecurityModule: <SEU_ISM> (opcional)"
echo ""
echo "============================================================"
echo ""
echo -e "${GREEN}✅ VERIFICAÇÃO ATUAL:${NC}"
echo ""

# Ler configuração atual
CONFIG_FILE="/home/lunc/hyperlane-validator-smart/hyperlane/agent-config.docker-testnet.json"

if [ -f "$CONFIG_FILE" ]; then
    echo "IGP atual do BSC:"
    jq -r '.chains.bsctestnet.interchainGasPaymaster // "NÃO CONFIGURADO"' "$CONFIG_FILE"
    echo ""
    
    echo "ISM atual do BSC:"
    jq -r '.chains.bsctestnet.interchainSecurityModule // "NÃO CONFIGURADO"' "$CONFIG_FILE"
    echo ""
    
    echo "Mailbox do BSC:"
    jq -r '.chains.bsctestnet.mailbox // "NÃO CONFIGURADO"' "$CONFIG_FILE"
    echo ""
else
    echo -e "${RED}Arquivo de configuração não encontrado!${NC}"
fi

echo "============================================================"
echo ""
echo -e "${YELLOW}⚠️  PRÓXIMOS PASSOS:${NC}"
echo ""
echo "1. Me forneça os endereços do seu warp BSC:"
echo "   - Endereço do contrato warp"
echo "   - Endereço do IGP personalizado"
echo "   - Endereço do ISM configurado"
echo ""
echo "2. Vou atualizar o agent-config.docker-testnet.json"
echo ""
echo "3. Reiniciar o relayer para aplicar as mudanças"
echo ""
echo "4. Testar novamente a mensagem BSC → Terra"
echo ""
