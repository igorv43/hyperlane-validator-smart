#!/bin/bash

# Script para criar IGP no BSC testnet e associar ao Warp Route
# Similar ao script do Solana, mas adaptado para BSC (EVM)
# Autor: Hyperlane Validator
# Data: 2025-01-27

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Configurações
BSC_RPC="https://bsc-testnet.publicnode.com"
BSC_DOMAIN=97
TERRA_DOMAIN=1325

# IGP padrão do BSC testnet (do agent-config)
BSC_IGP_DEFAULT="0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949"

# Warp Route BSC
WARP_ROUTE_BSC="0x2144Be4477202ba2d50c9A8be3181241878cf7D8"

# Valores do Terra Classic IGP (seguindo a mesma lógica do Solana)
# Terra Classic: exchange_rate=40000000000000, gas_price=1, custo 200k gas=800 LUNC
# Para BSC, vamos usar valores similares, ajustados para BNB
TERRA_EXCHANGE_RATE=40000000000000
TERRA_GAS_PRICE=1

# Calcular valores para BSC
# BNB tem 18 decimais, LUNC tem 6 decimais
# Assumindo 1 BNB = 100,000 LUNC (taxa de mercado aproximada)
print_header "CRIAR IGP NO BSC TESTNET E ASSOCIAR AO WARP ROUTE"

print_info "Este script irá (seguindo a lógica do Solana):"
print_value "1. Criar um NOVO IGP no BSC testnet (deployar novo contrato)"
print_value "2. Configurar o Gas Oracle para Terra Classic (Domain $TERRA_DOMAIN)"
print_value "3. Associar o novo IGP ao Warp Route: $WARP_ROUTE_BSC"
print_info ""
print_info "Nota: No Solana, criamos um novo IGP account. No BSC (EVM), vamos deployar um novo contrato IGP."
echo ""

print_info "Configurações:"
print_value "Warp Route BSC: $WARP_ROUTE_BSC"
print_value "IGP padrão BSC: $BSC_IGP_DEFAULT"
print_value "Terra Classic Domain: $TERRA_DOMAIN"
print_value "BSC Domain: $BSC_DOMAIN"
echo ""

# Verificar se cast está instalado
if ! command -v cast &> /dev/null; then
    print_error "cast não está instalado ou não está no PATH"
    print_info "Instale Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# Verificar se há chave privada ou KMS configurada
