# Guia: Resetar Containers do Relayer e Validator

Este documento explica como apagar e reiniciar os containers do relayer e validator usando o arquivo `.env` para configuração.

---

## 📋 Pré-requisitos

1. **Arquivo `.env` configurado** na raiz do projeto (`/home/lunc/hyperlane-validator-smart/.env`)
2. **Docker e Docker Compose** instalados e funcionando
3. **Acesso ao terminal** no servidor onde os containers estão rodando

---

## 🔄 Processo de Reset Completo

### 1️⃣ Parar e Remover os Containers

Execute o seguinte comando para parar e remover os containers, volumes e redes:

```bash
cd /home/lunc/hyperlane-validator-smart
docker compose -f docker-compose-testnet.yml down -v
```

**O que este comando faz:**
- Para os containers `hpl-relayer-testnet` e `hpl-validator-terraclassic-testnet`
- Remove os containers
- Remove os volumes (incluindo os databases)
- Remove as redes criadas

**⚠️ ATENÇÃO:** O parâmetro `-v` remove os volumes, o que significa que **todos os dados dos databases serão perdidos**. Se você quiser manter os databases, remova o `-v`:

```bash
docker compose -f docker-compose-testnet.yml down
```

---

### 2️⃣ Verificar se os Containers Foram Removidos

Para confirmar que os containers foram removidos:

```bash
docker ps -a | grep -E "hpl-relayer-testnet|hpl-validator-terraclassic-testnet"
```

Se não houver saída, os containers foram removidos com sucesso.

---

### 3️⃣ Verificar o Arquivo `.env`

Antes de reiniciar, verifique se o arquivo `.env` está configurado corretamente:

```bash
cd /home/lunc/hyperlane-validator-smart
cat .env | grep -E "AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|HYP_CHAINS|HYP_VALIDATOR_KEY|HYP_CHECKPOINT_SYNCER_BUCKET"
```

**Variáveis necessárias para o Relayer:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `HYP_DB` (opcional, padrão: `/etc/data/db`)
- `HYP_CHAINS_BSCTESTNET_SIGNER_KEY`
- `HYP_CHAINS_SOLANATESTNET_SIGNER_KEY`
- `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY`

**Variáveis adicionais para o Validator:**
- `HYP_VALIDATOR_KEY`
- `HYP_CHECKPOINT_SYNCER_BUCKET`
- `HYP_CHECKPOINT_SYNCER_REGION` (opcional)

---

### 4️⃣ Reiniciar os Containers

Para reiniciar os containers usando o arquivo `.env`:

```bash
cd /home/lunc/hyperlane-validator-smart
docker compose -f docker-compose-testnet.yml --env-file .env up -d
```

**O que este comando faz:**
- Carrega as variáveis de ambiente do arquivo `.env`
- Cria e inicia os containers em modo detached (`-d`)
- Aplica as configurações dinamicamente (substitui chaves no `relayer.testnet.json`)

---

### 5️⃣ Verificar se os Containers Estão Rodando

Para verificar o status dos containers:

```bash
docker ps | grep -E "hpl-relayer-testnet|hpl-validator-terraclassic-testnet"
```

Você deve ver ambos os containers com status `Up`.

---

### 6️⃣ Verificar os Logs

Para monitorar os logs dos containers:

**Relayer:**
```bash
docker logs -f hpl-relayer-testnet
```

**Validator:**
```bash
docker logs -f hpl-validator-terraclassic-testnet
```

**Logs de ambos (últimas 100 linhas):**
```bash
docker logs --tail 100 hpl-relayer-testnet
docker logs --tail 100 hpl-validator-terraclassic-testnet
```

---

## 🔍 Verificações Pós-Reinicialização

### Verificar se as Chaves Foram Substituídas Corretamente

**Relayer:**
```bash
docker exec hpl-relayer-testnet sh -c 'cat /etc/hyperlane/relayer.testnet.json | grep -A 3 "terraclassictestnet"'
```

