# 📚 GUIA: Configuração de Blocos Iniciais

**Data de Criação**: 2026-01-29  
**Versão**: 1.0  
**Autor**: Hyperlane Validator Smart

---

## 🎯 OBJETIVO

Este guia explica como configurar os blocos iniciais (`index.from`) para todas as chains no Hyperlane Relayer, garantindo sincronização rápida e eficiente.

---

## 📋 ÍNDICE

1. [O que é `index.from`?](#o-que-é-indexfrom)
2. [Por que atualizar os blocos?](#por-que-atualizar-os-blocos)
3. [Como usar o script automatizado](#como-usar-o-script-automatizado)
4. [Configuração manual](#configuração-manual)
5. [Valores recomendados](#valores-recomendados)
6. [Troubleshooting](#troubleshooting)

---

## 🔍 O QUE É `index.from`?

O parâmetro `index.from` no arquivo `agent-config.docker-testnet.json` define o **bloco/slot inicial** a partir do qual o relayer começará a sincronizar cada blockchain.

### Estrutura no Config:

```json
{
  "chains": {
    "terraclassictestnet": {
      "index": {
        "from": 20731645,  // ← Bloco inicial
        "chunk": 10         // Blocos processados por vez
      }
    }
  }
}
```

---

## 💡 POR QUE ATUALIZAR OS BLOCOS?

### ✅ VANTAGENS de usar blocos recentes:

| Vantagem | Descrição |
|----------|-----------|
| 🚀 **Sincronização Rápida** | Não precisa indexar milhares de blocos antigos |
| 💰 **Economia de Recursos** | Menos uso de CPU, memória e banda |
| ⚡ **Início Rápido** | Relayer fica operacional em minutos |
| 🔄 **Menos Rate Limits** | Menos requests aos RPCs públicos |

### ⚠️ DESVANTAGENS de usar blocos antigos:

| Problema | Impacto |
|----------|---------|
| 🐌 **Sincronização Lenta** | Pode levar horas ou dias |
| 💾 **Alto Uso de Recursos** | Database grande, muito processamento |
| 🚫 **Rate Limits** | RPCs públicos bloqueiam por excesso de requests |
| ⏱️ **Timeout** | Relayer pode travar ou reiniciar |

---

## 🤖 COMO USAR O SCRIPT AUTOMATIZADO

### 1️⃣ Executar o Script

O script `atualizar-blocos-chains.sh` consulta automaticamente os blocos atuais de todas as chains e atualiza o arquivo de configuração.

```bash
cd /home/lunc/hyperlane-validator-smart
./atualizar-blocos-chains.sh
```

### 2️⃣ O que o script faz:

1. ✅ Consulta blocos atuais de todas as chains
2. ✅ Cria backup do arquivo de configuração
3. ✅ Atualiza `index.from` automaticamente
4. ✅ Exibe resumo das mudanças
5. ✅ Oferece reiniciar o relayer automaticamente

### 3️⃣ Exemplo de Saída:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔄 ATUALIZAÇÃO AUTOMÁTICA DE BLOCOS - TODAS AS CHAINS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  TERRA CLASSIC TESTNET
   Consultando RPC... ✅
   Bloco atual: 20731645

2️⃣  BSC TESTNET
   Consultando RPC... ✅
   Bloco atual: 87295507

3️⃣  SOLANA TESTNET
   Consultando RPC... ✅
   Slot atual: 384872978

4️⃣  SEPOLIA
   Consultando RPC... ✅
   Bloco atual: 10150017

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📊 RESUMO DOS BLOCOS CONSULTADOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Terra Classic Testnet: 20731645
✅ BSC Testnet:          87295507
✅ Solana Testnet:       384872978
✅ Sepolia:              10150017

🔄 Deseja reiniciar o relayer agora? (s/n):
```

---

## 🔧 CONFIGURAÇÃO MANUAL

### 1️⃣ Consultar Blocos Manualmente

#### Terra Classic Testnet:

```bash
curl -s https://terra-testnet-rpc.polkachu.com/status | \
  jq -r '.result.sync_info.latest_block_height'
```

#### BSC Testnet:

```bash
cast block-number --rpc-url https://bsc-testnet.drpc.org
```

Ou sem `cast`:
```bash
curl -s https://bsc-testnet.drpc.org -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  jq -r '.result' | xargs printf "%d\n"
```

#### Solana Testnet:

```bash
curl -s https://api.testnet.solana.com -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | \
  jq -r '.result'
```

#### Sepolia:

```bash
cast block-number --rpc-url https://1rpc.io/sepolia
```

### 2️⃣ Atualizar Manualmente com jq

```bash
cd /home/lunc/hyperlane-validator-smart

jq '.chains.terraclassictestnet.index.from = 20731645 |
    .chains.bsctestnet.index.from = 87295507 |
    .chains.solanatestnet.index.from = 384872978 |
    .chains.sepolia.index.from = 10150017' \
  hyperlane/agent-config.docker-testnet.json > /tmp/config-updated.json

mv /tmp/config-updated.json hyperlane/agent-config.docker-testnet.json
```

### 3️⃣ Reiniciar Relayer

```bash
docker-compose -f docker-compose-testnet.yml restart relayer
```

---

## 📊 VALORES RECOMENDADOS

### 🧪 Para Testnet (Configuração Atual):

| Chain | Recomendação | Motivo |
|-------|--------------|--------|
| **Terra Classic** | Bloco atual | Sincronização rápida para testes |
| **BSC** | Bloco atual | Evita rate limits em RPCs públicos |
| **Solana** | Slot atual | Slots mudam rapidamente em Solana |
| **Sepolia** | Bloco atual | Testnet com muita atividade |

### 🚀 Para Mainnet (Produção):

| Chain | Recomendação | Motivo |
|-------|--------------|--------|
| **Todas** | Bloco de deploy - 100 | Garante não perder mensagens importantes |

**Exemplo para Mainnet:**
```
Se o contrato foi deployado no bloco 1000000:
  → Configure index.from: 999900
```

---

## 🎯 QUANDO ATUALIZAR OS BLOCOS?

### ✅ DEVE atualizar quando:

1. **Primeira configuração**: Usar blocos atuais
2. **Relayer ficou offline por dias**: Atualizar para bloco recente
3. **Database foi resetado**: Começar do bloco atual
4. **Performance ruim**: Pular blocos antigos
5. **Novos deploys de contratos**: Usar bloco do deploy

### ❌ NÃO deve atualizar quando:

1. **Existem mensagens pendentes**: Você pode perdê-las
2. **Em produção sem backup**: Sempre faça backup primeiro
3. **Sem entender o impacto**: Pode perder dados importantes

---

## ⚙️ CONFIGURAÇÃO DETALHADA

### Estrutura Completa do `index`:

```json
{
  "chains": {
    "terraclassictestnet": {
      "index": {
        "from": 20731645,  // Bloco inicial
        "chunk": 10        // Blocos por requisição
      }
    }
  }
}
```

### Parâmetros:

| Parâmetro | Descrição | Valores Típicos |
|-----------|-----------|-----------------|
| `from` | Bloco/slot inicial | Bloco atual ou bloco de deploy |
| `chunk` | Blocos processados por vez | 10-100 (menor = mais preciso, maior = mais rápido) |

---

## 🔍 VERIFICAÇÃO

### Como verificar se está funcionando:

#### 1. Ver logs de sincronização:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep "estimated_time_to_sync"
```

**Saída esperada:**
```
estimated_time_to_sync: "synced"
```

#### 2. Verificar blocos sendo processados:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -E "at_block|sequence" | tail -10
```

#### 3. Verificar todas as chains:

```bash
docker logs hpl-relayer-testnet 2>&1 | \
  grep -E "(terraclassictestnet|bsctestnet|solanatestnet|sepolia)" | \
  grep "synced"
```

#### 4. Verificar rate limits (deve ser 0):

```bash
docker logs hpl-relayer-testnet --since 5m 2>&1 | grep -i "rate limit" | wc -l
```

---

## ⚠️ TROUBLESHOOTING

### Problema: Blocos não estão atualizando

**Sintomas:**
```
Current indexing snapshot's block height is less than or equal to the lowest block height
```

**Solução:**
```bash
# 1. Verificar se o config foi atualizado
cat hyperlane/agent-config.docker-testnet.json | jq '.chains.terraclassictestnet.index.from'

# 2. Reiniciar o relayer
docker-compose -f docker-compose-testnet.yml restart relayer

# 3. Se persistir, resetar database
docker-compose -f docker-compose-testnet.yml down
sudo rm -rf relayer-testnet/db/*
docker-compose -f docker-compose-testnet.yml up -d
```

### Problema: Rate limits continuam altos

**Sintomas:**
```
ERROR: rate limit exceeded
```

**Solução:**
```bash
# 1. Atualizar para blocos mais recentes
./atualizar-blocos-chains.sh

# 2. Verificar RPCs no config
cat hyperlane/agent-config.docker-testnet.json | jq '.chains.sepolia.rpcUrls'

# 3. Trocar RPCs se necessário
# Editar agent-config.docker-testnet.json
```

### Problema: "Failed to query RPC"

**Sintomas:**
```
❌ Falha ao consultar
⚠️  Usando valor padrão
```

**Solução:**
1. Verificar conectividade:
```bash
curl -s https://terra-testnet-rpc.polkachu.com/status
```

2. Testar RPC alternativo:
```bash
curl -s https://terra-testnet-rpc.publicnode.com/status
```

3. Usar valor manual se RPCs estiverem offline

### Problema: Relayer está lento

**Sintomas:**
- Sincronização leva horas
- `estimated_time_to_sync`: "2h 30m"

**Solução:**
```bash
# Pular para blocos recentes
./atualizar-blocos-chains.sh

# Ou aumentar o chunk size (processar mais blocos por vez)
jq '.chains.terraclassictestnet.index.chunk = 50' \
  hyperlane/agent-config.docker-testnet.json > /tmp/config.json
mv /tmp/config.json hyperlane/agent-config.docker-testnet.json

# Reiniciar
docker-compose -f docker-compose-testnet.yml restart relayer
```

---

## 📁 ARQUIVOS RELACIONADOS

| Arquivo | Descrição |
|---------|-----------|
| `atualizar-blocos-chains.sh` | **Script automatizado** para atualizar blocos |
| `hyperlane/agent-config.docker-testnet.json` | **Configuração principal** do relayer |
| `BLOCOS-ATUALIZADOS.md` | Documentação dos blocos atualizados |
| `GUIA-CONFIGURACAO-BLOCOS.md` | **Este guia** |

---

## 🎓 EXEMPLOS DE USO

### Exemplo 1: Nova instalação (Testnet)

```bash
# 1. Clonar repositório
git clone <repo>
cd hyperlane-validator-smart

# 2. Atualizar blocos para valores recentes
./atualizar-blocos-chains.sh

# 3. Configurar chaves privadas no .env
nano .env

# 4. Iniciar relayer
docker-compose -f docker-compose-testnet.yml up -d

# 5. Verificar sincronização
docker logs -f hpl-relayer-testnet
```

### Exemplo 2: Relayer ficou offline por 1 semana

```bash
# 1. Atualizar para blocos atuais (pular a semana offline)
./atualizar-blocos-chains.sh

# 2. Responder "s" para reiniciar automaticamente

# 3. Verificar que sincronizou rapidamente
docker logs hpl-relayer-testnet 2>&1 | grep "synced"
```

### Exemplo 3: Reset completo

```bash
# 1. Parar tudo
docker-compose -f docker-compose-testnet.yml down

# 2. Limpar database
sudo rm -rf relayer-testnet/db/*

# 3. Atualizar blocos
./atualizar-blocos-chains.sh

# 4. Reiniciar
docker-compose -f docker-compose-testnet.yml up -d
```

### Exemplo 4: Configuração para Mainnet

```bash
# 1. Consultar bloco de deploy dos contratos
# Exemplo: Mailbox deployado no bloco 1000000

# 2. Configurar 100 blocos antes
jq '.chains.terra.index.from = 999900' \
  hyperlane/agent-config.docker.json > /tmp/config.json

# 3. Aplicar
mv /tmp/config.json hyperlane/agent-config.docker.json

# 4. Verificar
cat hyperlane/agent-config.docker.json | jq '.chains.terra.index'
```

---

## 📊 VALORES HISTÓRICOS

### Valores em 2026-01-29:

| Chain | Bloco/Slot | Observação |
|-------|------------|------------|
| Terra Classic | 20731645 | Bloco |
| BSC Testnet | 87295507 | Bloco |
| Solana Testnet | 384872978 | Slot (muda rapidamente) |
| Sepolia | 10150017 | Bloco |

**📝 Nota**: Para consultar valores atualizados, execute:
```bash
./atualizar-blocos-chains.sh
```

---

## 🔐 BOAS PRÁTICAS

### ✅ SEMPRE:

1. **Fazer backup** antes de alterar configs
2. **Testar em testnet** antes de mainnet
3. **Documentar** os blocos escolhidos e o motivo
4. **Monitorar** os logs após mudanças
5. **Usar o script automatizado** quando possível

### ❌ NUNCA:

1. **Alterar em produção** sem entender o impacto
2. **Usar bloco 0 ou 1** sem necessidade
3. **Ignorar rate limits** dos RPCs
4. **Esquecer de reiniciar** após mudanças

---

## 🆘 SUPORTE

### Comandos Úteis:

```bash
# Ver configuração atual
cat hyperlane/agent-config.docker-testnet.json | jq '.chains | to_entries[] | {chain: .key, from: .value.index.from}'

# Backup manual
cp hyperlane/agent-config.docker-testnet.json \
   hyperlane/agent-config.docker-testnet.json.backup.$(date +%Y%m%d_%H%M%S)

# Restaurar backup
cp hyperlane/agent-config.docker-testnet.json.backup.YYYYMMDD_HHMMSS \
   hyperlane/agent-config.docker-testnet.json

# Ver todos os backups
ls -lth hyperlane/agent-config.docker-testnet.json.backup.*

# Logs completos
docker logs hpl-relayer-testnet > relayer-logs-$(date +%Y%m%d_%H%M%S).txt

# Status resumido
docker logs hpl-relayer-testnet --tail 100 2>&1 | grep -E "(synced|ERROR|WARN)"
```

---

## 📚 RECURSOS ADICIONAIS

### Documentação Oficial:

- [Hyperlane Docs](https://docs.hyperlane.xyz/)
- [Relayer Configuration](https://docs.hyperlane.xyz/docs/operate/relayer/configuration)

### Block Explorers:

- **Terra Classic Testnet**: https://finder.terra.money/testnet
- **BSC Testnet**: https://testnet.bscscan.com/
- **Solana Testnet**: https://explorer.solana.com/?cluster=testnet
- **Sepolia**: https://sepolia.etherscan.io/

### RPCs Públicos:

- **Terra Classic**: https://terra-testnet-rpc.polkachu.com
- **BSC**: https://bsc-testnet.drpc.org
- **Solana**: https://api.testnet.solana.com
- **Sepolia**: https://1rpc.io/sepolia

---

## 📝 CHANGELOG

| Data | Versão | Mudanças |
|------|--------|----------|
| 2026-01-29 | 1.0 | Criação inicial do guia |

---

## ✅ CHECKLIST DE CONFIGURAÇÃO

Use este checklist ao configurar blocos para um novo relayer:

- [ ] Script `atualizar-blocos-chains.sh` tem permissão de execução (`chmod +x`)
- [ ] Executar script: `./atualizar-blocos-chains.sh`
- [ ] Verificar blocos consultados no resumo
- [ ] Confirmar backup foi criado
- [ ] Verificar valores atualizados no config
- [ ] Reiniciar relayer
- [ ] Verificar logs: `docker logs hpl-relayer-testnet`
- [ ] Confirmar todas as chains estão "synced"
- [ ] Verificar rate limits estão baixos (0-5 por minuto)
- [ ] Testar envio de mensagem em cada rota
- [ ] Documentar configuração final

---

**🎉 GUIA COMPLETO!**

Este guia cobre todos os aspectos da configuração de blocos iniciais para o Hyperlane Relayer. Para novos agentes ou desenvolvedores, basta seguir este documento passo a passo para garantir uma configuração otimizada e eficiente.

---

**Autor**: Hyperlane Validator Smart  
**Última Atualização**: 2026-01-29  
**Versão do Hyperlane**: Latest (Testnet)
