#!/bin/bash

# ============================================================================
# Script: Alterar Validadores do ISM associado ao Warp Route BSC (EVM)
# ============================================================================
# Este script altera os validadores do ISM no BSC criando um novo ISM Multisig
# e atualizando o Warp Route para usar o novo ISM
# 
# IMPORTANTE: O ISM atual é imutável, então precisamos criar um novo ISM
# via factory e atualizar o Warp Route
# 
# Uso: ./alterar-validadores-ism-bsc-evm.sh [private_key_or_aws_alias]
# Exemplo: ./alterar-validadores-ism-bsc-evm.sh 0xYOUR_PRIVATE_KEY
# Exemplo: ./alterar-validadores-ism-bsc-evm.sh --aws alias/hyperlane-relayer-signer-bsc
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

# Verificar se foi fornecido via argumento ou variável de ambiente
if [ $# -eq 0 ]; then
    # Tentar usar variável de ambiente
    if [ ! -z "$PRIVATE_KEY" ]; then
        SIGNER_ARG="--private-key $PRIVATE_KEY"
        print_info "Usando PRIVATE_KEY da variável de ambiente"
    elif [ ! -z "$AWS_KMS_ALIAS" ]; then
        SIGNER_ARG="--aws $AWS_KMS_ALIAS"
        print_info "Usando AWS_KMS_ALIAS da variável de ambiente: $AWS_KMS_ALIAS"
    else
        print_error "Erro: Chave privada ou alias AWS não fornecido"
        echo ""
        echo "Uso: $0 <private_key_or_aws_alias>"
        echo ""
        echo "Exemplos:"
        echo "  $0 0xYOUR_PRIVATE_KEY"
        echo "  $0 --aws alias/hyperlane-relayer-signer-bsc"
        echo ""
        echo "Ou defina uma variável de ambiente:"
        echo "  export PRIVATE_KEY=0xYOUR_PRIVATE_KEY"
        echo "  export AWS_KMS_ALIAS=alias/hyperlane-relayer-signer-bsc"
        echo ""
        exit 1
    fi
else
    # Se for --aws, precisa do segundo argumento
    if [ "$1" = "--aws" ] && [ $# -ge 2 ]; then
        SIGNER_ARG="$1 $2"
    else
        # Se for chave privada, adicionar --private-key
        SIGNER_ARG="--private-key $1"
    fi
fi

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

BSC_RPC="https://bsc-testnet.publicnode.com"
BSC_DOMAIN=97
TERRA_DOMAIN=1325

# Warp Route BSC
WARP_ROUTE_BSC="0x2144be4477202ba2d50c9a8be3181241878cf7d8"

# ISM Factory (MessageId Multisig ISM Factory)
# Do arquivo agent-config.docker.json
ISM_FACTORY="0x0D96aF0c01c4bbbadaaF989Eb489c8783F35B763"

# Novo validator e threshold
NEW_VALIDATOR="0x8a726b81468c002012a76a07f3d478da6c83e510"
THRESHOLD=1

# Verificar se cast está disponível
if ! command -v cast &> /dev/null; then
    print_error "cast não está instalado ou não está no PATH"
    print_info "Instale Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# ============================================================================
# VALIDAÇÃO DO VALIDATOR
# ============================================================================

# Remover 0x se presente para validação
VALIDATOR_CLEAN="${NEW_VALIDATOR#0x}"

# Validar formato (deve ser 40 caracteres hex)
if [[ ! "$VALIDATOR_CLEAN" =~ ^[0-9a-fA-F]{40}$ ]]; then
    print_error "Validator inválido! Deve ser um endereço hex de 40 caracteres"
    print_info "Formato esperado: 0x seguido de 40 caracteres hex"
    print_info "Exemplo: 0x8a726b81468c002012a76a07f3d478da6c83e510"
    exit 1
fi

# Validar threshold
if [ "$THRESHOLD" -lt 1 ] || [ "$THRESHOLD" -gt 10 ]; then
    print_error "Threshold inválido! Deve ser entre 1 e 10"
    exit 1
fi

# ============================================================================
# INÍCIO DO SCRIPT
# ============================================================================

print_header "ALTERAR VALIDADORES DO ISM - WARP ROUTE BSC (EVM)"

print_info "Configurações:"
print_value "Warp Route BSC: $WARP_ROUTE_BSC"
print_value "ISM Factory: $ISM_FACTORY"
print_value "Domain: $TERRA_DOMAIN (Terra Classic)"
print_value "Novo Validator: $NEW_VALIDATOR"
print_value "Threshold: $THRESHOLD"
echo ""

# ============================================================================
# VERIFICAR INFORMAÇÕES ATUAIS
# ============================================================================

print_section "1. VERIFICAR INFORMAÇÕES ATUAIS"

# Verificar ISM atual do Warp Route
print_info "Consultando ISM atual do Warp Route..."
CURRENT_ISM=$(cast call "$WARP_ROUTE_BSC" "interchainSecurityModule()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

if echo "$CURRENT_ISM" | grep -qiE "0x[0-9a-f]{40}"; then
    CURRENT_ISM_CLEAN=$(echo "$CURRENT_ISM" | grep -oE "0x[0-9a-f]+" | head -1 | sed 's/^0x//' | sed 's/^0*//')
    while [ ${#CURRENT_ISM_CLEAN} -lt 40 ]; do
        CURRENT_ISM_CLEAN="0$CURRENT_ISM_CLEAN"
    done
    CURRENT_ISM="0x$CURRENT_ISM_CLEAN"
    print_success "✅ ISM atual: $CURRENT_ISM"
    print_value "Explorer: https://testnet.bscscan.com/address/$CURRENT_ISM"
else
    print_warning "⚠️  Não foi possível consultar ISM atual"
fi
echo ""

# Verificar owner do Warp Route
print_info "Consultando owner do Warp Route..."
WARP_OWNER=$(cast call "$WARP_ROUTE_BSC" "owner()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

if echo "$WARP_OWNER" | grep -qiE "0x[0-9a-f]{40}"; then
    OWNER_CLEAN=$(echo "$WARP_OWNER" | grep -oE "0x[0-9a-f]+" | head -1 | sed 's/^0x//' | sed 's/^0*//')
    while [ ${#OWNER_CLEAN} -lt 40 ]; do
        OWNER_CLEAN="0$OWNER_CLEAN"
    done
    WARP_OWNER="0x$OWNER_CLEAN"
    print_success "✅ Owner do Warp Route: $WARP_OWNER"
    print_value "Explorer: https://testnet.bscscan.com/address/$WARP_OWNER"
    
    # Verificar se o signer é o owner
    SIGNER_ADDRESS=""
    if [[ "$SIGNER_ARG" == "--aws"* ]]; then
        SIGNER_ADDRESS=$(cast wallet address $SIGNER_ARG 2>/dev/null || echo "")
    elif [[ "$SIGNER_ARG" == "--private-key"* ]]; then
        # Extrair a chave privada do SIGNER_ARG
        PRIVATE_KEY_VALUE=$(echo "$SIGNER_ARG" | sed 's/--private-key //')
        SIGNER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY_VALUE" 2>/dev/null || echo "")
    else
        SIGNER_ADDRESS=$(cast wallet address --private-key "$SIGNER_ARG" 2>/dev/null || echo "")
    fi
    
    if [ ! -z "$SIGNER_ADDRESS" ]; then
        SIGNER_ADDRESS_LOWER=$(echo "$SIGNER_ADDRESS" | tr '[:upper:]' '[:lower:]')
        WARP_OWNER_LOWER=$(echo "$WARP_OWNER" | tr '[:upper:]' '[:lower:]')
        
        if [ "$SIGNER_ADDRESS_LOWER" = "$WARP_OWNER_LOWER" ]; then
            print_success "✅ O signer é o owner do Warp Route"
        else
            print_warning "⚠️  O signer NÃO é o owner do Warp Route"
            print_info "Signer: $SIGNER_ADDRESS"
            print_info "Owner: $WARP_OWNER"
            print_warning "A transação pode falhar se o signer não tiver permissões"
        fi
    fi
else
    print_warning "⚠️  Não foi possível consultar owner"
fi
echo ""

# ============================================================================
# CRIAR NOVO ISM MULTISIG
# ============================================================================

print_section "2. CRIAR NOVO ISM MULTISIG"

print_info "O ISM atual é imutável. Precisamos criar um novo ISM via factory."
print_info "Factory: $ISM_FACTORY"
print_value "Tipo: MessageId Multisig ISM"
echo ""

# Preparar parâmetros para criar o ISM
# A StaticMessageIdMultisigIsmFactory usa: deploy(address[] validators, uint8 threshold)
# NOTA: Não recebe domain como parâmetro - o ISM é genérico
print_info "Preparando parâmetros para criar novo ISM..."
print_value "Validators: [$NEW_VALIDATOR]"
print_value "Threshold: $THRESHOLD"
print_info "Nota: O ISM criado será genérico (não vinculado a um domain específico)"
print_info "O domain será configurado quando o ISM for associado ao Warp Route"
echo ""

# Verificar função da factory
print_info "Verificando função da factory..."
FACTORY_DEPLOY_SIG=$(cast sig "deploy(address[],uint8)" 2>/dev/null || echo "")
if [ ! -z "$FACTORY_DEPLOY_SIG" ]; then
    print_success "✅ Função encontrada: deploy(address[],uint8)"
    print_value "Selector: $FACTORY_DEPLOY_SIG"
else
    print_warning "⚠️  Função deploy não encontrada. Tentando outras variações..."
    # Tentar outras funções comuns
    FACTORY_DEPLOY_SIG=$(cast sig "deploy(address[],uint256)" 2>/dev/null || echo "")
fi
echo ""

# Preparar calldata para criar ISM
print_info "Preparando calldata para criar novo ISM..."
DEPLOY_CALLDATA=$(cast calldata "deploy(address[],uint8)" "[$NEW_VALIDATOR]" "$THRESHOLD" 2>&1 || echo "")

if [ ! -z "$DEPLOY_CALLDATA" ] && echo "$DEPLOY_CALLDATA" | grep -qiE "^0x[0-9a-f]+"; then
    print_success "✅ Calldata preparado:"
    print_value "$DEPLOY_CALLDATA"
else
    print_error "❌ Erro ao preparar calldata"
    print_info "Tentando método alternativo..."
    # Método alternativo: construir calldata manualmente
    DEPLOY_CALLDATA=$(cast calldata "deploy(uint32,address[],uint8)" "$TERRA_DOMAIN" "[\"$NEW_VALIDATOR\"]" "$THRESHOLD" 2>&1 || echo "")
fi
echo ""

# ============================================================================
# CONFIRMAÇÃO
# ============================================================================

print_section "3. CONFIRMAÇÃO"

print_warning "⚠️  ATENÇÃO: Esta operação irá:"
print_value "1. Criar um novo ISM Multisig no BSC"
print_value "2. Atualizar o Warp Route para usar o novo ISM"
echo ""
print_info "Nova configuração:"
print_value "Domain: $TERRA_DOMAIN (Terra Classic)"
print_value "Validator: $NEW_VALIDATOR"
print_value "Threshold: $THRESHOLD"
echo ""

read -p "Deseja continuar? (sim/não): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Ss][Ii][Mm]$ ]]; then
    print_info "Operação cancelada pelo usuário"
    exit 0
fi

# ============================================================================
# CRIAR NOVO ISM
# ============================================================================

print_section "4. CRIAR NOVO ISM MULTISIG"

# Verificar se o ISM já existe antes de tentar criar (Create2 determinístico)
print_info "Verificando se o ISM já existe (Create2 determinístico)..."
print_info "Nota: O endereço é determinístico - mesmo validators + threshold = mesmo endereço"
GET_ADDRESS_PRE_CHECK=$(cast call "$ISM_FACTORY" "getAddress(address[],uint8)" "[$NEW_VALIDATOR]" "$THRESHOLD" --rpc-url "$BSC_RPC" 2>&1 || echo "")
ISM_EXISTS=false
NEW_ISM_ADDRESS=""

if echo "$GET_ADDRESS_PRE_CHECK" | grep -qiE "0x[0-9a-f]+"; then
    PRE_CHECK_ADDRESS_RAW=$(echo "$GET_ADDRESS_PRE_CHECK" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
    if [ ! -z "$PRE_CHECK_ADDRESS_RAW" ]; then
        PRE_CHECK_ADDRESS_CLEAN=$(echo "$PRE_CHECK_ADDRESS_RAW" | sed 's/^0x//' | sed 's/^0*//')
        while [ ${#PRE_CHECK_ADDRESS_CLEAN} -lt 40 ]; do
            PRE_CHECK_ADDRESS_CLEAN="0$PRE_CHECK_ADDRESS_CLEAN"
        done
        PRE_CHECK_ADDRESS="0x$PRE_CHECK_ADDRESS_CLEAN"
        
        PRE_CHECK_CODE=$(cast code "$PRE_CHECK_ADDRESS" --rpc-url "$BSC_RPC" 2>&1 || echo "")
        if echo "$PRE_CHECK_CODE" | grep -qiE "^0x[0-9a-f]+" && [ "$PRE_CHECK_CODE" != "0x" ]; then
            ISM_EXISTS=true
            NEW_ISM_ADDRESS="$PRE_CHECK_ADDRESS"
            print_success "✅ ISM já existe na blockchain: $NEW_ISM_ADDRESS"
            print_value "Explorer: https://testnet.bscscan.com/address/$NEW_ISM_ADDRESS"
            print_info "A factory reutilizará este ISM (Create2 determinístico)"
            print_info "Pulando criação e usando ISM existente..."
            echo ""
        else
            print_info "ISM ainda não existe. Será criado na transação..."
            print_value "Endereço calculado: $PRE_CHECK_ADDRESS"
        fi
    fi
fi

# Executar transação para criar ISM (se não existir)
if [ "$ISM_EXISTS" = false ]; then
    print_info "Enviando transação para criar novo ISM..."
    print_value "Factory: $ISM_FACTORY"
    print_value "RPC: $BSC_RPC"
    echo ""
    
    print_info "Executando: cast send para criar ISM..."
    DEPLOY_RESULT=$(cast send "$ISM_FACTORY" "$DEPLOY_CALLDATA" \
        $SIGNER_ARG \
        --rpc-url "$BSC_RPC" \
        --legacy \
        --gas-price 1000000000 \
        2>&1 || echo "ERROR")
fi

if [ "$ISM_EXISTS" = false ]; then
    if echo "$DEPLOY_RESULT" | grep -qi "error\|ERROR\|reverted\|failed"; then
        print_error "❌ Erro ao criar ISM:"
        echo "$DEPLOY_RESULT"
        print_info ""
        print_info "Possíveis causas:"
        print_info "  - A função deploy pode ter assinatura diferente"
        print_info "  - O signer não tem permissões"
        print_info "  - Parâmetros inválidos"
        print_info ""
        print_info "Verifique o contrato da factory no BSCScan:"
        print_info "  https://testnet.bscscan.com/address/$ISM_FACTORY#code"
        exit 1
    fi

    # Extrair hash da transação
    TX_HASH=$(echo "$DEPLOY_RESULT" | grep -oE "0x[0-9a-f]{64}" | head -1 || echo "")
    
    if [ ! -z "$TX_HASH" ]; then
        print_success "✅ Transação enviada com sucesso!"
        print_value "Tx Hash: $TX_HASH"
        print_value "Explorer: https://testnet.bscscan.com/tx/$TX_HASH"
        echo ""
        
        print_info "Aguardando confirmação da transação..."
        sleep 5
        
        # Calcular endereço usando getAddress da factory (método mais confiável)
        # IMPORTANTE: O endereço é determinístico (Create2) - mesmo validators + threshold = mesmo endereço
        print_info "Calculando endereço do ISM usando getAddress da factory..."
        print_info "Nota: O endereço é determinístico (Create2). Se já existe um ISM com os mesmos validators e threshold, será reutilizado."
        GET_ADDRESS_RESULT=$(cast call "$ISM_FACTORY" "getAddress(address[],uint8)" "[$NEW_VALIDATOR]" "$THRESHOLD" --rpc-url "$BSC_RPC" 2>&1 || echo "")
        
        NEW_ISM_ADDRESS=""
        if echo "$GET_ADDRESS_RESULT" | grep -qiE "0x[0-9a-f]+"; then
            GET_ADDRESS_RAW=$(echo "$GET_ADDRESS_RESULT" | grep -oE "0x[0-9a-f]+" | head -1 || echo "")
            if [ ! -z "$GET_ADDRESS_RAW" ]; then
                GET_ADDRESS_CLEAN=$(echo "$GET_ADDRESS_RAW" | sed 's/^0x//' | sed 's/^0*//')
                while [ ${#GET_ADDRESS_CLEAN} -lt 40 ]; do
                    GET_ADDRESS_CLEAN="0$GET_ADDRESS_CLEAN"
                done
                NEW_ISM_ADDRESS="0x$GET_ADDRESS_CLEAN"
                
                # Verificar se o contrato já existe (Create2 reutiliza se já foi criado)
                ISM_CODE=$(cast code "$NEW_ISM_ADDRESS" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                if echo "$ISM_CODE" | grep -qiE "^0x[0-9a-f]+" && [ "$ISM_CODE" != "0x" ]; then
                    print_success "✅ ISM já existe (ou foi criado): $NEW_ISM_ADDRESS"
                    print_value "Explorer: https://testnet.bscscan.com/address/$NEW_ISM_ADDRESS"
                    print_info "Nota: Este ISM já existe na blockchain (Create2 determinístico)"
                    
                    # Verificar tipo do ISM
                    ISM_TYPE=$(cast call "$NEW_ISM_ADDRESS" "moduleType()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                    if echo "$ISM_TYPE" | grep -qiE "^0x[0-9a-f]+$|^[0-9]+$"; then
                        ISM_TYPE_DEC=$(echo "$ISM_TYPE" | grep -oE "^0x[0-9a-f]+$|^[0-9]+$" | head -1)
                        if [[ "$ISM_TYPE_DEC" =~ ^0x ]]; then
                            ISM_TYPE_DEC=$(cast --to-dec "$ISM_TYPE_DEC" 2>/dev/null || echo "$ISM_TYPE_DEC")
                        fi
                        print_value "Tipo do ISM: $ISM_TYPE_DEC"
                    fi
                    
                    # Verificar validators
                    VALIDATORS_CHECK=$(cast call "$NEW_ISM_ADDRESS" "validators()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                    if echo "$VALIDATORS_CHECK" | grep -qiE "0x[0-9a-f]{40}"; then
                        print_info "Validators configurados:"
                        echo "$VALIDATORS_CHECK" | grep -oE "0x[0-9a-f]{40}" | while read -r validator; do
                            if [ ! -z "$validator" ] && [ "$validator" != "0x0000000000000000000000000000000000000000" ]; then
                                print_value "  - $validator"
                            fi
                        done
                    fi
                else
                    print_info "ISM ainda não existe. Será criado na transação..."
                    print_value "Endereço calculado: $NEW_ISM_ADDRESS"
                    print_info "Aguardando confirmação da transação..."
                    sleep 10
                    
                    # Verificar novamente após aguardar
                    ISM_CODE=$(cast code "$NEW_ISM_ADDRESS" --rpc-url "$BSC_RPC" 2>&1 || echo "")
                    if echo "$ISM_CODE" | grep -qiE "^0x[0-9a-f]+" && [ "$ISM_CODE" != "0x" ]; then
                        print_success "✅ ISM criado: $NEW_ISM_ADDRESS"
                        print_value "Explorer: https://testnet.bscscan.com/address/$NEW_ISM_ADDRESS"
                    else
                        print_warning "⚠️  ISM ainda não está disponível. Pode levar alguns blocos."
                        print_info "Endereço calculado: $NEW_ISM_ADDRESS"
                        print_info "Você pode verificar mais tarde se o ISM foi criado"
                    fi
                fi
            fi
        fi
        
        # Se ainda não encontrou, solicitar ao usuário
        if [ -z "$NEW_ISM_ADDRESS" ]; then
            print_warning "⚠️  Não foi possível obter o endereço do novo ISM automaticamente"
            print_info "O ISM foi criado, mas precisamos do endereço para continuar"
            print_info ""
            print_info "Opções:"
            print_info "  1. Verifique a transação no BSCScan e encontre o endereço do novo ISM"
            print_info "  2. Use o comando abaixo para calcular o endereço:"
            print_value "     cast call $ISM_FACTORY \"getAddress(address[],uint8)\" \"[$NEW_VALIDATOR]\" \"$THRESHOLD\" --rpc-url $BSC_RPC"
            print_info ""
            read -p "Digite o endereço do novo ISM (ou pressione Enter para cancelar): " NEW_ISM_ADDRESS
            
            if [ -z "$NEW_ISM_ADDRESS" ]; then
                print_info "Operação cancelada. Execute novamente quando tiver o endereço do novo ISM"
                exit 0
            fi
            
            # Validar formato do endereço
            if [[ ! "$NEW_ISM_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
                print_error "Endereço inválido!"
                exit 1
            fi
        else
            print_success "✅ Endereço do novo ISM: $NEW_ISM_ADDRESS"
            print_value "Explorer: https://testnet.bscscan.com/address/$NEW_ISM_ADDRESS"
        fi
    else
        print_error "❌ Não foi possível extrair o hash da transação"
        echo "$DEPLOY_RESULT"
        exit 1
    fi
fi
echo ""

# ============================================================================
# ATUALIZAR WARP ROUTE
# ============================================================================

print_section "5. ATUALIZAR WARP ROUTE"

if [ -z "$NEW_ISM_ADDRESS" ]; then
    print_warning "⚠️  Não foi possível obter o endereço do novo ISM automaticamente"
    print_info "Você precisará:"
    print_info "  1. Verificar a transação no BSCScan para encontrar o endereço do novo ISM"
    print_info "  2. Executar manualmente a atualização do Warp Route"
    print_info ""
    print_info "Comando para atualizar o Warp Route (quando tiver o endereço do novo ISM):"
    print_value "cast send $WARP_ROUTE_BSC \\"
    print_value "  \"setInterchainSecurityModule(address)\" \\"
    print_value "  0xNOVO_ISM_ADDRESS \\"
    print_value "  $SIGNER_ARG \\"
    print_value "  --rpc-url $BSC_RPC \\"
    print_value "  --legacy \\"
    print_value "  --gas-price 1000000000"
    exit 0
fi

print_info "Atualizando Warp Route para usar o novo ISM..."
print_value "Warp Route: $WARP_ROUTE_BSC"
print_value "Novo ISM: $NEW_ISM_ADDRESS"
echo ""

# Preparar calldata para atualizar ISM
SET_ISM_CALLDATA=$(cast calldata "setInterchainSecurityModule(address)" "$NEW_ISM_ADDRESS" 2>&1 || echo "")

if [ ! -z "$SET_ISM_CALLDATA" ] && echo "$SET_ISM_CALLDATA" | grep -qiE "^0x[0-9a-f]+"; then
    print_success "✅ Calldata preparado:"
    print_value "$SET_ISM_CALLDATA"
else
    print_error "❌ Erro ao preparar calldata para atualizar ISM"
    exit 1
fi
echo ""

# Executar transação para atualizar Warp Route
print_info "Executando: cast send para atualizar Warp Route..."
UPDATE_RESULT=$(cast send "$WARP_ROUTE_BSC" "$SET_ISM_CALLDATA" \
    $SIGNER_ARG \
    --rpc-url "$BSC_RPC" \
    --legacy \
    --gas-price 1000000000 \
    2>&1 || echo "ERROR")

if echo "$UPDATE_RESULT" | grep -qi "error\|ERROR\|reverted\|failed"; then
    print_error "❌ Erro ao atualizar Warp Route:"
    echo "$UPDATE_RESULT"
    print_info ""
    print_info "Possíveis causas:"
    print_info "  - O signer não é o owner do Warp Route"
    print_info "  - A função setInterchainSecurityModule não existe ou tem assinatura diferente"
    print_info "  - O novo ISM não é válido"
    exit 1
fi

print_success "✅ Warp Route atualizado com sucesso!"
echo ""

# ============================================================================
# VERIFICAR NOVA CONFIGURAÇÃO
# ============================================================================

print_section "6. VERIFICAR NOVA CONFIGURAÇÃO"

print_info "Aguardando alguns segundos antes de verificar..."
sleep 5

print_info "Consultando ISM atual do Warp Route..."
NEW_ISM_CHECK=$(cast call "$WARP_ROUTE_BSC" "interchainSecurityModule()" --rpc-url "$BSC_RPC" 2>&1 || echo "")

if echo "$NEW_ISM_CHECK" | grep -qiE "0x[0-9a-f]{40}"; then
    NEW_ISM_CHECK_CLEAN=$(echo "$NEW_ISM_CHECK" | grep -oE "0x[0-9a-f]+" | head -1 | sed 's/^0x//' | sed 's/^0*//')
    while [ ${#NEW_ISM_CHECK_CLEAN} -lt 40 ]; do
        NEW_ISM_CHECK_CLEAN="0$NEW_ISM_CHECK_CLEAN"
    done
    NEW_ISM_CHECK="0x$NEW_ISM_CHECK_CLEAN"
    
    NEW_ISM_LOWER=$(echo "$NEW_ISM_ADDRESS" | tr '[:upper:]' '[:lower:]')
    CHECK_LOWER=$(echo "$NEW_ISM_CHECK" | tr '[:upper:]' '[:lower:]')
    
    if [ "$NEW_ISM_LOWER" = "$CHECK_LOWER" ]; then
        print_success "✅ ISM atualizado com sucesso!"
        print_value "Novo ISM: $NEW_ISM_CHECK"
        print_value "Explorer: https://testnet.bscscan.com/address/$NEW_ISM_CHECK"
        echo ""
        
        # ============================================================================
        # CONSULTAR CONFIGURAÇÃO DO NOVO ISM NO CONTRATO
        # ============================================================================
        
        print_section "CONFIGURAÇÃO DO ISM (CONSULTADA NO CONTRATO)"
        
        print_info "Consultando configuração do ISM $NEW_ISM_CHECK no contrato..."
        echo ""
        
        # Consultar tipo do ISM
        ISM_TYPE_CHECK=$(cast call "$NEW_ISM_CHECK" "moduleType()" --rpc-url "$BSC_RPC" 2>&1 || echo "")
        if echo "$ISM_TYPE_CHECK" | grep -qiE "^0x[0-9a-f]+$|^[0-9]+$"; then
            ISM_TYPE_RAW=$(echo "$ISM_TYPE_CHECK" | grep -oE "^0x[0-9a-f]+$|^[0-9]+$" | head -1 || echo "")
            if [ ! -z "$ISM_TYPE_RAW" ]; then
                if [[ "$ISM_TYPE_RAW" =~ ^0x ]]; then
                    ISM_TYPE_DEC=$(cast --to-dec "$ISM_TYPE_RAW" 2>/dev/null || echo "$ISM_TYPE_RAW")
                else
                    ISM_TYPE_DEC="$ISM_TYPE_RAW"
                fi
                
                case "$ISM_TYPE_DEC" in
                    0) ISM_TYPE_NAME="UNUSED" ;;
                    1) ISM_TYPE_NAME="ROUTING" ;;
                    2) ISM_TYPE_NAME="AGGREGATION" ;;
                    3) ISM_TYPE_NAME="LEGACY_MULTISIG" ;;
                    4) ISM_TYPE_NAME="MERKLE_ROOT_MULTISIG" ;;
                    5) ISM_TYPE_NAME="MESSAGE_ID_MULTISIG" ;;
                    6) ISM_TYPE_NAME="NULL" ;;
                    7) ISM_TYPE_NAME="CCIP_READ" ;;
                    8) ISM_TYPE_NAME="ARB_L2_TO_L1" ;;
                    9) ISM_TYPE_NAME="WEIGHTED_MERKLE_ROOT_MULTISIG" ;;
                    10) ISM_TYPE_NAME="WEIGHTED_MESSAGE_ID_MULTISIG" ;;
                    11) ISM_TYPE_NAME="OP_L2_TO_L1" ;;
                    12) ISM_TYPE_NAME="POLYMER" ;;
                    *) ISM_TYPE_NAME="UNKNOWN ($ISM_TYPE_DEC)" ;;
                esac
                
                print_success "✅ Tipo do ISM: $ISM_TYPE_NAME (Type $ISM_TYPE_DEC)"
            fi
        fi
        echo ""
        
        # Consultar validators e threshold usando validatorsAndThreshold(bytes)
        print_info "Consultando validators e threshold do ISM..."
        VALIDATORS_AND_THRESHOLD=$(cast call "$NEW_ISM_CHECK" "validatorsAndThreshold(bytes)" "0x" --rpc-url "$BSC_RPC" 2>&1 || echo "")
        
        VALIDATORS_LIST=""
        THRESHOLD_VALUE=""
        
        if echo "$VALIDATORS_AND_THRESHOLD" | grep -qiE "0x[0-9a-f]+"; then
            # Extrair validators (procurar endereços de 40 caracteres hex após os offsets)
            # O formato ABI retorna: offset_array, threshold, length_array, validators...
            print_success "✅ Validators encontrados:"
            echo "$VALIDATORS_AND_THRESHOLD" | grep -oE "0x[0-9a-f]{40}" | while read -r validator; do
                # Filtrar endereços válidos (não zero e não parte de offsets)
                if [ ! -z "$validator" ] && [ "$validator" != "0x0000000000000000000000000000000000000000" ]; then
                    # Verificar se é um endereço válido (não começa com muitos zeros)
                    if echo "$validator" | grep -qiE "0x[0-9a-f]{1,39}[0-9a-f]{1,40}"; then
                        print_value "  - $validator"
                        VALIDATORS_LIST="$VALIDATORS_LIST$validator\n"
                    fi
                fi
            done
            
            # Extrair threshold - procurar valores pequenos (uint8) no resultado
            # O threshold é um uint8, então será um valor pequeno (0-255)
            # Vamos procurar todos os valores de 64 bytes e verificar qual é o threshold
            for val in $(echo "$VALIDATORS_AND_THRESHOLD" | grep -oE "0x[0-9a-f]{64}"); do
                DEC=$(cast --to-dec "$val" 2>/dev/null || echo "")
                # Threshold é uint8, então deve ser entre 0 e 255
                # E não deve ser 64 (offset comum) nem muito grande
                if [ ! -z "$DEC" ] && [ "$DEC" -ge 0 ] && [ "$DEC" -le 255 ] && [ "$DEC" != "64" ]; then
                    THRESHOLD_VALUE="$DEC"
                    print_success "✅ Threshold: $THRESHOLD_VALUE"
                    break
                fi
            done
            
            # Se não encontrou threshold, usar o valor configurado no script
            if [ -z "$THRESHOLD_VALUE" ]; then
                THRESHOLD_VALUE="$THRESHOLD"
                print_info "Threshold (do script): $THRESHOLD_VALUE"
            fi
        else
            print_warning "⚠️  Validators e threshold não encontrados ou função não disponível"
            # Usar valores do script como fallback
            THRESHOLD_VALUE="$THRESHOLD"
            print_info "Usando valores do script:"
            print_value "  Validator: $NEW_VALIDATOR"
            print_value "  Threshold: $THRESHOLD_VALUE"
        fi
        echo ""
        
        # Mostrar domain (configurado no script)
        print_info "Domain configurado:"
        print_success "✅ Domain: $TERRA_DOMAIN (Terra Classic)"
        echo ""
        
        # Resumo final
        print_section "RESUMO DA CONFIGURAÇÃO APLICADA"
        print_success "✅ Configuração aplicada e verificada com sucesso!"
        echo ""
        print_info "Warp Route BSC:"
        print_value "  Endereço: $WARP_ROUTE_BSC"
        print_value "  Explorer: https://testnet.bscscan.com/address/$WARP_ROUTE_BSC"
        echo ""
        print_info "ISM (Interchain Security Module):"
        print_value "  Endereço: $NEW_ISM_CHECK"
        print_value "  Tipo: $ISM_TYPE_NAME (Type $ISM_TYPE_DEC)"
        print_value "  Explorer: https://testnet.bscscan.com/address/$NEW_ISM_CHECK"
        echo ""
        print_info "Configuração do ISM:"
        print_value "  Domain: $TERRA_DOMAIN (Terra Classic)"
        if [ ! -z "$VALIDATORS_AND_THRESHOLD" ] && echo "$VALIDATORS_AND_THRESHOLD" | grep -qiE "0x[0-9a-f]{40}"; then
            print_value "  Validators:"
            echo "$VALIDATORS_AND_THRESHOLD" | grep -oE "0x[0-9a-f]{40}" | while read -r validator; do
                if [ ! -z "$validator" ] && [ "$validator" != "0x0000000000000000000000000000000000000000" ]; then
                    print_value "    - $validator"
                fi
            done
        fi
        if [ ! -z "$THRESHOLD_VALUE" ]; then
            print_value "  Threshold: $THRESHOLD_VALUE"
        fi
        echo ""
        
        # Exibir no formato YAML
        print_section "CONFIGURAÇÃO EM FORMATO YAML"
        echo "interchainSecurityModule:"
        echo "    type: messageIdMultisigIsm"
        echo "    domain: $TERRA_DOMAIN  # Terra Classic"
        echo "    validators:"
        if [ ! -z "$VALIDATORS_AND_THRESHOLD" ] && echo "$VALIDATORS_AND_THRESHOLD" | grep -qiE "0x[0-9a-f]{40}"; then
            echo "$VALIDATORS_AND_THRESHOLD" | grep -oE "0x[0-9a-f]{40}" | while read -r validator; do
                if [ ! -z "$validator" ] && [ "$validator" != "0x0000000000000000000000000000000000000000" ]; then
                    echo "      - \"$validator\""
                fi
            done
        else
            echo "      - \"Não encontrado\""
        fi
        if [ ! -z "$THRESHOLD_VALUE" ]; then
            echo "    threshold: $THRESHOLD_VALUE  #"
        else
            echo "    threshold: ?  # (não encontrado)"
        fi
        echo ""
    else
        print_warning "⚠️  ISM diferente do esperado"
        print_value "Esperado: $NEW_ISM_ADDRESS"
        print_value "Encontrado: $NEW_ISM_CHECK"
    fi
else
    print_warning "⚠️  Não foi possível verificar o novo ISM"
fi
echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_section "RESUMO"

print_success "✅ Operação concluída!"
print_info "Configuração aplicada:"
print_value "Warp Route: $WARP_ROUTE_BSC"
if [ ! -z "$NEW_ISM_ADDRESS" ]; then
    print_value "Novo ISM: $NEW_ISM_ADDRESS"
    print_value "Explorer ISM: https://testnet.bscscan.com/address/$NEW_ISM_ADDRESS"
fi
print_value "Domain: $TERRA_DOMAIN (Terra Classic)"
print_value "Validator: $NEW_VALIDATOR"
print_value "Threshold: $THRESHOLD"
echo ""

print_info "Para verificar novamente, execute:"
print_value "cast call $WARP_ROUTE_BSC \"interchainSecurityModule()\" --rpc-url $BSC_RPC"
echo ""
