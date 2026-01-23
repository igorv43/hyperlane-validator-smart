# 🔍 Teste Local do Relayer - Diagnóstico

Este diretório contém arquivos para testar apenas o relayer localmente e diagnosticar por que as mensagens não estão sendo enviadas do Terra Classic para o BSC.

## 📋 Estrutura

```
teste-relayer/
├── docker-compose-relayer-only.yml  # Docker Compose apenas para o relayer
├── diagnostico.sh                    # Script de diagnóstico completo
├── README.md                        # Este arquivo
└── relayer-data/                    # Dados do relayer (criado automaticamente)
```

## 🚀 Como Usar

### 1. Preparar Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto ou exporte as variáveis:

```bash
export AWS_ACCESS_KEY_ID="sua_access_key"
export AWS_SECRET_ACCESS_KEY="sua_secret_key"
export AWS_REGION="us-east-1"
export HYP_CHAINS_BSCTESTNET_SIGNER_KEY="0x..."
export HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY="0x..."
```

### 2. Iniciar o Relayer

```bash
cd teste-relayer
docker-compose -f docker-compose-relayer-only.yml up -d
```

### 3. Verificar Logs

```bash
docker logs -f hpl-relayer-testnet-local
```

### 4. Executar Diagnóstico

**Do host:**
```bash
cd teste-relayer
./diagnostico.sh
```

**Dentro do container:**
```bash
docker exec -it hpl-relayer-testnet-local bash
cd /app
bash /etc/hyperlane/../diagnostico.sh
```

Ou execute os comandos manualmente:
```bash
# Health check
curl http://localhost:9090/health | jq '.'

# Validators
curl http://localhost:9090/validators | jq '.["1325"]'

# Checkpoints
curl http://localhost:9090/checkpoints/1325 | jq '.'

# Sync status
curl http://localhost:9090/sync/1325 | jq '.'

# Pool
curl http://localhost:9090/pool | jq '.'
```

## 🔍 O Que Verificar

### 1. Validators Descobertos

O relayer precisa descobrir validators através do contrato ValidatorAnnounce.

**Verificar:**
```bash
curl http://localhost:9090/validators | jq '.["1325"]'
```

**Se vazio:**
- Validator pode não ter anunciado
- Relayer não está consultando ValidatorAnnounce
- Verificar logs por "Discovering validators"

### 2. Checkpoints Lidos

O relayer precisa ler checkpoints do S3.

**Verificar:**
```bash
curl http://localhost:9090/checkpoints/1325 | jq '.lastCheckpoint'
```

**Se vazio:**
- Problema com credenciais AWS
- Permissões do IAM user insuficientes
- Bucket não acessível

### 3. Status de Sincronização

O relayer precisa sincronizar mensagens do Terra Classic.

**Verificar:**
```bash
curl http://localhost:9090/sync/1325 | jq '.'
```

**Se não aparecer:**
- Relayer não está sincronizando Terra Classic
- Verificar `relayChains` no `relayer.testnet.json`
- Verificar configuração do Terra Classic

### 4. Pool de Mensagens

Mensagens prontas para serem enviadas.

**Verificar:**
```bash
curl http://localhost:9090/pool | jq '.size'
```

**Se size: 0:**
- Pode ser normal se não houver mensagens
- Verificar se há mensagens sendo enviadas do Terra Classic
- Verificar se o validator está gerando checkpoints

## 🚨 Problemas Comuns

### Problema 1: Validators Não Descobertos

**Sintoma:** `curl http://localhost:9090/validators | jq '.["1325"]'` retorna `null`

**Solução:**
- Verificar se o validator anunciou: `./query-validator-s3.sh announcement`
- Verificar logs do relayer por "Discovering validators"
- Verificar se o contrato ValidatorAnnounce está acessível

### Problema 2: Checkpoints Não Lidos

**Sintoma:** `curl http://localhost:9090/checkpoints/1325 | jq '.lastCheckpoint'` retorna `null`

**Solução:**
- Verificar variáveis de ambiente AWS
- Testar acesso ao S3: `aws s3 ls s3://bucket/`
- Verificar permissões do IAM user (precisa de `s3:GetObject`)

### Problema 3: Pool Vazio

**Sintoma:** `curl http://localhost:9090/pool | jq '.size'` retorna `0`

**Solução:**
- Verificar se há mensagens sendo enviadas do Terra Classic
- Verificar se o validator está gerando checkpoints
- Verificar status de sincronização

### Problema 4: Relayer Não Sincroniza Terra Classic

**Sintoma:** `curl http://localhost:9090/sync/1325` retorna erro ou `null`

**Solução:**
- Verificar `relayChains` no `relayer.testnet.json`
- Verificar configuração do Terra Classic no `agent-config.docker-testnet.json`
- Verificar logs do relayer

## 📊 Comandos Úteis

### Verificar Logs em Tempo Real

```bash
docker logs -f hpl-relayer-testnet-local
```

### Procurar por Erros nos Logs

```bash
docker logs hpl-relayer-testnet-local 2>&1 | grep -i "error\|failed\|panic"
```

### Procurar por Checkpoints nos Logs

```bash
docker logs hpl-relayer-testnet-local 2>&1 | grep -i "checkpoint"
```

### Procurar por Terra Classic nos Logs

```bash
docker logs hpl-relayer-testnet-local 2>&1 | grep -i "terraclassic\|1325"
```

### Acessar o Container

```bash
docker exec -it hpl-relayer-testnet-local sh
```

### Parar o Relayer

```bash
docker-compose -f docker-compose-relayer-only.yml down
```

### Limpar Dados (Reset Database)

```bash
docker-compose -f docker-compose-relayer-only.yml down -v
rm -rf relayer-data
```

## 🎯 Checklist de Diagnóstico

Execute o script `diagnostico.sh` e verifique:

- [ ] Relayer está respondendo (health check)
- [ ] Validators do Terra Classic foram descobertos
- [ ] Checkpoints estão sendo lidos do S3
- [ ] Status de sincronização mostra `synced: true`
- [ ] Pool de mensagens mostra mensagens (ou `size: 0` se não houver)
- [ ] Credenciais AWS estão configuradas
- [ ] Acesso ao S3 funciona
- [ ] `relayChains` inclui `terraclassictestnet`
- [ ] `allowLocalCheckpointSyncers` é `false`
- [ ] Logs não mostram erros críticos

## 📝 Notas

- O relayer usa os mesmos arquivos de configuração do projeto principal (`../hyperlane/`)
- Os dados do relayer são armazenados em `relayer-data/`
- A API do relayer está disponível em `http://localhost:19010`
- Dentro do container, a API está em `http://localhost:9090`

## 🔗 Referências

- Documentação do Hyperlane: https://docs.hyperlane.xyz
- Guia de troubleshooting: Ver logs do relayer e este README

---

**Última atualização**: 2026-01-23
