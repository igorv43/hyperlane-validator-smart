#!/bin/bash

# ============================================================================
# Script: Query Validator S3 Files
# ============================================================================
# Este script facilita o acesso aos arquivos do validator armazenados no S3:
# - Checkpoints
# - Announcements
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/hyperlane/validator.terraclassic-testnet.json"
ENV_FILE="${SCRIPT_DIR}/.env"

# Função para carregar variáveis do arquivo .env
load_env_file() {
    if [ -f "$ENV_FILE" ]; then
        # Carregar variáveis do .env (ignorando comentários e linhas vazias)
        # Usar source direto para garantir que as variáveis sejam exportadas
        while IFS= read -r line || [ -n "$line" ]; do
            # Ignorar comentários e linhas vazias
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
                continue
            fi
            # Exportar variável
            export "$line" 2>/dev/null || true
        done < "$ENV_FILE"
    fi
}

# Função para ler configuração do arquivo JSON
load_config_from_file() {
    if [ -f "$CONFIG_FILE" ]; then
        # Tentar usar jq se disponível
        if command -v jq &> /dev/null; then
            local file_bucket=$(jq -r '.checkpointSyncer.bucket // empty' "$CONFIG_FILE" 2>/dev/null)
            local file_region=$(jq -r '.checkpointSyncer.region // empty' "$CONFIG_FILE" 2>/dev/null)
            
            if [ -n "$file_bucket" ] && [ "$file_bucket" != "null" ] && [ "$file_bucket" != "" ]; then
                BUCKET="$file_bucket"
            fi
            
            if [ -n "$file_region" ] && [ "$file_region" != "null" ] && [ "$file_region" != "" ]; then
                REGION="$file_region"
            fi
        else
            # Fallback: usar grep/sed se jq não estiver disponível
            local file_bucket=$(grep -o '"bucket"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"bucket"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            local file_region=$(grep -o '"region"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"region"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            
            if [ -n "$file_bucket" ] && [ "$file_bucket" != "" ]; then
                BUCKET="$file_bucket"
            fi
            
            if [ -n "$file_region" ] && [ "$file_region" != "" ]; then
                REGION="$file_region"
            fi
        fi
    fi
}

# Carregar arquivo .env primeiro (se existir)
load_env_file

# Valores padrão (podem ser sobrescritos por variáveis de ambiente ou arquivo)
BUCKET="${HYP_CHECKPOINT_SYNCER_BUCKET:-}"
REGION="${HYP_CHECKPOINT_SYNCER_REGION:-${AWS_REGION:-us-east-1}}"
DOMAIN="${DOMAIN:-1325}"  # Terra Classic Testnet

# Tentar carregar do arquivo de configuração JSON se bucket não estiver definido
if [ -z "$BUCKET" ]; then
    load_config_from_file
fi

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   $1${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Função para construir URL do S3
build_s3_url() {
    local file_path=$1
    echo "https://${BUCKET}.s3.${REGION}.amazonaws.com/${file_path}"
}

# Função para verificar se arquivo existe e está acessível
check_file_access() {
    local url=$1
    local silent=${2:-0}  # Se 1, não mostra erros (para tentativas silenciosas)
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    case $http_code in
        200)
            return 0  # Arquivo existe e está acessível
            ;;
        403)
            if [ "$silent" -eq 0 ]; then
                print_error "Arquivo existe mas não está público (403 Forbidden)"
            fi
            return 1
            ;;
        404)
            if [ "$silent" -eq 0 ]; then
                print_error "Arquivo não encontrado (404 Not Found)"
            fi
            return 1
            ;;
        *)
            if [ "$silent" -eq 0 ]; then
                print_error "Erro ao acessar arquivo (HTTP $http_code)"
            fi
            return 1
            ;;
    esac
}