Você deve ver a chave real (não `0xYOUR_PRIVATE_KEY_HERE`).

**Validator:**
```bash
docker exec hpl-validator-terraclassic-testnet sh -c 'cat /etc/hyperlane/validator.terraclassic-testnet.json | grep -A 2 "validator"'
```

---

### Verificar Sincronização

**Relayer - Status de Sincronização:**
```bash
docker logs hpl-relayer-testnet | grep -iE "terraclassic.*1325|sequence|synced" | tail -n 20
```

**Validator - Geração de Checkpoints:**
```bash
docker logs hpl-validator-terraclassic-testnet | grep -iE "checkpoint|s3|bucket" | tail -n 20
```

---

## 🚨 Problemas Comuns e Soluções

### Problema 1: Variáveis de Ambiente Não Carregadas

**Sintoma:** Containers iniciam mas mostram erros de variáveis não definidas.

**Solução:**
1. Verifique se o arquivo `.env` existe na raiz do projeto
2. Verifique se o caminho está correto: `--env-file .env`
3. Verifique se as variáveis estão definidas no `.env` sem espaços extras

### Problema 2: Chaves Não Foram Substituídas

**Sintoma:** Logs mostram erros como `HexKey { key: 0xYOUR_PRIVATE_KEY_HERE }`.

**Solução:**
1. Verifique se o arquivo `relayer.testnet.json` tem os placeholders `0xYOUR_PRIVATE_KEY_HERE`
2. Verifique se as variáveis de ambiente estão definidas no `.env`
3. Verifique os logs do container para ver se os comandos `sed` foram executados

### Problema 3: Container Não Inicia

**Sintoma:** Container para imediatamente após iniciar.

**Solução:**
1. Verifique os logs: `docker logs hpl-relayer-testnet` ou `docker logs hpl-validator-terraclassic-testnet`
2. Verifique se todas as variáveis obrigatórias estão definidas
3. Verifique se há erros de sintaxe no `docker-compose-testnet.yml`

---

## 📝 Comandos Rápidos de Referência

```bash
# Parar e remover containers (mantendo volumes)
docker compose -f docker-compose-testnet.yml down

# Parar e remover containers (removendo volumes/databases)
docker compose -f docker-compose-testnet.yml down -v

# Iniciar containers com .env
docker compose -f docker-compose-testnet.yml --env-file .env up -d

# Ver logs em tempo real
docker logs -f hpl-relayer-testnet
docker logs -f hpl-validator-terraclassic-testnet

# Parar containers (sem remover)
docker compose -f docker-compose-testnet.yml stop

# Reiniciar containers (sem remover)
docker compose -f docker-compose-testnet.yml restart

# Ver status dos containers
docker ps | grep -E "hpl-relayer-testnet|hpl-validator-terraclassic-testnet"
```

---

## 🔐 Segurança

**⚠️ IMPORTANTE:** O arquivo `.env` contém informações sensíveis (chaves privadas, credenciais AWS). 

- **NUNCA** commite o arquivo `.env` no controle de versão (Git)
- **NUNCA** compartilhe o arquivo `.env` publicamente
- Use `.gitignore` para garantir que o `.env` não seja commitado
- Mantenha backups seguros do arquivo `.env` em local seguro

---

## 📋 Checklist de Reset

Antes de fazer o reset, certifique-se de:

- [ ] Arquivo `.env` está configurado com todas as variáveis necessárias
- [ ] Você tem backup dos dados importantes (se necessário)
- [ ] Você está no diretório correto (`/home/lunc/hyperlane-validator-smart`)
- [ ] Docker está rodando e acessível
- [ ] Você tem permissões para executar comandos Docker

Após o reset, verifique:

- [ ] Containers estão rodando (`docker ps`)
- [ ] Logs não mostram erros críticos
- [ ] Chaves foram substituídas corretamente
- [ ] Relayer está sincronizando
- [ ] Validator está gerando checkpoints

---

**Última atualização:** 2026-01-23
