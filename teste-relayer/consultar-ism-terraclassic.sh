#!/bin/bash

# ============================================================================
# Script: Consultar ISM do Terra Classic para Domain 97 (BSC)
# ============================================================================
# Este script consulta o ISM do Warp Route no Terra Classic e exibe
# informações sobre validators e threshold para o domain 97 (BSC Testnet)
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️${NC}  $1"
}

print_success() {
    echo -e "${GREEN}✅${NC}  $1"
}

print_error() {
    echo -e "${RED}❌${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC}  $1"
}

print_value() {
    echo -e "  ${YELLOW}$1${NC}"
}

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

ISM_TERRA="terra1na6ljyf4m5x2u7llfvvxxe2nyq0t8628qyk0vnwu4ttpq86tt0cse47t68"
WARP_ROUTE="terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml"
DOMAIN_97="97"  # BSC Testnet
TERRA_REST="https://lcd.luncblaze.com"
TERRA_RPC="https://rpc.luncblaze.com:443"

# Verificar se jq está disponível
if ! command -v jq &> /dev/null; then
    print_error "jq não está instalado. Instale com: sudo apt-get install jq"
    exit 1
fi

# ============================================================================
# INÍCIO DO SCRIPT
# ============================================================================

print_header "CONSULTAR ISM DO TERRA CLASSIC PARA DOMAIN 97 (BSC)"

print_info "Configurações:"
print_value "ISM Terra Classic: $ISM_TERRA"
print_value "Warp Route: $WARP_ROUTE"
print_value "Domain: $DOMAIN_97 (BSC Testnet)"
print_value "REST API: $TERRA_REST"
echo ""

# ============================================================================
# 1. CONSULTAR INFORMAÇÕES DO CONTRATO ISM
# ============================================================================

print_section "1. CONSULTAR INFORMAÇÕES DO ISM"

print_info "Consultando informações do contrato ISM..."

# Converter endereço bech32 para hex para usar na query
# O contrato ISM no Terra Classic é um contrato CosmWasm
# Precisamos fazer uma query smart contract

# Query para obter validators do ISM para domain 97
# O formato correto é multisig_ism com enrolled_validators

print_info "Consultando validators do ISM para domain 97 (BSC Testnet)..."

# Query para obter validators inscritos para o domain 97
QUERY_VALIDATORS='{"multisig_ism":{"enrolled_validators":{"domain":97}}}'

print_value "Query: $QUERY_VALIDATORS"

# Usar terrad para consultar o contrato
print_info "Usando terrad para consultar o contrato ISM..."

# Configurar terrad para testnet
TERRAD_NODE="${TERRA_RPC}"
TERRAD_CHAIN_ID="rebel-2"

# Consultar validators inscritos para domain 97
print_info "Consultando validators inscritos para domain 97..."
QUERY_RESPONSE=$(terrad query wasm contract-state smart \
  "${ISM_TERRA}" \
  "${QUERY_VALIDATORS}" \
  --node "${TERRAD_NODE}" \
  --chain-id "${TERRAD_CHAIN_ID}" \
  --output json 2>&1)

# Se terrad não funcionar, tentar via REST API como fallback
if echo "$QUERY_RESPONSE" | grep -qiE "error|failed|not found"; then
    print_warning "⚠️  terrad não funcionou. Tentando via REST API..."
    
    # Tentar via REST API com formato correto
    QUERY_BASE64=$(echo -n "$QUERY_JSON" | base64 -w 0 2>/dev/null || echo -n "$QUERY_JSON" | base64)
    
    QUERY_RESPONSE=$(curl -s -X GET \
      "${TERRA_REST}/cosmwasm/wasm/v1/contract/${ISM_TERRA}/smart/${QUERY_BASE64}" \
      -H "Content-Type: application/json" 2>&1)
fi