# Função para baixar e exibir checkpoint
download_checkpoint() {
    local checkpoint_index=$1
    
    print_info "Buscando checkpoint: $checkpoint_index"
    echo ""
    
    # Tentar primeiro o caminho padrão (silenciosamente)
    local file_path="checkpoints/${DOMAIN}/${checkpoint_index}.json"
    local url=$(build_s3_url "$file_path")
    
    if check_file_access "$url" 1; then
        print_success "Checkpoint encontrado!"
        echo ""
        curl -s "$url" | jq '.' 2>/dev/null || curl -s "$url"
        return 0
    fi
    
    # Tentar caminho alternativo (formato checkpoint_N_with_id.json)
    local file_path_alt="checkpoint_${checkpoint_index}_with_id.json"
    local url_alt=$(build_s3_url "$file_path_alt")
    
    if check_file_access "$url_alt" 1; then
        print_success "Checkpoint encontrado!"
        echo ""
        curl -s "$url_alt" | jq '.' 2>/dev/null || curl -s "$url_alt"
        return 0
    fi
    
    # Tentar formato simples checkpoint_N.json
    local file_path_simple="checkpoint_${checkpoint_index}.json"
    local url_simple=$(build_s3_url "$file_path_simple")
    
    if check_file_access "$url_simple" 1; then
        print_success "Checkpoint encontrado!"
        echo ""
        curl -s "$url_simple" | jq '.' 2>/dev/null || curl -s "$url_simple"
        return 0
    fi
    
    # Se nenhum caminho funcionou, mostrar erro
    print_error "Não foi possível acessar o checkpoint $checkpoint_index"
    print_info "Tentados os seguintes caminhos:"
    echo "  1. $url"
    echo "  2. $url_alt"
    echo "  3. $url_simple"
    return 1
}

# Função para baixar e exibir announcement
download_announcement() {
    local validator_address=$1
    
    print_info "Buscando announcement do validator"
    if [ -n "$validator_address" ]; then
        print_info "Endereço do validator: $validator_address"
    fi
    echo ""
    
    # Tentar primeiro o formato padrão: announcements/{address}.json
    if [ -n "$validator_address" ]; then
        local file_path="announcements/${validator_address}.json"
        local url=$(build_s3_url "$file_path")
        
        if check_file_access "$url" 1; then
            print_success "Announcement encontrado!"
            echo ""
            curl -s "$url" | jq '.' 2>/dev/null || curl -s "$url"
            return 0
        fi
    fi
    
    # Tentar formato alternativo: announcement.json (na raiz)
    local file_path_alt="announcement.json"
    local url_alt=$(build_s3_url "$file_path_alt")
    
    if check_file_access "$url_alt" 1; then
        print_success "Announcement encontrado!"
        echo ""
        curl -s "$url_alt" | jq '.' 2>/dev/null || curl -s "$url_alt"
        return 0
    fi
    
    # Se nenhum funcionou, mostrar erro
    print_error "Não foi possível acessar o announcement"
    if [ -n "$validator_address" ]; then
        print_info "Tentados os seguintes caminhos:"
        echo "  1. announcements/${validator_address}.json"
        echo "  2. announcement.json"
    else
        print_info "Tentado caminho: announcement.json"
        print_info "Dica: Você pode especificar o endereço do validator como argumento"
    fi
    return 1
}

