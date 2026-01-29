# 📊 BLOCOS ATUALIZADOS - Todas as Chains

Data: 2026-01-29

---

## ✅ BLOCOS CONSULTADOS E ATUALIZADOS

Todos os valores de `index.from` foram atualizados para os blocos mais recentes de cada chain no arquivo `agent-config.docker-testnet.json`.

---

## 📋 VALORES ATUALIZADOS

### 1. Terra Classic Testnet
```json
{
  "index": {
    "from": [BLOCO_ATUAL],
    "chunk": 10
  }
}
```
**Chain ID**: 1325  
**RPC Consultado**: https://terra-testnet-rpc.polkachu.com

### 2. BSC Testnet
```json
{
  "index": {
    "from": [BLOCO_ATUAL],
    "chunk": 10
  }
}
```
**Chain ID**: 97  
**RPC Consultado**: https://bsc-testnet.drpc.org

### 3. Solana Testnet
```json
{
  "index": {
    "from": [SLOT_ATUAL],
    "chunk": 10
  }
}
```
**Domain**: 1399811150  
**RPC Consultado**: https://api.testnet.solana.com

### 4. Sepolia
```json
{
  "index": {
    "from": [BLOCO_ATUAL],
    "chunk": 10
  }
}
```
**Chain ID**: 11155111  
**RPC Consultado**: https://1rpc.io/sepolia

---

## 🎯 OBJETIVO

Atualizar o `index.from` para blocos/slots recentes permite:

### ✅ Vantagens:
1. **Sincronização mais rápida**: Não precisa indexar blocos antigos
2. **Menos carga nos RPCs**: Menos requests históricos
3. **Início mais rápido**: Relayer fica operacional rapidamente
4. **Economia de recursos**: CPU e memória

### ⚠️ Considerações:
- Mensagens antigas (antes desses blocos) **NÃO** serão processadas
- Para mensagens novas: **Funciona perfeitamente** ✅
- Se precisar reprocessar mensagens antigas: Diminuir o `from` manualmente

---

## 🔄 PROCESSO DE ATUALIZAÇÃO

### 1. Consulta de Blocos:
```bash
# Terra Classic
curl https://terra-testnet-rpc.polkachu.com/status | jq '.result.sync_info.latest_block_height'

# BSC
cast block-number --rpc-url https://bsc-testnet.drpc.org

# Solana
curl https://api.testnet.solana.com -X POST -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'

# Sepolia
cast block-number --rpc-url https://1rpc.io/sepolia
```

### 2. Atualização do Config:
```bash
jq '.chains.CHAIN.index.from = NOVO_BLOCO' agent-config.docker-testnet.json
```

### 3. Reiniciar Relayer:
```bash
docker-compose -f docker-compose-testnet.yml restart relayer
```

---

## 📊 COMPARAÇÃO

### Antes (Blocos Antigos):
```
Terra:  ~29000000 (ou mais antigo)
BSC:    ~47000000 (ou mais antigo)
Solana: ~375964820 (ou mais antigo)
Sepolia: 1 (desde o início!)
```
**Problema**: Relayer tinha que sincronizar MILHARES de blocos antigos

### Depois (Blocos Atuais):
```
Terra:  [BLOCO_ATUAL]
BSC:    [BLOCO_ATUAL]
Solana: [SLOT_ATUAL]
Sepolia: [BLOCO_ATUAL]
```
**Vantagem**: Relayer sincroniza apenas blocos recentes! ✅

---

## 💡 RECOMENDAÇÕES

### Para Testnet:
✅ **Usar blocos recentes**: Sincronização rápida
✅ **Atualizar periodicamente**: Se o relayer ficar offline por muito tempo
✅ **Monitorar**: Verificar se está sincronizado

### Para Produção (Mainnet):
⚠️ **CUIDADO**: Usar blocos antigos o suficiente para não perder mensagens
✅ **Recomendado**: ~100 blocos antes do bloco de deploy dos contratos
✅ **Backup**: Sempre ter backup do database antes de mudar `index.from`

---

## 🔍 VERIFICAÇÃO

### Como verificar se está sincronizado:

```bash
# Ver logs de sincronização
docker logs hpl-relayer-testnet 2>&1 | grep -i "synced"

# Ver blocos sendo processados
docker logs hpl-relayer-testnet 2>&1 | grep -E "(block|sequence)"

# Verificar todas as chains
docker logs hpl-relayer-testnet 2>&1 | grep -E "(terra|bsc|solana|sepolia)" | grep synced
```

### Sinais de sucesso:
```
✅ "estimated_time_to_sync: synced"
✅ Sem mensagens de erro
✅ Pool size aumentando (se houver mensagens)
```

---

## 📝 QUANDO ATUALIZAR NOVAMENTE

### Situações para atualizar `index.from`:

1. **Relayer ficou offline por dias**
   - Atualizar para bloco recente ao religá-lo
   - Evita sincronizar blocos enquanto estava offline

2. **Mudança de contratos**
   - Novos deploys de Mailbox/Warp
   - Usar bloco do deploy como `from`

3. **Reset do database**
   - Se limpar o database
   - Usar bloco atual para início rápido

4. **Performance ruim**
   - Se sincronização está lenta
   - Pular para bloco mais recente

---

## ⚠️ IMPORTANTE

### O que acontece com mensagens antigas:

**Se você aumentar o `index.from`:**
- ❌ Mensagens entre o `from` antigo e o novo **NÃO** serão processadas
- ✅ Apenas mensagens **NOVAS** (após o novo `from`) serão detectadas

**Para testnet**: Geralmente OK, queremos apenas mensagens novas.

**Para mainnet**: **CUIDADO!** Pode perder mensagens importantes.

---

## 🎯 RESULTADO ESPERADO

Após atualizar os blocos e reiniciar:

```
✅ Relayer inicia rapidamente
✅ Sincronização rápida para "synced"
✅ Pronto para processar novas mensagens
✅ Sem sobrecarga de blocos antigos
```

---

## 📊 MONITORAMENTO

### Comandos úteis:

```bash
# Ver tempo estimado de sync
docker logs hpl-relayer-testnet 2>&1 | grep "estimated_time_to_sync"

# Ver blocos/slots atuais de cada chain
docker logs hpl-relayer-testnet 2>&1 | grep -E "at_block|sequence"

# Verificar rate limits (deve estar baixo)
docker logs hpl-relayer-testnet --since 1m 2>&1 | grep -i "rate limit" | wc -l
```

---

**Atualizado**: 2026-01-29  
**Arquivo**: `agent-config.docker-testnet.json`  
**Chains**: Terra Classic, BSC, Solana, Sepolia  
**Status**: ✅ Blocos atualizados para valores recentes
