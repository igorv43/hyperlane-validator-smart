# Guia de Acesso aos Arquivos do Validator no AWS S3

Este documento explica como acessar e consultar os arquivos públicos do validator armazenados no bucket S3 da AWS.

## 📋 Índice

1. [Estrutura dos Arquivos no S3](#estrutura-dos-arquivos-no-s3)
2. [Acessando Arquivos via URL](#acessando-arquivos-via-url)
3. [Tipos de Arquivos](#tipos-de-arquivos)
4. [Scripts de Consulta](#scripts-de-consulta)
5. [Exemplos Práticos](#exemplos-práticos)

---

## 📁 Estrutura dos Arquivos no S3

O Hyperlane validator armazena os seguintes tipos de arquivos no bucket S3:

```
s3://seu-bucket-name/
├── checkpoints/
│   ├── {domain-id}/
│   │   ├── {checkpoint-index}.json
│   │   └── ...
│   └── ...
└── announcements/
    └── {validator-address}.json
```

### Estrutura Detalhada

#### Checkpoints
- **Caminho**: `checkpoints/{domain-id}/{checkpoint-index}.json`
- **Exemplo**: `checkpoints/1325/28563839.json`
- **Conteúdo**: Checkpoint assinado pelo validator para um determinado índice de bloco

#### Announcements
- **Caminho**: `announcements/{validator-address}.json`
- **Exemplo**: `announcements/0x1234...abcd.json`
- **Conteúdo**: Informações de anúncio do validator (endereço, assinatura, etc.)

---

## 🌐 Acessando Arquivos via URL

### Formato da URL

Para acessar arquivos públicos no S3, use o seguinte formato:

```
https://{bucket-name}.s3.{region}.amazonaws.com/{caminho-do-arquivo}
```

ou

```
https://s3.{region}.amazonaws.com/{bucket-name}/{caminho-do-arquivo}
```

### Exemplo Real

Se seu bucket é `hyperlane-validator-signatures-igorverasvalidador-terraclassic` na região `us-east-1`:

**Checkpoint:**
```
https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/checkpoints/1325/28563839.json
```

**Announcement:**
```
https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/announcements/0x1234...abcd.json
```

---

## 📄 Tipos de Arquivos

### 1. Checkpoint JSON

Estrutura típica de um checkpoint:

```json
{
  "value": {
    "root": "0x...",
    "index": 28563839,
    "mailbox_domain": 1325
  },
  "signature": "0x...",
  "checkpoint_type": "merkle_root"
}
```

**Informações importantes:**
- `index`: Número do bloco do checkpoint
- `mailbox_domain`: Domain ID da chain (1325 = Terra Classic Testnet)
- `root`: Merkle root do checkpoint
- `signature`: Assinatura do validator

### 2. Announcement JSON

Estrutura típica de um announcement:

```json
{
  "validator": "0x...",
  "storage_location": "s3://bucket-name/checkpoints",
  "signature": "0x...",
  "announcement_type": "s3"
}
```

**Informações importantes:**
- `validator`: Endereço do validator
- `storage_location`: Localização do storage (S3 bucket)
- `signature`: Assinatura do announcement

---

## 🔧 Scripts de Consulta

### Script Principal: `query-validator-s3.sh`

Use o script `query-validator-s3.sh` para facilitar o acesso aos arquivos. Veja a seção [Scripts de Consulta](#scripts-de-consulta) abaixo.

---

## 💡 Exemplos Práticos

### 1. Acessar Checkpoint Específico

**Via cURL:**
```bash
curl https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/checkpoints/1325/28563839.json
```

**Via wget:**
```bash
wget https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/checkpoints/1325/28563839.json
```

### 2. Listar Todos os Checkpoints de um Domain

**Via AWS CLI:**
```bash
aws s3 ls s3://hyperlane-validator-signatures-igorverasvalidador-terraclassic/checkpoints/1325/ --recursive
```

### 3. Baixar Announcement do Validator

**Via cURL:**
```bash
curl https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/announcements/0x1234...abcd.json
```

### 4. Verificar se Arquivo Existe

**Via cURL:**
```bash
curl -I https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/checkpoints/1325/28563839.json
```

Se retornar `200 OK`, o arquivo existe e está acessível.

---

## 🔍 Encontrando Informações do Seu Validator

### 1. Bucket Name

O nome do bucket está configurado na variável de ambiente:
```bash
echo $HYP_CHECKPOINT_SYNCER_BUCKET
```

Ou no arquivo de configuração do validator:
```bash
cat hyperlane/validator.terraclassic-testnet.json | jq '.checkpointSyncer.bucket'
```

### 2. Region

A região está configurada em:
```bash
echo $HYP_CHECKPOINT_SYNCER_REGION
# ou
echo $AWS_REGION
```

Ou no arquivo de configuração:
```bash
cat hyperlane/validator.terraclassic-testnet.json | jq '.checkpointSyncer.region'
```

### 3. Domain ID

Para Terra Classic Testnet: `1325`

Outros domains:
- BSC Testnet: `97`
- Solana Testnet: `1399811150`

### 4. Validator Address

O endereço do validator pode ser encontrado no announcement ou calculado a partir da chave privada.

---

## 📊 Verificando Acessibilidade Pública

### Teste de Acesso Público

```bash
# Substitua pelos seus valores
BUCKET="seu-bucket-name"
REGION="us-east-1"
DOMAIN="1325"
CHECKPOINT_INDEX="28563839"

URL="https://${BUCKET}.s3.${REGION}.amazonaws.com/checkpoints/${DOMAIN}/${CHECKPOINT_INDEX}.json"

curl -I "$URL"
```

**Respostas esperadas:**
- `200 OK`: Arquivo existe e está acessível
- `403 Forbidden`: Arquivo existe mas não está público (precisa configurar política do bucket)
- `404 Not Found`: Arquivo não existe

---

## ⚙️ Configurando Acesso Público (se necessário)

Se os arquivos não estiverem acessíveis publicamente, você precisa configurar a política do bucket S3.

### Política de Bucket para Leitura Pública

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::seu-bucket-name/*"
    }
  ]
}
```

**⚠️ ATENÇÃO:** Esta política torna todos os arquivos do bucket públicos. Use apenas se necessário para o funcionamento do Hyperlane.

---

## 🛠️ Troubleshooting

### Problema: 403 Forbidden

**Causa:** Bucket ou arquivo não está configurado como público.

**Solução:**
1. Verifique a política do bucket
2. Verifique as ACLs (Access Control Lists)
3. Verifique se o Block Public Access está desabilitado

### Problema: 404 Not Found

**Causa:** Arquivo não existe ou caminho incorreto.

**Solução:**
1. Verifique o caminho do arquivo
2. Liste os arquivos no bucket usando AWS CLI
3. Verifique se o validator está gerando os checkpoints

### Problema: URL não funciona

**Causa:** Formato da URL incorreto ou região errada.

**Solução:**
1. Verifique o formato da URL
2. Tente ambos os formatos de URL mencionados acima
3. Verifique a região do bucket

---

## 📚 Referências

- [AWS S3 Public Access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteAccessPermissionsReqd.html)
- [Hyperlane Validator Documentation](https://docs.hyperlane.xyz/)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)

---

## 🔗 Links Úteis

- **AWS Console**: https://console.aws.amazon.com/s3/
- **Hyperlane Explorer**: https://explorer.hyperlane.xyz/
- **Terra Classic Testnet Explorer**: https://finder.terraclassic.community/testnet

---

**Última atualização:** 2026-01-23