# Função para listar checkpoints disponíveis (requer AWS CLI)
list_checkpoints() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI não está instalado. Instale para usar esta funcionalidade."
        print_info "Instalação: https://aws.amazon.com/cli/"
        return 1
    fi
    
    # Verificar se credenciais AWS estão configuradas
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        print_error "Credenciais AWS não encontradas!"
        print_info "Certifique-se de que AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY estão configuradas"
        print_info "Configure no arquivo .env ou como variáveis de ambiente"
        return 1
    fi
    
    if [ -z "$BUCKET" ]; then
        print_error "Bucket não configurado!"
        return 1
    fi
    
    print_info "Listando checkpoints do bucket: $BUCKET"
    print_info "Region: $REGION"
    echo ""
    
    # Configurar região para AWS CLI
    export AWS_DEFAULT_REGION="$REGION"
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    
    # Tentar primeiro o caminho padrão do Hyperlane: checkpoints/{domain}/
    local s3_path_standard="s3://${BUCKET}/checkpoints/${DOMAIN}/"
    local output=$(aws s3 ls "$s3_path_standard" --recursive 2>&1)
    local exit_code=$?
    
    # Se não encontrar no caminho padrão, tentar na raiz do bucket
    if [ $exit_code -ne 0 ] || [ -z "$output" ]; then
        print_info "Tentando caminho alternativo (raiz do bucket)..."
        local s3_path_root="s3://${BUCKET}/"
        output=$(aws s3 ls "$s3_path_root" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
            # Filtrar apenas arquivos de checkpoint e processar com data/hora
            local checkpoints=$(echo "$output" | \
                grep -E "checkpoint_[0-9]+.*\.json$" | \
                while IFS= read -r line; do
                    # Extrair data, hora e nome do arquivo
                    local date_part=$(echo "$line" | awk '{print $1}')
                    local time_part=$(echo "$line" | awk '{print $2}')
                    local filename=$(echo "$line" | awk '{print $4}')
                    
                    # Extrair número do checkpoint
                    local checkpoint_num=$(echo "$filename" | sed -n 's/checkpoint_\([0-9]*\)_with_id\.json/\1/p')
                    
                    if [ -n "$checkpoint_num" ]; then
                        # Converter data de YYYY-MM-DD para MM/DD/YYYY
                        local year=$(echo "$date_part" | cut -d'-' -f1)
                        local month=$(echo "$date_part" | cut -d'-' -f2)
                        local day=$(echo "$date_part" | cut -d'-' -f3)
                        
                        # Formatar: MM/DD/YYYY H:M:S (remover zeros à esquerda da hora)
                        local formatted_date="${month}/${day}/${year}"
                        local time_no_ms=$(echo "$time_part" | cut -d'.' -f1)
                        local hour=$(echo "$time_no_ms" | cut -d':' -f1 | sed 's/^0*//')
                        local minute=$(echo "$time_no_ms" | cut -d':' -f2 | sed 's/^0*//')
                        local second=$(echo "$time_no_ms" | cut -d':' -f3 | sed 's/^0*//')
                        
                        # Garantir que não fique vazio (se for 0, manter como 0)
                        [ -z "$hour" ] && hour="0"
                        [ -z "$minute" ] && minute="0"
                        [ -z "$second" ] && second="0"
                        
                        local formatted_time="${hour}:${minute}:${second}"
                        
                        # Formatar linha mantendo número para ordenação
                        echo "${checkpoint_num}|${formatted_date} ${formatted_time} - ${checkpoint_num}(checkpoint)"
                    fi
                done | sort -t'|' -k1 -n | cut -d'|' -f2)
            
            if [ -n "$checkpoints" ]; then
                local count=$(echo "$checkpoints" | wc -l)
                print_success "Encontrados $count checkpoint(s):"
                echo ""
                echo "$checkpoints"
                return 0
            fi
        fi
    else
        # Processar output do caminho padrão com data/hora
        echo "$output" | \
            while IFS= read -r line; do
                local date_part=$(echo "$line" | awk '{print $1}')
                local time_part=$(echo "$line" | awk '{print $2}')
                local filename=$(echo "$line" | awk '{print $4}')
                local checkpoint_num=$(echo "$filename" | sed 's|checkpoints/[0-9]*/||' | sed 's|\.json||')
                
                if [ -n "$checkpoint_num" ]; then
                    local year=$(echo "$date_part" | cut -d'-' -f1)
                    local month=$(echo "$date_part" | cut -d'-' -f2)
                    local day=$(echo "$date_part" | cut -d'-' -f3)
                    local formatted_date="${month}/${day}/${year}"
                    local time_no_ms=$(echo "$time_part" | cut -d'.' -f1)
                    local hour=$(echo "$time_no_ms" | cut -d':' -f1 | sed 's/^0*//')
                    local minute=$(echo "$time_no_ms" | cut -d':' -f2 | sed 's/^0*//')
                    local second=$(echo "$time_no_ms" | cut -d':' -f3 | sed 's/^0*//')
                    
                    # Garantir que não fique vazio (se for 0, manter como 0)
                    [ -z "$hour" ] && hour="0"
                    [ -z "$minute" ] && minute="0"
                    [ -z "$second" ] && second="0"
                    
                    local formatted_time="${hour}:${minute}:${second}"
                    
                    # Formatar linha mantendo número para ordenação
                    echo "${checkpoint_num}|${formatted_date} ${formatted_time} - ${checkpoint_num}(checkpoint)"
                fi
            done | sort -t'|' -k1 -n | cut -d'|' -f2
        return 0
    fi
    
    # Se chegou aqui, houve erro
    if [ $exit_code -ne 0 ]; then
        print_error "Erro ao acessar S3 (código: $exit_code)"
        echo "$output" | head -5
        echo ""
        print_info "Verificações:"
        echo "  - Bucket existe: $BUCKET"
        echo "  - Credenciais AWS configuradas: $([ -n "$AWS_ACCESS_KEY_ID" ] && echo "sim" || echo "não")"
        echo "  - Região: $REGION"
        return 1
    fi
    
    print_warning "Nenhum checkpoint encontrado"
    print_info "Verifique se:"
    echo "  - O validator está gerando checkpoints"
    echo "  - O bucket está correto: $BUCKET"
    return 0
}

