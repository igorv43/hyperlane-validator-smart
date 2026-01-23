# Guia Completo: Query Validator S3

Este documento explica como configurar e usar o script `query-validator-s3.sh` para consultar checkpoints e announcements do validator Hyperlane armazenados no AWS S3.

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Configuração](#configuração)
3. [Comandos Disponíveis](#comandos-disponíveis)
4. [Exemplos de Uso](#exemplos-de-uso)
5. [Troubleshooting](#troubleshooting)

---

## 🔧 Pré-requisitos

### Ferramentas Necessárias

1. **AWS CLI** (opcional, apenas para comando `list`)
   ```bash
   # Instalar AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **jq** (opcional, para formatação JSON)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install jq
   
   # Ou usar sem jq (o script funciona, mas JSON não será formatado)
   ```

3. **curl** (geralmente já instalado)
   ```bash
   # Verificar se está instalado
   curl --version
   ```

---

## ⚙️ Configuração

O script detecta automaticamente as configurações em **3 níveis de prioridade**:

### 1. Opções da Linha de Comando (Maior Prioridade)

```bash
./query-validator-s3.sh --bucket meu-bucket --region us-west-2 list
```

### 2. Variáveis de Ambiente

```bash
export HYP_CHECKPOINT_SYNCER_BUCKET="meu-bucket"
export HYP_CHECKPOINT_SYNCER_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="sua-key"
export AWS_SECRET_ACCESS_KEY="sua-secret"
```

### 3. Arquivo `.env` (Recomendado)

O script carrega automaticamente o arquivo `.env` na raiz do projeto.

**Estrutura do `.env`:**

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=sua_access_key_aqui
AWS_SECRET_ACCESS_KEY=sua_secret_key_aqui
AWS_REGION=us-east-1

# S3 Bucket Configuration
HYP_CHECKPOINT_SYNCER_BUCKET=hyperlane-validator-signatures-seu-nome-aqui
HYP_CHECKPOINT_SYNCER_REGION=us-east-1
```

### 4. Arquivo de Configuração do Validator (Fallback)

Se o bucket não estiver definido, o script tenta ler de:
```
hyperlane/validator.terraclassic-testnet.json
```

---

## 📚 Comandos Disponíveis

### 1. `checkpoint <index>`

Baixa e exibe um checkpoint específico pelo seu índice.

**Sintaxe:**
```bash
./query-validator-s3.sh checkpoint <index>
```

**Exemplo:**
```bash
./query-validator-s3.sh checkpoint 18
```

**O que faz:**
- Tenta múltiplos formatos de arquivo:
  1. `checkpoints/{domain}/{index}.json` (formato padrão Hyperlane)
  2. `checkpoint_{index}_with_id.json` (formato atual)
  3. `checkpoint_{index}.json` (formato simples)
- Exibe o JSON formatado do checkpoint

**Saída:**
```json
{
  "value": {
    "checkpoint": {
      "merkle_tree_hook_address": "0x...",
      "mailbox_domain": 1325,
      "root": "0x...",
      "index": 18
    },
    "message_id": "0x..."
  },
  "signature": {
    "r": "0x...",
    "s": "0x...",
    "v": 28
  }
}
```

---

### 2. `announcement [address]`

Baixa e exibe o announcement do validator.

**Sintaxe:**
```bash
./query-validator-s3.sh announcement [address]
```

**Exemplos:**
```bash
# Sem argumento (usa announcement.json da raiz)
./query-validator-s3.sh announcement

# Com endereço do validator
./query-validator-s3.sh announcement 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
```

**O que faz:**
- Se o endereço for fornecido, tenta: `announcements/{address}.json`
- Se não fornecido ou não encontrado, tenta: `announcement.json` (raiz)
- Exibe o JSON formatado do announcement

**Saída:**
```json
{
  "value": {
    "validator": "0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0",
    "mailbox_address": "0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd",
    "mailbox_domain": 1325,
    "storage_location": "s3://bucket-name/region"
  },
  "signature": {
    "r": "0x...",
    "s": "0x...",
    "v": 28
  }
}
```

---

### 3. `list`

Lista todos os checkpoints disponíveis no bucket.

**Sintaxe:**
```bash
./query-validator-s3.sh list
```

**Requisitos:**
- AWS CLI instalado
- Credenciais AWS configuradas (no `.env` ou variáveis de ambiente)

**O que faz:**
- Lista todos os checkpoints do domain configurado
- Tenta primeiro: `checkpoints/{domain}/`
- Se não encontrar, tenta na raiz do bucket
- Extrai os índices dos checkpoints e ordena numericamente

**Saída:**
```
✅ Encontrados 17 checkpoint(s):

6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
```

---

### 4. `latest`

Obtém e exibe o último checkpoint disponível.

**Sintaxe:**
```bash
./query-validator-s3.sh latest
```

**O que faz:**
- Lista todos os checkpoints
- Identifica o último (maior índice)
- Baixa e exibe o checkpoint completo

**Exemplo:**
```bash
./query-validator-s3.sh latest
```

**Saída:**
```
✅ Último checkpoint: 22
✅ Checkpoint encontrado!

{
  "value": {
    "checkpoint": {
      ...
      "index": 22
    }
  },
  ...
}
```

---

### 5. `config`

Exibe a configuração atual detectada pelo script.

**Sintaxe:**
```bash
./query-validator-s3.sh config
```

**O que faz:**
- Mostra bucket, região e domain configurados
- Indica quais arquivos de configuração foram encontrados
- Verifica se as credenciais AWS estão configuradas

**Saída:**
```
╔══════════════════════════════════════════════════════════════╗
║   CONFIGURAÇÃO ATUAL
╚══════════════════════════════════════════════════════════════╝

Bucket: hyperlane-validator-signatures-igorverasvalidador-terraclassic
Region: us-east-1
Domain: 1325 (Terra Classic Testnet)

Arquivos de configuração:
  ✓ .env encontrado: /home/lunc/hyperlane-validator-smart/.env
  ⚠ Config validator não encontrado: ...

Credenciais AWS:
  ✓ AWS_ACCESS_KEY_ID: AKIAWK73T2... (configurado)
  ✓ AWS_SECRET_ACCESS_KEY: *** (configurado)
  ✓ AWS_REGION: us-east-1
```

---

## 💡 Exemplos de Uso

### Exemplo 1: Consultar Checkpoint Específico

```bash
# Consultar checkpoint 18
./query-validator-s3.sh checkpoint 18
```

### Exemplo 2: Ver Announcement do Validator

```bash
# Ver announcement (sem especificar endereço)
./query-validator-s3.sh announcement
```

### Exemplo 3: Listar Todos os Checkpoints

```bash
# Listar todos os checkpoints disponíveis
./query-validator-s3.sh list
```

### Exemplo 4: Obter Último Checkpoint

```bash
# Obter o último checkpoint gerado
./query-validator-s3.sh latest
```

### Exemplo 5: Verificar Configuração

```bash
# Ver configuração atual
./query-validator-s3.sh config
```

### Exemplo 6: Especificar Bucket Manualmente

```bash
# Usar bucket diferente sem modificar .env
./query-validator-s3.sh --bucket outro-bucket list
```

### Exemplo 7: Especificar Domain Diferente

```bash
# Consultar checkpoints de outro domain (ex: BSC Testnet = 97)
./query-validator-s3.sh --domain 97 list
```

### Exemplo 8: Combinar Opções

```bash
# Especificar bucket, região e domain
./query-validator-s3.sh --bucket meu-bucket --region us-west-2 --domain 97 checkpoint 12345
```

---

## 🔍 Opções Disponíveis

### `--bucket <nome>`

Especifica o nome do bucket S3 manualmente.

```bash
./query-validator-s3.sh --bucket meu-bucket list
```

### `--region <região>`

Especifica a região AWS (padrão: `us-east-1`).

```bash
./query-validator-s3.sh --region us-west-2 list
```

### `--domain <id>`

Especifica o Domain ID (padrão: `1325` = Terra Classic Testnet).

**Domain IDs comuns:**
- `1325` - Terra Classic Testnet
- `97` - BSC Testnet
- `1399811150` - Solana Testnet

```bash
./query-validator-s3.sh --domain 97 list
```

### `-h, --help`

Exibe a ajuda completa do script.

```bash
./query-validator-s3.sh --help
```

---

## 🛠️ Troubleshooting

### Problema: "Bucket não especificado!"

**Causa:** O bucket não está configurado em nenhuma fonte.

**Solução:**
1. Configure no arquivo `.env`:
   ```bash
   HYP_CHECKPOINT_SYNCER_BUCKET=seu-bucket-aqui
   ```

2. Ou use a opção `--bucket`:
   ```bash
   ./query-validator-s3.sh --bucket seu-bucket list
   ```

3. Ou configure como variável de ambiente:
   ```bash
   export HYP_CHECKPOINT_SYNCER_BUCKET="seu-bucket-aqui"
   ```

---

### Problema: "Credenciais AWS não encontradas!"

**Causa:** As credenciais AWS não estão configuradas.

**Solução:**
1. Configure no arquivo `.env`:
   ```bash
   AWS_ACCESS_KEY_ID=sua_access_key
   AWS_SECRET_ACCESS_KEY=sua_secret_key
   AWS_REGION=us-east-1
   ```

2. Ou configure como variáveis de ambiente:
   ```bash
   export AWS_ACCESS_KEY_ID="sua_access_key"
   export AWS_SECRET_ACCESS_KEY="sua_secret_key"
   export AWS_REGION="us-east-1"
   ```

**Nota:** As credenciais são necessárias apenas para o comando `list` (que usa AWS CLI). Os comandos `checkpoint` e `announcement` funcionam via HTTP público.

---

### Problema: "AWS CLI não está instalado"

**Causa:** O comando `list` requer AWS CLI, mas não está instalado.

**Solução:**
1. Instale o AWS CLI (veja [Pré-requisitos](#pré-requisitos))
2. Ou use os comandos `checkpoint` e `announcement` que não requerem AWS CLI

---

### Problema: "Nenhum checkpoint encontrado"

**Causas possíveis:**
1. O validator não está gerando checkpoints
2. O domain ID está incorreto
3. O bucket está incorreto

**Solução:**
1. Verifique a configuração:
   ```bash
   ./query-validator-s3.sh config
   ```

2. Verifique se o validator está rodando:
   ```bash
   docker ps | grep validator
   ```

3. Verifique os logs do validator:
   ```bash
   docker logs hpl-validator-terraclassic-testnet
   ```

---

### Problema: "403 Forbidden" ao acessar arquivos

**Causa:** O bucket ou arquivos não estão configurados como públicos.

**Solução:**
1. Configure a política do bucket S3 para permitir leitura pública (veja `AWS-S3-ACCESS-GUIDE.md`)
2. Ou use AWS CLI com credenciais (comando `list`)

---

### Problema: "404 Not Found" ao acessar checkpoint

**Causa:** O checkpoint não existe ou o formato do arquivo é diferente.

**Solução:**
1. Liste os checkpoints disponíveis:
   ```bash
   ./query-validator-s3.sh list
   ```

2. Verifique o formato dos arquivos no bucket:
   ```bash
   aws s3 ls s3://seu-bucket/ --recursive | head -10
   ```

3. O script tenta automaticamente múltiplos formatos, mas se nenhum funcionar, verifique manualmente

---

## 📖 Estrutura dos Arquivos no S3

### Formato Atual (Detectado)

```
s3://bucket-name/
├── announcement.json                    # Announcement do validator
├── checkpoint_6_with_id.json           # Checkpoint 6
├── checkpoint_7_with_id.json           # Checkpoint 7
├── checkpoint_8_with_id.json           # Checkpoint 8
└── ...
```

### Formato Padrão Hyperlane (Também Suportado)

```
s3://bucket-name/
├── announcements/
│   └── {validator-address}.json
└── checkpoints/
    └── {domain-id}/
        ├── {index}.json
        └── ...
```

---

## 🔐 Segurança

### ⚠️ Importante

1. **Nunca commite o arquivo `.env`** - Ele contém credenciais sensíveis
2. **O arquivo `.env` está no `.gitignore`** - Não será commitado acidentalmente
3. **Use apenas leitura** - O script apenas lê arquivos, nunca modifica
4. **Credenciais AWS** - Mantenha suas chaves seguras e nunca as compartilhe

---

## 📝 Variáveis de Ambiente

### Variáveis Obrigatórias (para comando `list`)

```bash
AWS_ACCESS_KEY_ID=sua_access_key
AWS_SECRET_ACCESS_KEY=sua_secret_key
AWS_REGION=us-east-1
```

### Variáveis Obrigatórias (para todos os comandos)

```bash
HYP_CHECKPOINT_SYNCER_BUCKET=nome-do-bucket
HYP_CHECKPOINT_SYNCER_REGION=us-east-1  # Opcional, usa AWS_REGION se não definido
```

### Variáveis Opcionais

```bash
DOMAIN=1325  # Opcional, padrão: 1325 (Terra Classic Testnet)
```

---

## 🎯 Casos de Uso

### 1. Verificar se Validator Está Gerando Checkpoints

```bash
# Listar checkpoints
./query-validator-s3.sh list

# Ver último checkpoint
./query-validator-s3.sh latest
```

### 2. Analisar Checkpoint Específico

```bash
# Ver checkpoint 18
./query-validator-s3.sh checkpoint 18 | jq '.value.checkpoint'
```

### 3. Verificar Configuração do Validator

```bash
# Ver announcement
./query-validator-s3.sh announcement | jq '.value'
```

### 4. Monitorar Novos Checkpoints

```bash
# Script para monitorar (exemplo)
while true; do
    ./query-validator-s3.sh latest
    sleep 60
done
```

---

## 📚 Referências

- [AWS S3 Access Guide](./AWS-S3-ACCESS-GUIDE.md) - Guia detalhado sobre acesso S3
- [Hyperlane Documentation](https://docs.hyperlane.xyz/) - Documentação oficial
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/) - Documentação AWS CLI

---

## ✅ Checklist de Configuração

Antes de usar o script, certifique-se de ter:

- [ ] Arquivo `.env` configurado com:
  - [ ] `HYP_CHECKPOINT_SYNCER_BUCKET`
  - [ ] `AWS_ACCESS_KEY_ID` (para comando `list`)
  - [ ] `AWS_SECRET_ACCESS_KEY` (para comando `list`)
  - [ ] `AWS_REGION` ou `HYP_CHECKPOINT_SYNCER_REGION`
- [ ] AWS CLI instalado (opcional, apenas para `list`)
- [ ] Script com permissão de execução: `chmod +x query-validator-s3.sh`

---

## 🚀 Início Rápido

1. **Configure o `.env`:**
   ```bash
   cp env.example .env
   nano .env  # Edite com suas credenciais
   ```

2. **Teste a configuração:**
   ```bash
   ./query-validator-s3.sh config
   ```

3. **Liste os checkpoints:**
   ```bash
   ./query-validator-s3.sh list
   ```

4. **Consulte um checkpoint:**
   ```bash
   ./query-validator-s3.sh checkpoint 18
   ```

5. **Veja o announcement:**
   ```bash
   ./query-validator-s3.sh announcement
   ```

---

**Última atualização:** 2026-01-23