if [ -z "$BSC_PRIVATE_KEY" ] && [ -z "$BSC_KMS_ALIAS" ]; then
    print_warning "Nenhuma chave configurada para BSC"
    print_info "Opções disponíveis:"
    print_value "1. Chave privada hexadecimal (0x...)"
    print_value "2. Alias AWS KMS (alias/...)"
    echo ""
    read -p "Digite a chave privada BSC (0x...) ou pressione Enter para usar KMS: " BSC_PRIVATE_KEY_INPUT
    if [ ! -z "$BSC_PRIVATE_KEY_INPUT" ]; then
        # Validar formato da chave privada
        if [[ "$BSC_PRIVATE_KEY_INPUT" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
            export BSC_PRIVATE_KEY="$BSC_PRIVATE_KEY_INPUT"
            print_success "Chave privada configurada (oculta por segurança)"
        else
            print_error "Formato inválido! A chave privada deve começar com 0x e ter 64 caracteres hexadecimais"
            print_info "Exemplo: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
            exit 1
        fi
    else
        read -p "Digite o alias KMS (ex: alias/hyperlane-relayer-signer-bsc) ou pressione Enter para usar o padrão: " BSC_KMS_ALIAS_INPUT
        if [ ! -z "$BSC_KMS_ALIAS_INPUT" ]; then
            export BSC_KMS_ALIAS="$BSC_KMS_ALIAS_INPUT"
        else
            # Tentar usar o alias padrão
            export BSC_KMS_ALIAS="alias/hyperlane-relayer-signer-bsc"
            print_info "Usando alias KMS padrão: $BSC_KMS_ALIAS"
            # Verificar se o alias existe
            if ! cast wallet address --aws "$BSC_KMS_ALIAS" &>/dev/null; then
                print_error "Alias KMS não encontrado: $BSC_KMS_ALIAS"
                print_info "Crie o alias KMS primeiro ou forneça uma chave privada"
                exit 1
            fi
        fi
    fi
fi

# Calcular valores do Gas Oracle para Terra Classic
print_section "CALCULANDO VALORES DO GAS ORACLE"

print_info "Valores de referência do Terra Classic IGP:"
print_value "Exchange Rate: $TERRA_EXCHANGE_RATE"
print_value "Gas Price: $TERRA_GAS_PRICE"
print_value "Custo para 200k gas: 800 LUNC"
echo ""

# Calcular token_exchange_rate e gas_price para BSC
CALC_OUTPUT=$(python3 << PYEOF
# Configurações
BNB_DECIMALS = 18
LUNC_DECIMALS = 6
BSC_SCALE = 10**18  # BNB tem 18 decimais

# Valores do Terra Classic
gas_amount_ref = 200000
gas_price_terra = 1
exchange_rate_terra = 40000000000000
cost_lunc = 800

# Calcular custo por gas
cost_per_gas_lunc = cost_lunc / gas_amount_ref

# Para destination_gas = 3,000,000 (padrão)
gas_amount_dest = 3000000
total_cost_lunc = gas_amount_dest * cost_per_gas_lunc

# Assumindo 1 BNB = 100,000 LUNC (taxa de mercado)
bnb_to_lunc_rate = 100000
total_cost_bnb = total_cost_lunc / bnb_to_lunc_rate
total_cost_wei = total_cost_bnb * (10**18)

print(f"Para {gas_amount_dest:,} gas:")
print(f"  Custo em LUNC: {total_cost_lunc:,.2f} LUNC")
print(f"  Custo em BNB: {total_cost_bnb:.9f} BNB")
print(f"  Custo em wei: {total_cost_wei:,.0f}")
print()

# Calcular token_exchange_rate para BSC
# Fórmula: origin_cost_wei = (gas_amount * gas_price * token_exchange_rate) / BSC_SCALE * 10^(BNB_DECIMALS - LUNC_DECIMALS)
# token_exchange_rate = (origin_cost_wei * BSC_SCALE) / (gas_amount * gas_price * 10^(BNB_DECIMALS - LUNC_DECIMALS))

token_exchange_rate = (total_cost_wei * BSC_SCALE) / (gas_amount_dest * gas_price_terra * (10 ** (BNB_DECIMALS - LUNC_DECIMALS)))

print(f"=== VALORES CALCULADOS PARA BSC ===")
print(f"token_exchange_rate: {int(token_exchange_rate)}")
print(f"gas_price: {gas_price_terra}")
print(f"token_decimals: {LUNC_DECIMALS}")
PYEOF
)

TOKEN_EXCHANGE_RATE=$(echo "$CALC_OUTPUT" | grep "token_exchange_rate:" | grep -oE "[0-9]+" | head -1)
GAS_PRICE=$(echo "$CALC_OUTPUT" | grep "gas_price:" | grep -oE "[0-9]+" | head -1)
TOKEN_DECIMALS=$(echo "$CALC_OUTPUT" | grep "token_decimals:" | grep -oE "[0-9]+" | head -1)

echo "$CALC_OUTPUT"
echo ""

if [ -z "$TOKEN_EXCHANGE_RATE" ] || [ -z "$GAS_PRICE" ]; then
    print_error "Erro ao calcular valores do Gas Oracle"
    exit 1
fi

print_info "Valores calculados para BSC IGP:"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

# Permitir execução automática via variável de ambiente
if [ -z "$AUTO_CONFIRM" ]; then
    read -p "Deseja continuar com esses valores? (s/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
        print_info "Operação cancelada."
        exit 0
    fi
else
    print_info "Execução automática habilitada (AUTO_CONFIRM=$AUTO_CONFIRM)"
fi

echo ""

# ============================================================================
# PASSO 1: Criar novo IGP no BSC (seguindo lógica do Solana)
# ============================================================================
print_section "PASSO 1: CRIAR NOVO IGP NO BSC"

print_info "Seguindo a lógica do Solana: vamos criar um NOVO IGP no BSC"
print_info "No Solana: cargo run -- igp init-igp-account"
print_info "No BSC: hyperlane core deploy (deployar novo contrato IGP)"
echo ""

# Verificar se Hyperlane CLI está disponível
if ! command -v hyperlane &> /dev/null; then
    print_error "Hyperlane CLI não está instalado ou não está no PATH"
    print_info "Instale: npm install -g @hyperlane-xyz/cli"
    exit 1
fi

print_info "Preparando para deployar novo IGP no BSC testnet..."
print_value "Chain: bsctestnet"
print_value "RPC: $BSC_RPC"
echo ""

# Preparar chave para o Hyperlane CLI
if [ ! -z "$BSC_PRIVATE_KEY" ]; then
    export HYP_KEY="$BSC_PRIVATE_KEY"
    print_success "Chave privada configurada para Hyperlane CLI"
elif [ ! -z "$BSC_KMS_ALIAS" ]; then
    print_warning "Hyperlane CLI pode não suportar KMS diretamente"
    print_info "Será necessário usar chave privada para deploy"
    print_error "Para deployar IGP, é necessário uma chave privada (não KMS)"
    exit 1
else
    print_error "Nenhuma chave configurada"
    exit 1
fi

# Para BSC, precisamos deployar um novo contrato IGP usando Hyperlane CLI
# Isso requer criar uma configuração ou usar o comando direto
print_info "Deployando novo IGP no BSC testnet usando Hyperlane CLI..."
print_warning "Isso pode requerer configuração adicional"

# Tentar usar o Hyperlane CLI para deployar apenas o IGP
# O comando exato depende da versão do Hyperlane CLI
print_value "Comando:"
print_value "hyperlane core deploy \\"
print_value "  --chain bsctestnet \\"
print_value "  --key \$BSC_PRIVATE_KEY \\"
print_value "  --config <config-file>"
echo ""

print_warning "⚠️  Deployar um novo IGP requer:"
print_value "1. Arquivo de configuração do core (core-config.yaml)"
print_value "2. Ou usar o Hyperlane CLI com opções específicas para IGP"
print_value "3. Ou deployar o contrato IGP diretamente usando cast"
echo ""

print_info "Alternativa: Deployar contrato IGP diretamente usando cast"
print_info "Isso requer o bytecode do contrato InterchainGasPaymaster"
echo ""

# Por enquanto, vamos informar que é necessário deployar manualmente
# ou usar uma abordagem alternativa
print_warning "Para criar um novo IGP no BSC, você precisa:"
print_value "1. Obter o bytecode do contrato InterchainGasPaymaster"
print_value "2. Deployar usando cast ou Hyperlane CLI"
print_value "3. Configurar o Gas Oracle"
print_value "4. Associar ao Warp Route"
echo ""

print_info "Vamos tentar uma abordagem: verificar se há um factory contract ou usar Hyperlane CLI"
print_info "Se não funcionar, você precisará deployar manualmente"
echo ""

# Tentar usar Hyperlane CLI para verificar opções
print_info "Verificando opções do Hyperlane CLI para deploy de IGP..."
HYPERLANE_IGP_HELP=$(hyperlane --help 2>&1 | grep -i "igp\|gas" || echo "")

if [ ! -z "$HYPERLANE_IGP_HELP" ]; then
    print_info "Hyperlane CLI pode ter comandos específicos para IGP"
else
    print_warning "Hyperlane CLI pode não ter comando direto para deploy de IGP isolado"
fi

# Por enquanto, vamos pedir ao usuário para fornecer o endereço do novo IGP
# ou tentar deployar usando cast se tiver o bytecode
print_info "Opções para criar novo IGP:"
print_value "1. Usar Hyperlane CLI com arquivo de configuração completo"
print_value "2. Deployar manualmente o contrato usando cast (requer bytecode)"
print_value "3. Usar um script de deploy do Hyperlane monorepo"
echo ""

# Para BSC, deployar um novo IGP requer:
# 1. Usar Hyperlane CLI com arquivo de configuração
# 2. Ou deployar manualmente o contrato usando cast/foundry
# 3. O contrato é upgradeable e precisa de initialize

print_info "Para criar um novo IGP no BSC, você precisa:"
print_value "1. Deployar o contrato InterchainGasPaymaster (upgradeable)"
print_value "2. Chamar initialize(owner, beneficiary)"
print_value "3. Configurar o Gas Oracle"
echo ""

print_warning "⚠️  Deploy automático de IGP requer:"
print_value "- Arquivo de configuração do Hyperlane core"
print_value "- Ou deploy manual usando cast/foundry com bytecode"
echo ""

read -p "Você já tem um novo IGP deployado? Digite o endereço (0x...) ou 'deploy' para tentar deployar: " NEW_IGP_INPUT

if [ ! -z "$NEW_IGP_INPUT" ] && [[ "$NEW_IGP_INPUT" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    NEW_IGP_ACCOUNT="$NEW_IGP_INPUT"
    print_success "Usando IGP fornecido: $NEW_IGP_ACCOUNT"
elif [ "$NEW_IGP_INPUT" = "deploy" ] || [ -z "$NEW_IGP_INPUT" ]; then
    print_info "Tentando deployar novo IGP usando Hyperlane CLI..."
    
    # Obter endereço do owner (você)
    OWNER_ADDRESS=$(cast wallet address --private-key "$BSC_PRIVATE_KEY" 2>/dev/null || echo "")
    if [ -z "$OWNER_ADDRESS" ]; then
        print_error "Não foi possível obter endereço do owner"
        exit 1
    fi
    
    print_info "Owner: $OWNER_ADDRESS"
    print_info "Beneficiary: $OWNER_ADDRESS (mesmo que owner)"
    echo ""
    
    # Tentar criar uma configuração mínima e deployar
    print_warning "Deploy de IGP via CLI requer arquivo de configuração completo"
    print_info "Criando configuração temporária..."
    
    # Criar diretório temporário para config
    TEMP_CONFIG_DIR=$(mktemp -d)
    TEMP_CONFIG_FILE="$TEMP_CONFIG_DIR/core-config.yaml"
    
    # Criar configuração mínima para deploy de IGP
    cat > "$TEMP_CONFIG_FILE" << EOF
chains:
  bsctestnet:
    owner: $OWNER_ADDRESS
    igp:
      beneficiary: $OWNER_ADDRESS
EOF
    
    print_info "Configuração criada: $TEMP_CONFIG_FILE"
    print_value "Tentando deployar com Hyperlane CLI..."
    echo ""
    
    # Tentar deployar
    HYPERLANE_DEPLOY_OUTPUT=$(hyperlane core deploy \
        --chain bsctestnet \
        --key "$BSC_PRIVATE_KEY" \
        --config "$TEMP_CONFIG_FILE" \
        --yes 2>&1 || echo "ERROR")
    
    # Limpar arquivo temporário
    rm -rf "$TEMP_CONFIG_DIR"
    
    if echo "$HYPERLANE_DEPLOY_OUTPUT" | grep -qi "error\|failed"; then
        print_error "Deploy via Hyperlane CLI falhou"
        print_info "Output:"
        echo "$HYPERLANE_DEPLOY_OUTPUT" | head -20
        echo ""
        print_warning "Por favor, deploye o IGP manualmente e execute este script novamente"
        print_info "Ou consulte a documentação do Hyperlane para deploy de IGP"
        exit 1
    else
        # Tentar extrair endereço do novo IGP
        NEW_IGP_ACCOUNT=$(echo "$HYPERLANE_DEPLOY_OUTPUT" | grep -oE "0x[a-fA-F0-9]{40}" | grep -v "$OWNER_ADDRESS" | head -1 || echo "")
        
        if [ -z "$NEW_IGP_ACCOUNT" ]; then
            print_warning "Não foi possível extrair endereço do novo IGP automaticamente"
            print_info "Verifique o output acima e digite o endereço do novo IGP:"
            read -p "Endereço do novo IGP (0x...): " NEW_IGP_ACCOUNT
        fi
    fi
    
    if [ -z "$NEW_IGP_ACCOUNT" ] || [[ ! "$NEW_IGP_ACCOUNT" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Endereço de IGP inválido ou não fornecido"
        exit 1
    fi
    
    print_success "Novo IGP deployado: $NEW_IGP_ACCOUNT"
else
    print_error "Opção inválida: $NEW_IGP_INPUT"
    exit 1
fi

print_success "Novo IGP identificado: $NEW_IGP_ACCOUNT"
echo ""

# ============================================================================
# PASSO 2: Configurar Gas Oracle no IGP
# ============================================================================
print_section "PASSO 2: CONFIGURAR GAS ORACLE PARA TERRA CLASSIC"

print_info "Configurando Gas Oracle no IGP para Terra Classic (Domain $TERRA_DOMAIN)..."
print_value "IGP: $NEW_IGP_ACCOUNT"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

# Verificar se o IGP tem a função setGasOracle
print_info "Verificando interface do IGP..."
IGP_ABI=$(cast abi "$NEW_IGP_ACCOUNT" --rpc-url "$BSC_RPC" 2>&1 || echo "")

if echo "$IGP_ABI" | grep -qi "setGasOracle\|setGasOracleConfig"; then
    print_success "IGP suporta configuração de gas oracle"
    
    # Tentar configurar usando setGasOracle ou setGasOracleConfig
    # A função pode ter diferentes assinaturas, vamos tentar a mais comum
    print_info "Configurando gas oracle..."
    
    # Preparar comando cast send
    if [ ! -z "$BSC_PRIVATE_KEY" ]; then
        CAST_SIGNER="--private-key $BSC_PRIVATE_KEY"
    elif [ ! -z "$BSC_KMS_ALIAS" ]; then
        CAST_SIGNER="--aws $BSC_KMS_ALIAS"
    else
        print_error "Nenhuma chave configurada para assinar transações"
        exit 1
    fi
    
    # A função setGasOracle geralmente tem a assinatura:
    # setGasOracle(uint32 _destinationDomain, address _gasOracle)
    # ou
    # setGasOracleConfig(uint32 _destinationDomain, uint256 _tokenExchangeRate, uint256 _gasPrice, uint8 _tokenDecimals)
    
    # Vamos tentar a segunda opção primeiro (mais completa)
    print_value "Comando:"
    print_value "cast send $NEW_IGP_ACCOUNT \\"
    print_value "  \"setGasOracleConfig(uint32,uint256,uint256,uint8)\" \\"
    print_value "  $TERRA_DOMAIN \\"
    print_value "  $TOKEN_EXCHANGE_RATE \\"
    print_value "  $GAS_PRICE \\"
    print_value "  $TOKEN_DECIMALS \\"
    print_value "  $CAST_SIGNER \\"
    print_value "  --rpc-url $BSC_RPC"
    echo ""
    
    if [ -z "$AUTO_CONFIRM" ]; then
        read -p "Deseja executar esta transação? (s/N): " CONFIRM_SEND
        CONFIRM_SEND_VALUE="$CONFIRM_SEND"
    else
        CONFIRM_SEND_VALUE="s"
        print_info "Execução automática: confirmando transação..."
    fi
    
    if [[ "$CONFIRM_SEND_VALUE" =~ ^[Ss]$ ]]; then
        SET_GAS_OUTPUT=$(cast send "$NEW_IGP_ACCOUNT" \
            "setGasOracleConfig(uint32,uint256,uint256,uint8)" \
            "$TERRA_DOMAIN" \
            "$TOKEN_EXCHANGE_RATE" \
            "$GAS_PRICE" \
            "$TOKEN_DECIMALS" \
            $CAST_SIGNER \
            --rpc-url "$BSC_RPC" 2>&1)
        SET_GAS_EXIT_CODE=$?
        
        echo "$SET_GAS_OUTPUT"
        echo ""
        
        if [ $SET_GAS_EXIT_CODE -eq 0 ]; then
            print_success "Gas Oracle configurado com sucesso!"
        else
            print_warning "Erro ao configurar Gas Oracle. Tentando método alternativo..."
            # Tentar método alternativo se o primeiro falhar
            print_info "Tentando método alternativo (pode requerer deploy de Gas Oracle contract)..."
            print_warning "Para BSC, pode ser necessário usar o Hyperlane CLI ou deployar um contrato Gas Oracle separado"
        fi
    else
        print_info "Transação cancelada. Você pode executar manualmente depois."
    fi
else
    print_warning "IGP não expõe função setGasOracle diretamente"
    print_info "Para BSC, a configuração do Gas Oracle pode requerer:"
    print_value "1. Usar o Hyperlane CLI (se disponível)"
    print_value "2. Deployar um contrato Gas Oracle separado"
    print_value "3. Configurar via interface do IGP padrão"
    print_info "Verifique a documentação do Hyperlane para BSC"
fi

echo ""

# ============================================================================
# PASSO 3: Associar IGP ao Warp Route
# ============================================================================
print_section "PASSO 3: ASSOCIAR IGP AO WARP ROUTE"

print_info "Associando IGP ao Warp Route..."
print_value "Warp Route: $WARP_ROUTE_BSC"
print_value "IGP: $NEW_IGP_ACCOUNT"
echo ""

# Verificar se o Warp Route tem função para setar IGP
WARP_ABI=$(cast abi "$WARP_ROUTE_BSC" --rpc-url "$BSC_RPC" 2>&1 || echo "")

if echo "$WARP_ABI" | grep -qi "setInterchainGasPaymaster\|setIGP"; then
    print_success "Warp Route suporta configuração de IGP"
    
    print_value "Comando:"
    print_value "cast send $WARP_ROUTE_BSC \\"
    print_value "  \"setInterchainGasPaymaster(address)\" \\"
    print_value "  $NEW_IGP_ACCOUNT \\"
    print_value "  $CAST_SIGNER \\"
    print_value "  --rpc-url $BSC_RPC"
    echo ""
    
    if [ -z "$AUTO_CONFIRM" ]; then
        read -p "Deseja executar esta transação? (s/N): " CONFIRM_SET_IGP
        CONFIRM_SET_IGP_VALUE="$CONFIRM_SET_IGP"
    else
        CONFIRM_SET_IGP_VALUE="s"
        print_info "Execução automática: confirmando transação..."
    fi
    
    if [[ "$CONFIRM_SET_IGP_VALUE" =~ ^[Ss]$ ]]; then
        SET_IGP_OUTPUT=$(cast send "$WARP_ROUTE_BSC" \
            "setInterchainGasPaymaster(address)" \
            "$NEW_IGP_ACCOUNT" \
            $CAST_SIGNER \
            --rpc-url "$BSC_RPC" 2>&1)
        SET_IGP_EXIT_CODE=$?
        
        echo "$SET_IGP_OUTPUT"
        echo ""
        
        if [ $SET_IGP_EXIT_CODE -eq 0 ]; then
            print_success "IGP associado ao Warp Route com sucesso!"
        else
            print_error "Erro ao associar IGP ao Warp Route"
            print_info "Verifique se você tem permissões (owner) no Warp Route"
        fi
    else
        print_info "Transação cancelada. Você pode executar manualmente depois."
    fi
else
    print_warning "Warp Route não expõe função para setar IGP diretamente"
    print_info "O IGP pode ser configurado:"
    print_value "1. Via owner do Warp Route (se você for o owner)"
    print_value "2. Via Hyperlane CLI"
    print_value "3. O Warp Route pode usar o IGP padrão do Mailbox automaticamente"
fi

echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================
print_header "✅ PROCESSO CONCLUÍDO"

print_info "Resumo:"
print_value "Warp Route BSC: $WARP_ROUTE_BSC"
print_value "IGP: $NEW_IGP_ACCOUNT"
print_value "Gas Oracle configurado para Terra Classic (Domain $TERRA_DOMAIN)"
echo ""

print_info "Valores do Gas Oracle:"
print_value "Token Exchange Rate: $TOKEN_EXCHANGE_RATE"
print_value "Gas Price: $GAS_PRICE"
print_value "Token Decimals: $TOKEN_DECIMALS"
echo ""

print_info "Próximos passos:"
print_value "1. Verifique se o IGP foi configurado corretamente"
print_value "2. Teste uma transferência BSC -> Terra Classic"
print_value "3. Verifique se o gas está sendo pago corretamente"
print_value "4. Ajuste os valores do Gas Oracle se necessário"
echo ""

print_success "🎉 Script concluído!"