# Função para obter último checkpoint
get_latest_checkpoint() {
    local latest=$(list_checkpoints | tail -1)
    
    if [ -z "$latest" ]; then
        print_error "Nenhum checkpoint encontrado"
        return 1
    fi
    
    print_success "Último checkpoint: $latest"
    download_checkpoint "$latest"
}

# Função para exibir informações de configuração
show_config() {
    print_header "CONFIGURAÇÃO ATUAL"
    
    echo -e "${CYAN}Bucket:${NC} ${BUCKET:-<não configurado>}"
    echo -e "${CYAN}Region:${NC} $REGION"
    echo -e "${CYAN}Domain:${NC} $DOMAIN (Terra Classic Testnet)"
    echo ""
    
    echo -e "${CYAN}Arquivos de configuração:${NC}"
    if [ -f "$ENV_FILE" ]; then
        echo -e "  ${GREEN}✓${NC} .env encontrado: $ENV_FILE"
    else
        echo -e "  ${YELLOW}⚠${NC} .env não encontrado: $ENV_FILE"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  ${GREEN}✓${NC} Config validator encontrado: $CONFIG_FILE"
    else
        echo -e "  ${YELLOW}⚠${NC} Config validator não encontrado: $CONFIG_FILE"
    fi
    echo ""
    
    echo -e "${CYAN}Credenciais AWS:${NC}"
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        echo -e "  ${GREEN}✓${NC} AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}... (configurado)"
    else
        echo -e "  ${YELLOW}⚠${NC} AWS_ACCESS_KEY_ID: não configurado"
    fi
    
    if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        echo -e "  ${GREEN}✓${NC} AWS_SECRET_ACCESS_KEY: *** (configurado)"
    else
        echo -e "  ${YELLOW}⚠${NC} AWS_SECRET_ACCESS_KEY: não configurado"
    fi
    
    if [ -n "$AWS_REGION" ]; then
        echo -e "  ${GREEN}✓${NC} AWS_REGION: $AWS_REGION"
    else
        echo -e "  ${YELLOW}⚠${NC} AWS_REGION: não configurado"
    fi
    echo ""
    
    if [ -z "$BUCKET" ]; then
        print_warning "Bucket não configurado!"
        echo ""
        echo "Opções para configurar:"
        echo "  1. Use --bucket <nome> na linha de comando"
        echo "  2. Configure HYP_CHECKPOINT_SYNCER_BUCKET no arquivo .env"
        echo "  3. Configure HYP_CHECKPOINT_SYNCER_BUCKET como variável de ambiente"
        echo "  4. Configure no arquivo: $CONFIG_FILE"
    fi
}