if echo "$QUERY_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    print_success "✅ Query bem-sucedida!"
    echo ""
    echo "$QUERY_RESPONSE" | jq '.'
    
    # Extrair validators do formato multisig_ism
    VALIDATORS=$(echo "$QUERY_RESPONSE" | jq -r '.data.validators // .data.enrolled_validators // empty' 2>/dev/null)
    THRESHOLD=$(echo "$QUERY_RESPONSE" | jq -r '.data.threshold // empty' 2>/dev/null)
    
    if [ ! -z "$VALIDATORS" ] && [ "$VALIDATORS" != "null" ]; then
        print_success "✅ Validators encontrados:"
        # Validators podem estar em formato array ou objeto
        if echo "$VALIDATORS" | jq -e 'type == "array"' > /dev/null 2>&1; then
            echo "$VALIDATORS" | jq -r '.[]' 2>/dev/null | while read -r validator; do
                if [ ! -z "$validator" ]; then
                    print_value "  - $validator"
                fi
            done
        else
            # Pode ser um objeto com validators dentro
            echo "$VALIDATORS" | jq -r 'to_entries[] | .value' 2>/dev/null | while read -r validator; do
                if [ ! -z "$validator" ]; then
                    print_value "  - $validator"
                fi
            done
        fi
    fi
    
    if [ ! -z "$THRESHOLD" ] && [ "$THRESHOLD" != "null" ]; then
        print_success "✅ Threshold: $THRESHOLD"
    fi
else
    print_warning "⚠️  Query direta não funcionou. Tentando outros formatos..."
    echo ""
    
    # Query 2: Tentar com formato diferente
    QUERY_JSON2='{"validators_and_threshold":{"destination_domain":97}}'
    print_info "Tentando query alternativa: $QUERY_JSON2"
    
    QUERY_RESPONSE2=$(curl -s -X GET \
      "${TERRA_REST}/cosmwasm/wasm/v1/contract/${ISM_TERRA}/smart/${QUERY_JSON2}" \
      -H "Content-Type: application/json" 2>&1)
    
    if echo "$QUERY_RESPONSE2" | jq -e '.data' > /dev/null 2>&1; then
        print_success "✅ Query alternativa bem-sucedida!"
        echo ""
        echo "$QUERY_RESPONSE2" | jq '.'
    else
        print_error "❌ Não foi possível consultar o ISM com os formatos testados"
        echo ""
        print_info "Resposta da API:"
        echo "$QUERY_RESPONSE2" | jq '.' 2>/dev/null || echo "$QUERY_RESPONSE2"
        echo ""
        print_warning "⚠️  Pode ser necessário verificar a estrutura exata do contrato ISM"
    fi
fi

echo ""

# ============================================================================
# 2. CONSULTAR INFORMAÇÕES DO WARP ROUTE
# ============================================================================

print_section "2. CONSULTAR INFORMAÇÕES DO WARP ROUTE"

print_info "Consultando informações do Warp Route..."

# Query para obter o ISM do Warp Route (para confirmar)
QUERY_WARP_ISM='{"interchain_security_module":{}}'

WARP_RESPONSE=$(curl -s -X GET \
  "${TERRA_REST}/cosmwasm/wasm/v1/contract/${WARP_ROUTE}/smart/${QUERY_WARP_ISM}" \
  -H "Content-Type: application/json" 2>&1)

if echo "$WARP_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    WARP_ISM=$(echo "$WARP_RESPONSE" | jq -r '.data' 2>/dev/null)
    print_success "✅ ISM do Warp Route: $WARP_ISM"
    
    if [ "$WARP_ISM" = "$ISM_TERRA" ]; then
        print_success "✅ ISM confere com o fornecido!"
    else
        print_warning "⚠️  ISM do Warp Route difere do fornecido"
        print_value "  Fornecido: $ISM_TERRA"
        print_value "  Retornado: $WARP_ISM"
    fi
else
    print_warning "⚠️  Não foi possível consultar o ISM do Warp Route"
fi

echo ""

# ============================================================================
# 3. RESUMO FINAL
# ============================================================================

print_section "RESUMO"

print_success "✅ Informações consultadas:"
echo ""
print_info "Warp Route Terra Classic:"
print_value "  Endereço: $WARP_ROUTE"
print_value "  Explorer: https://finder.terraclassic.community/testnet/address/$WARP_ROUTE"
echo ""
print_info "ISM (Interchain Security Module):"
print_value "  Endereço: $ISM_TERRA"
print_value "  Explorer: https://finder.terraclassic.community/testnet/address/$ISM_TERRA"
echo ""
print_info "Configuração para Domain 97 (BSC Testnet):"
if [ ! -z "$VALIDATORS" ] && [ "$VALIDATORS" != "null" ]; then
    print_value "  Validators:"
    echo "$VALIDATORS" | jq -r '.[]' 2>/dev/null | while read -r validator; do
        if [ ! -z "$validator" ]; then
            print_value "    - $validator"
        fi
    done
fi
if [ ! -z "$THRESHOLD" ] && [ "$THRESHOLD" != "null" ]; then
    print_value "  Threshold: $THRESHOLD"
fi
echo ""

print_success "✅ Consulta concluída!"
