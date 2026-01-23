#!/bin/bash

# ============================================================================
# Script: Consultar ISM do Warp Route BSC
# ============================================================================
# Este script consulta o ISM associado a um Warp Route BSC e exibe
# os validadores configurados para o domain 1325 (Terra Classic)
# Uso: ./consultar-ism-warp-bsc.sh <endereco_warp_bsc>
# Exemplo: ./consultar-ism-warp-bsc.sh 0x2144be4477202ba2d50c9a8be3181241878cf7d8
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
# VALIDAÇÃO DE PARÂMETROS
# ============================================================================

if [ $# -eq 0 ]; then
    print_error "Erro: Endereço Warp Route BSC não fornecido"
    echo ""
    echo "Uso: $0 <endereco_warp_bsc>"
    echo ""
    echo "Exemplo:"
    echo "  $0 0x2144be4477202ba2d50c9a8be3181241878cf7d8"
    echo ""
    exit 1
fi

WARP_BSC_ADDRESS="$1"

# Validar formato do endereço EVM (0x...)
if [[ ! "$WARP_BSC_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    print_error "Endereço inválido! Deve ser um endereço EVM válido (0x seguido de 40 caracteres hex)"
    exit 1
fi

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

BSC_RPC="https://bsc-testnet.publicnode.com"
BSC_DOMAIN=97
TERRA_DOMAIN=1325

# Verificar se cast está disponível
if ! command -v cast &> /dev/null; then
    print_error "cast não está instalado ou não está no PATH"
    print_info "Instale Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# ============================================================================
# INÍCIO DO SCRIPT
# ============================================================================

print_header "CONSULTA ISM DO WARP ROUTE BSC"

print_info "Warp Route BSC: $WARP_BSC_ADDRESS"
print_value "Explorer: https://testnet.bscscan.com/address/$WARP_BSC_ADDRESS"
echo ""

# ============================================================================
# CONSULTAR ISM DO WARP ROUTE
# ============================================================================

print_section "CONSULTANDO ISM DO WARP ROUTE"

# Método 1: Consultar diretamente no Warp Route
print_info "Consultando ISM diretamente no Warp Route..."
WARP_ISM=""

ISM_QUERY=$(cast call "$WARP_BSC_ADDRESS" "interchainSecurityModule()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

# Se não encontrou, tentar na implementação (se for proxy)
if echo "$ISM_QUERY" | grep -qi "error\|reverted"; then
    print_value "Tentando consultar na implementação do proxy..."
    IMPL=$(cast implementation "$WARP_BSC_ADDRESS" --rpc-url "$BSC_RPC" 2>&1 | grep -oE "0x[0-9a-f]{40}" | head -1 || echo "")
    if [ ! -z "$IMPL" ]; then
        print_value "Implementation: $IMPL"
        ISM_QUERY=$(cast call "$IMPL" "interchainSecurityModule()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
    fi
fi

# Se ainda não encontrou, consultar Mailbox
if echo "$ISM_QUERY" | grep -qi "error\|reverted"; then
    print_value "Consultando Mailbox para obter ISM padrão..."
    
    # Consultar Mailbox primeiro
    MAILBOX_QUERY=$(cast call "$WARP_BSC_ADDRESS" "mailbox()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
    
    if echo "$MAILBOX_QUERY" | grep -qiE "0x[0-9a-f]+"; then
        MAILBOX_RAW=$(echo "$MAILBOX_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
        if [ ! -z "$MAILBOX_RAW" ]; then
            MAILBOX_CLEAN=$(echo "$MAILBOX_RAW" | sed 's/^0x//' | sed 's/^0*//')
            while [ ${#MAILBOX_CLEAN} -lt 40 ]; do
                MAILBOX_CLEAN="0$MAILBOX_CLEAN"
            done
            MAILBOX="0x$MAILBOX_CLEAN"
            print_value "Mailbox encontrado: $MAILBOX"
            
            # Consultar defaultIsm do Mailbox
            MAILBOX_ISM_QUERY=$(cast call "$MAILBOX" "defaultIsm()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
            if echo "$MAILBOX_ISM_QUERY" | grep -qiE "0x[0-9a-f]+"; then
                ISM_QUERY="$MAILBOX_ISM_QUERY"
                print_value "ISM encontrado no Mailbox (defaultIsm)"
            fi
        fi
    fi
fi

# Extrair ISM se encontrado
WARP_ISM_DIRECT=""
if echo "$ISM_QUERY" | grep -qiE "0x[0-9a-f]+"; then
    ISM_RAW=$(echo "$ISM_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
    if [ ! -z "$ISM_RAW" ]; then
        ISM_CLEAN=$(echo "$ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
        while [ ${#ISM_CLEAN} -lt 40 ]; do
            ISM_CLEAN="0$ISM_CLEAN"
        done
        WARP_ISM_DIRECT="0x$ISM_CLEAN"
        print_success "✅ ISM encontrado no Warp Route: $WARP_ISM_DIRECT"
        print_value "Explorer: https://testnet.bscscan.com/address/$WARP_ISM_DIRECT"
    fi
fi

# Consultar Mailbox para usar como fallback
MAILBOX=""
if echo "$ISM_QUERY" | grep -qi "error\|reverted"; then
    # Consultar Mailbox
    MAILBOX_QUERY=$(cast call "$WARP_BSC_ADDRESS" "mailbox()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
    
    if echo "$MAILBOX_QUERY" | grep -qiE "0x[0-9a-f]+"; then
        MAILBOX_RAW=$(echo "$MAILBOX_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
        if [ ! -z "$MAILBOX_RAW" ]; then
            MAILBOX_CLEAN=$(echo "$MAILBOX_RAW" | sed 's/^0x//' | sed 's/^0*//')
            while [ ${#MAILBOX_CLEAN} -lt 40 ]; do
                MAILBOX_CLEAN="0$MAILBOX_CLEAN"
            done
            MAILBOX="0x$MAILBOX_CLEAN"
        fi
    fi
fi

# Se encontrou ISM direto, usar ele. Senão, tentar Mailbox
if [ ! -z "$WARP_ISM_DIRECT" ]; then
    WARP_ISM="$WARP_ISM_DIRECT"
else
    # Se não encontrou direto, consultar Mailbox
    if [ ! -z "$MAILBOX" ]; then
        print_value "Consultando ISM padrão do Mailbox..."
        MAILBOX_ISM_QUERY=$(cast call "$MAILBOX" "defaultIsm()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
        
        if echo "$MAILBOX_ISM_QUERY" | grep -qiE "0x[0-9a-f]+"; then
            MAILBOX_ISM_RAW=$(echo "$MAILBOX_ISM_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
            if [ ! -z "$MAILBOX_ISM_RAW" ]; then
                MAILBOX_ISM_CLEAN=$(echo "$MAILBOX_ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
                while [ ${#MAILBOX_ISM_CLEAN} -lt 40 ]; do
                    MAILBOX_ISM_CLEAN="0$MAILBOX_ISM_CLEAN"
                done
                WARP_ISM="0x$MAILBOX_ISM_CLEAN"
                print_success "✅ ISM encontrado no Mailbox (defaultIsm): $WARP_ISM"
                print_value "Explorer: https://testnet.bscscan.com/address/$WARP_ISM"
            fi
        fi
    fi
fi

if [ -z "$WARP_ISM" ]; then
    print_error "❌ ISM não encontrado"
    exit 1
fi
echo ""

# ============================================================================
# CONSULTAR TIPO DO ISM
# ============================================================================

print_section "INFORMAÇÕES DO ISM"

print_info "Consultando tipo de ISM..."
MODULE_TYPE_QUERY=$(cast call "$WARP_ISM" "moduleType()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

MODULE_TYPE=""
MODULE_TYPE_NAME=""
if echo "$MODULE_TYPE_QUERY" | grep -qiE "^0x[0-9a-f]+$|^[0-9]+$"; then
    MODULE_TYPE_RAW=$(echo "$MODULE_TYPE_QUERY" | grep -oE "^0x[0-9a-f]+$|^[0-9]+$" | head -1 || echo "")
    if [ ! -z "$MODULE_TYPE_RAW" ]; then
        if [[ "$MODULE_TYPE_RAW" =~ ^0x ]]; then
            MODULE_TYPE=$(cast --to-dec "$MODULE_TYPE_RAW" 2>/dev/null || echo "$MODULE_TYPE_RAW")
        else
            MODULE_TYPE="$MODULE_TYPE_RAW"
        fi
        
        case "$MODULE_TYPE" in
            0) MODULE_TYPE_NAME="UNUSED" ;;
            1) MODULE_TYPE_NAME="ROUTING" ;;
            2) MODULE_TYPE_NAME="AGGREGATION" ;;
            3) MODULE_TYPE_NAME="LEGACY_MULTISIG" ;;
            4) MODULE_TYPE_NAME="MULTISIG" ;;
            5) MODULE_TYPE_NAME="TREASURY" ;;
            *) MODULE_TYPE_NAME="UNKNOWN ($MODULE_TYPE)" ;;
        esac
        
        print_success "✅ Tipo de ISM: $MODULE_TYPE_NAME (Type $MODULE_TYPE)"
    fi
fi
echo ""

# ============================================================================
# CONSULTAR VALIDADORES PARA DOMAIN 1325
# ============================================================================

print_section "VALIDADORES PARA DOMAIN $TERRA_DOMAIN (Terra Classic)"

print_info "Consultando validadores do ISM para domain $TERRA_DOMAIN..."

# Se for ISM Routing (type 1) ou Aggregation (type 2), consultar ISM para este domain
# Também tentar se for TREASURY (type 5) - pode ter estrutura interna
if [ "$MODULE_TYPE" = "1" ] || [ "$MODULE_TYPE" = "2" ] || [ "$MODULE_TYPE" = "5" ]; then
    print_value "ISM é do tipo $MODULE_TYPE_NAME. Consultando ISM configurado para domain $TERRA_DOMAIN..."
    
    # Tentar função route(uint32) para ISM Routing/Aggregation
    ROUTE_QUERY=$(cast call "$WARP_ISM" "route(uint32)" "$TERRA_DOMAIN" --rpc-url "$BSC_RPC" 2>&1 || echo "")
    
    if echo "$ROUTE_QUERY" | grep -qiE "0x[0-9a-f]{40}"; then
        ROUTE_ISM_RAW=$(echo "$ROUTE_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
        if [ ! -z "$ROUTE_ISM_RAW" ]; then
            ROUTE_ISM_CLEAN=$(echo "$ROUTE_ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
            while [ ${#ROUTE_ISM_CLEAN} -lt 40 ]; do
                ROUTE_ISM_CLEAN="0$ROUTE_ISM_CLEAN"
            done
            ROUTE_ISM="0x$ROUTE_ISM_CLEAN"
            print_success "✅ ISM configurado para domain $TERRA_DOMAIN: $ROUTE_ISM"
            print_value "Explorer: https://testnet.bscscan.com/address/$ROUTE_ISM"
            echo ""
            
            # Consultar validators deste ISM
            print_info "Consultando validators do ISM $ROUTE_ISM..."
            VALIDATORS_QUERY=$(cast call "$ROUTE_ISM" "validators()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
            
            VALIDATORS_LIST=()
            if echo "$VALIDATORS_QUERY" | grep -qiE "0x[0-9a-f]{40}"; then
                echo "$VALIDATORS_QUERY" | grep -oE "0x[0-9a-f]{40}" | while read -r validator; do
                    if [ ! -z "$validator" ] && [ "$validator" != "0x0000000000000000000000000000000000000000" ]; then
                        VALIDATORS_LIST+=("$validator")
                    fi
                done
            fi
            
            # Consultar threshold
            THRESHOLD_QUERY=$(cast call "$ROUTE_ISM" "threshold()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
            THRESHOLD=""
            if echo "$THRESHOLD_QUERY" | grep -qiE "^[0-9]+$|^0x[0-9a-f]+$"; then
                THRESHOLD=$(echo "$THRESHOLD_QUERY" | grep -oE "^[0-9]+$|^0x[0-9a-f]+$" | head -1 || echo "")
                if [ ! -z "$THRESHOLD" ]; then
                    if [[ "$THRESHOLD" =~ ^0x ]]; then
                        THRESHOLD=$(cast --to-dec "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
                    fi
                fi
            fi
            
            # Exibir no formato YAML
            if [ ${#VALIDATORS_LIST[@]} -gt 0 ] || [ ! -z "$THRESHOLD" ]; then
                echo ""
                print_success "✅ Configuração encontrada:"
                echo ""
                echo "interchainSecurityModule:"
                echo "    type: messageIdMultisigIsm"
                echo "    validators:"
                
                # Extrair validators novamente (o while em subshell não funciona para array)
                VALIDATORS_OUTPUT=$(echo "$VALIDATORS_QUERY" | grep -oE "0x[0-9a-f]{40}" | grep -v "0x0000000000000000000000000000000000000000" || echo "")
                if [ ! -z "$VALIDATORS_OUTPUT" ]; then
                    echo "$VALIDATORS_OUTPUT" | while read -r validator; do
                        if [ ! -z "$validator" ]; then
                            echo "      - \"$validator\""
                        fi
                    done
                else
                    print_warning "      ⚠️  Validators não encontrados"
                fi
                
                if [ ! -z "$THRESHOLD" ]; then
                    echo "    threshold: $THRESHOLD  #"
                else
                    echo "    threshold: ?  # (não encontrado)"
                fi
                echo ""
            else
                print_warning "⚠️  Validators e threshold não encontrados para este ISM"
            fi
    else
        print_warning "⚠️  ISM não encontrado para domain $TERRA_DOMAIN via route(uint32)"
        
        # Se for TREASURY, pode ter uma estrutura diferente
        if [ "$MODULE_TYPE" = "5" ]; then
            print_info "ISM TREASURY pode ter estrutura diferente. Tentando consultar Mailbox..."
            
            # Consultar Mailbox se ainda não foi consultado
            if [ -z "$MAILBOX" ]; then
                MAILBOX_QUERY=$(cast call "$WARP_BSC_ADDRESS" "mailbox()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                
                if echo "$MAILBOX_QUERY" | grep -qiE "0x[0-9a-f]+"; then
                    MAILBOX_RAW=$(echo "$MAILBOX_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
                    if [ ! -z "$MAILBOX_RAW" ]; then
                        MAILBOX_CLEAN=$(echo "$MAILBOX_RAW" | sed 's/^0x//' | sed 's/^0*//')
                        while [ ${#MAILBOX_CLEAN} -lt 40 ]; do
                            MAILBOX_CLEAN="0$MAILBOX_CLEAN"
                        done
                        MAILBOX="0x$MAILBOX_CLEAN"
                    fi
                fi
            fi
            
            # Consultar Mailbox para obter ISM AGGREGATION
            if [ ! -z "$MAILBOX" ]; then
                MAILBOX_ISM_QUERY=$(cast call "$MAILBOX" "defaultIsm()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                
                if echo "$MAILBOX_ISM_QUERY" | grep -qiE "0x[0-9a-f]+"; then
                    MAILBOX_ISM_RAW=$(echo "$MAILBOX_ISM_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
                    if [ ! -z "$MAILBOX_ISM_RAW" ]; then
                        MAILBOX_ISM_CLEAN=$(echo "$MAILBOX_ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
                        while [ ${#MAILBOX_ISM_CLEAN} -lt 40 ]; do
                            MAILBOX_ISM_CLEAN="0$MAILBOX_ISM_CLEAN"
                        done
                        MAILBOX_ISM="0x$MAILBOX_ISM_CLEAN"
                        print_value "ISM do Mailbox: $MAILBOX_ISM"
                        
                        # Consultar tipo do ISM do Mailbox
                        MAILBOX_ISM_TYPE_QUERY=$(cast call "$MAILBOX_ISM" "moduleType()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                        if echo "$MAILBOX_ISM_TYPE_QUERY" | grep -qiE "^0x[0-9a-f]+$|^[0-9]+$"; then
                            MAILBOX_ISM_TYPE_RAW=$(echo "$MAILBOX_ISM_TYPE_QUERY" | grep -oE "^0x[0-9a-f]+$|^[0-9]+$" | head -1 || echo "")
                            if [ ! -z "$MAILBOX_ISM_TYPE_RAW" ]; then
                                if [[ "$MAILBOX_ISM_TYPE_RAW" =~ ^0x ]]; then
                                    MAILBOX_ISM_TYPE=$(cast --to-dec "$MAILBOX_ISM_TYPE_RAW" 2>/dev/null || echo "$MAILBOX_ISM_TYPE_RAW")
                                else
                                    MAILBOX_ISM_TYPE="$MAILBOX_ISM_TYPE_RAW"
                                fi
                                
                                # Se for AGGREGATION, tentar route
                                if [ "$MAILBOX_ISM_TYPE" = "2" ]; then
                                    print_value "ISM do Mailbox é AGGREGATION. Consultando route para domain $TERRA_DOMAIN..."
                                    MAILBOX_ROUTE_QUERY=$(cast call "$MAILBOX_ISM" "route(uint32)" "$TERRA_DOMAIN" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                                    
                                    if echo "$MAILBOX_ROUTE_QUERY" | grep -qiE "0x[0-9a-f]{40}"; then
                                        ROUTE_ISM_RAW=$(echo "$MAILBOX_ROUTE_QUERY" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
                                        if [ ! -z "$ROUTE_ISM_RAW" ]; then
                                            ROUTE_ISM_CLEAN=$(echo "$ROUTE_ISM_RAW" | sed 's/^0x//' | sed 's/^0*//')
                                            while [ ${#ROUTE_ISM_CLEAN} -lt 40 ]; do
                                                ROUTE_ISM_CLEAN="0$ROUTE_ISM_CLEAN"
                                            done
                                            ROUTE_ISM="0x$ROUTE_ISM_CLEAN"
                                            print_success "✅ ISM encontrado via Mailbox para domain $TERRA_DOMAIN: $ROUTE_ISM"
                                            
                                            # Consultar validators deste ISM
                                            VALIDATORS_QUERY=$(cast call "$ROUTE_ISM" "validators()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                                            THRESHOLD_QUERY=$(cast call "$ROUTE_ISM" "threshold()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                                            
                                            VALIDATORS_OUTPUT=$(echo "$VALIDATORS_QUERY" | grep -oE "0x[0-9a-f]{40}" | grep -v "0x0000000000000000000000000000000000000000" || echo "")
                                            THRESHOLD=""
                                            if echo "$THRESHOLD_QUERY" | grep -qiE "^[0-9]+$|^0x[0-9a-f]+$"; then
                                                THRESHOLD=$(echo "$THRESHOLD_QUERY" | grep -oE "^[0-9]+$|^0x[0-9a-f]+$" | head -1 || echo "")
                                                if [ ! -z "$THRESHOLD" ]; then
                                                    if [[ "$THRESHOLD" =~ ^0x ]]; then
                                                        THRESHOLD=$(cast --to-dec "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
                                                    fi
                                                fi
                                            fi
                                            
                                            # Exibir no formato YAML
                                            if [ ! -z "$VALIDATORS_OUTPUT" ] || [ ! -z "$THRESHOLD" ]; then
                                                echo ""
                                                print_success "✅ Configuração encontrada:"
                                                echo ""
                                                echo "interchainSecurityModule:"
                                                echo "    type: messageIdMultisigIsm"
                                                echo "    validators:"
                                                
                                                if [ ! -z "$VALIDATORS_OUTPUT" ]; then
                                                    echo "$VALIDATORS_OUTPUT" | while read -r validator; do
                                                        if [ ! -z "$validator" ]; then
                                                            echo "      - \"$validator\""
                                                        fi
                                                    done
                                                else
                                                    print_warning "      ⚠️  Validators não encontrados"
                                                fi
                                                
                                                if [ ! -z "$THRESHOLD" ]; then
                                                    echo "    threshold: $THRESHOLD  #"
                                                else
                                                    echo "    threshold: ?  # (não encontrado)"
                                                fi
                                                echo ""
                                                
                                                # Sair do script com sucesso
                                                print_section "RESUMO"
                                                print_info "Warp Route BSC:"
                                                print_value "  Endereço: $WARP_BSC_ADDRESS"
                                                print_value "  Explorer: https://testnet.bscscan.com/address/$WARP_BSC_ADDRESS"
                                                echo ""
                                                print_info "ISM (Interchain Security Module):"
                                                print_value "  ISM Direto: $WARP_ISM_DIRECT (TREASURY)"
                                                print_value "  ISM Mailbox: $MAILBOX_ISM (AGGREGATION)"
                                                print_value "  ISM para Domain $TERRA_DOMAIN: $ROUTE_ISM"
                                                echo ""
                                                print_success "✅ Consulta concluída!"
                                                exit 0
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
else
    # Para outros tipos de ISM, tentar consultar validators diretamente
    print_value "Consultando validators do ISM diretamente..."
    
    VALIDATORS_QUERY=$(cast call "$WARP_ISM" "validators()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
    THRESHOLD_QUERY=$(cast call "$WARP_ISM" "threshold()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
    
    VALIDATORS_OUTPUT=$(echo "$VALIDATORS_QUERY" | grep -oE "0x[0-9a-f]{40}" | grep -v "0x0000000000000000000000000000000000000000" || echo "")
    THRESHOLD=""
    if echo "$THRESHOLD_QUERY" | grep -qiE "^[0-9]+$|^0x[0-9a-f]+$"; then
        THRESHOLD=$(echo "$THRESHOLD_QUERY" | grep -oE "^[0-9]+$|^0x[0-9a-f]+$" | head -1 || echo "")
        if [ ! -z "$THRESHOLD" ]; then
            if [[ "$THRESHOLD" =~ ^0x ]]; then
                THRESHOLD=$(cast --to-dec "$THRESHOLD" 2>/dev/null || echo "$THRESHOLD")
            fi
        fi
    fi
    
    # Exibir no formato YAML
    if [ ! -z "$VALIDATORS_OUTPUT" ] || [ ! -z "$THRESHOLD" ]; then
        echo ""
        print_success "✅ Configuração encontrada:"
        echo ""
        echo "interchainSecurityModule:"
        echo "    type: messageIdMultisigIsm"
        echo "    validators:"
        
        if [ ! -z "$VALIDATORS_OUTPUT" ]; then
            echo "$VALIDATORS_OUTPUT" | while read -r validator; do
                if [ ! -z "$validator" ]; then
                    echo "      - \"$validator\""
                fi
            done
        else
            print_warning "      ⚠️  Validators não encontrados"
        fi
        
        if [ ! -z "$THRESHOLD" ]; then
            echo "    threshold: $THRESHOLD  #"
        else
            echo "    threshold: ?  # (não encontrado)"
        fi
        echo ""
    else
        print_warning "⚠️  Validators e threshold não encontrados"
    fi
fi

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_section "RESUMO"

print_info "Warp Route BSC:"
print_value "  Endereço: $WARP_BSC_ADDRESS"
print_value "  Explorer: https://testnet.bscscan.com/address/$WARP_BSC_ADDRESS"
echo ""

print_info "ISM (Interchain Security Module):"
print_value "  Endereço: $WARP_ISM"
print_value "  Tipo: $MODULE_TYPE_NAME (Type $MODULE_TYPE)"
print_value "  Explorer: https://testnet.bscscan.com/address/$WARP_ISM"
echo ""

if [ ! -z "$ROUTE_ISM" ]; then
    print_info "ISM para Domain $TERRA_DOMAIN (Terra Classic):"
    print_value "  Endereço: $ROUTE_ISM"
    print_value "  Explorer: https://testnet.bscscan.com/address/$ROUTE_ISM"
    echo ""
fi

print_success "✅ Consulta concluída!"

# Fechar o bloco if principal (linha 262: if [ "$MODULE_TYPE" = "1" ] || ...)
fi