# ============================================================================
# MENU DE AJUDA
# ============================================================================

show_help() {
    print_header "QUERY VALIDATOR S3 - Ajuda"
    
    echo "Uso: $0 [OPÇÕES] [COMANDO] [ARGUMENTOS]"
    echo ""
    echo "Comandos:"
    echo "  checkpoint <index>     Baixar e exibir checkpoint específico"
    echo "  announcement [address]  Baixar e exibir announcement do validator (address opcional)"
    echo "  list                   Listar todos os checkpoints disponíveis"
    echo "  latest                 Obter o último checkpoint"
    echo "  config                 Exibir configuração atual"
    echo ""
    echo "Opções:"
    echo "  --bucket <name>        Especificar bucket S3"
    echo "  --region <region>      Especificar região AWS (padrão: us-east-1)"
    echo "  --domain <id>          Especificar domain ID (padrão: 1325)"
    echo "  -h, --help             Exibir esta ajuda"
    echo ""
    echo "Variáveis de Ambiente:"
    echo "  HYP_CHECKPOINT_SYNCER_BUCKET    Nome do bucket S3"
    echo "  HYP_CHECKPOINT_SYNCER_REGION    Região do bucket"
    echo "  AWS_REGION                      Região AWS (fallback)"
    echo ""
    echo "Exemplos:"
    echo "  $0 checkpoint 28563839"
    echo "  $0 --bucket meu-bucket checkpoint 28563839"
    echo "  $0 announcement 0x1234...abcd"
    echo "  $0 list"
    echo "  $0 latest"
    echo ""
}

# ============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# ============================================================================

COMMAND=""
COMMAND_ARG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --bucket)
            BUCKET="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        checkpoint|announcement|list|latest|config)
            COMMAND="$1"
            if [ "$1" = "announcement" ] || [ "$1" = "checkpoint" ]; then
                if [ -n "$2" ] && [[ ! "$2" =~ ^-- ]]; then
                    COMMAND_ARG="$2"
                    shift
                fi
            fi
            shift
            ;;
        *)
            print_error "Opção desconhecida: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# VALIDAÇÃO E EXECUÇÃO
# ============================================================================

if [ -z "$COMMAND" ]; then
    show_help
    exit 0
fi

# Tentar carregar do arquivo novamente antes de validar (caso tenha sido passado --bucket depois)
if [ -z "$BUCKET" ]; then
    load_config_from_file
fi

# Validar bucket para comandos que precisam
if [ "$COMMAND" != "config" ] && [ -z "$BUCKET" ]; then
    print_error "Bucket não especificado!"
    echo ""
    print_info "Opções para configurar:"
    echo "  1. Use --bucket <nome> na linha de comando"
    echo "  2. Configure HYP_CHECKPOINT_SYNCER_BUCKET como variável de ambiente"
    echo "  3. Configure no arquivo: $CONFIG_FILE"
    echo ""
    show_help
    exit 1
fi

# Executar comando
case $COMMAND in
    checkpoint)
        if [ -z "$COMMAND_ARG" ]; then
            print_error "Índice do checkpoint não especificado"
            echo "Uso: $0 checkpoint <index>"
            exit 1
        fi
        download_checkpoint "$COMMAND_ARG"
        ;;
    announcement)
        # Endereço do validator é opcional (pode tentar announcement.json na raiz)
        download_announcement "$COMMAND_ARG"
        ;;
    list)
        list_checkpoints
        ;;
    latest)
        get_latest_checkpoint
        ;;
    config)
        show_config
        ;;
    *)
        print_error "Comando desconhecido: $COMMAND"
        show_help
        exit 1
        ;;
esac
