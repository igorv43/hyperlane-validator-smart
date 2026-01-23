# 🔍 Resultado Final do Diagnóstico do Relayer

## ✅ Status do Container

- ✅ Container está rodando (Up)
- ✅ Relayer iniciou com sucesso
- ✅ Variáveis de ambiente carregadas do `.env`
- ⚠️ API não responde na porta 19010 (pode estar iniciando ainda)

## 📊 Logs Observados

### BSC Testnet
- ✅ Relayer está sincronizando BSC (bsctestnet)
- ✅ Processando blocos: 86143023-86143053
- ✅ Status: "synced"
- ✅ Pool size: 0 (normal se não houver mensagens)

### Terra Classic
- ⚠️ **Nenhum log do Terra Classic encontrado**
- ⚠️ Não há logs de sincronização do Terra Classic
- ⚠️ Não há logs de descoberta de validators do Terra Classic

## 🔍 Diagnóstico da API

Execute dentro do container para verificar:

```bash
docker exec -it hpl-relayer-testnet-local sh

# Dentro do container:
curl http://localhost:9090/health
curl http://localhost:9090/validators | jq '.["1325"]'
curl http://localhost:9090/checkpoints/1325 | jq '.'
curl http://localhost:9090/sync/1325 | jq '.'
curl http://localhost:9090/pool | jq '.size'
```

## 🚨 Problema Identificado

### Relayer Não Está Sincronizando Terra Classic

**Evidências:**
- Nenhum log do Terra Classic nos logs do relayer
- Apenas logs do BSC aparecem
- Pool size: 0 (pode ser normal se não houver mensagens)

**Possíveis Causas:**

1. **Relayer não descobriu validators do Terra Classic**
   - Verificar se o validator anunciou
   - Verificar se o relayer está consultando ValidatorAnnounce

2. **Relayer não está lendo checkpoints do S3**
   - Verificar credenciais AWS
   - Verificar permissões do IAM user
   - Verificar se o bucket está acessível

3. **Configuração do Terra Classic incorreta**
   - Verificar `relayChains` no `relayer.testnet.json`
   - Verificar configuração do Terra Classic no `agent-config.docker-testnet.json`

## 🔧 Próximos Passos

### 1. Verificar Validators Descobertos

```bash
docker exec hpl-relayer-testnet-local curl -s http://localhost:9090/validators | jq '.["1325"]'
```

**Se retornar `null` ou `[]`:**
- Validator pode não ter anunciado
- Relayer não está consultando ValidatorAnnounce
- Verificar logs por "Discovering validators"

### 2. Verificar Checkpoints Lidos

```bash
docker exec hpl-relayer-testnet-local curl -s http://localhost:9090/checkpoints/1325 | jq '.lastCheckpoint'
```

**Se retornar `null`:**
- Problema com credenciais AWS
- Permissões do IAM user insuficientes
- Bucket não acessível

### 3. Verificar Status de Sincronização

```bash
docker exec hpl-relayer-testnet-local curl -s http://localhost:9090/sync/1325 | jq '.'
```

**Se não aparecer domain 1325:**
- Relayer não está sincronizando Terra Classic
- Verificar `relayChains` no `relayer.testnet.json`
- Verificar configuração do Terra Classic

### 4. Verificar Logs do Relayer

```bash
docker logs -f hpl-relayer-testnet-local | grep -i "terraclassic\|1325\|checkpoint\|validator"
```

## 📋 Checklist de Verificação

- [ ] Container está rodando
- [ ] Variáveis de ambiente carregadas
- [ ] API do relayer responde (dentro do container)
- [ ] Validators do Terra Classic foram descobertos
- [ ] Checkpoints estão sendo lidos do S3
- [ ] Status de sincronização mostra Terra Classic
- [ ] Logs mostram sincronização do Terra Classic

## 🎯 Comandos de Diagnóstico Completo

Execute este script dentro do container:

```bash
docker exec -it hpl-relayer-testnet-local sh

# Dentro do container:
echo "=== VALIDATORS ===" && \
curl -s http://localhost:9090/validators | jq '.["1325"]' && \
echo "" && \
echo "=== CHECKPOINTS ===" && \
curl -s http://localhost:9090/checkpoints/1325 | jq '.lastCheckpoint' && \
echo "" && \
echo "=== SYNC STATUS ===" && \
curl -s http://localhost:9090/sync/1325 | jq '{synced, lastIndexedBlock, messagesProcessed}' && \
echo "" && \
echo "=== POOL SIZE ===" && \
curl -s http://localhost:9090/pool | jq '.size'
```

---

**Data do diagnóstico**: 2026-01-23
**Status**: ⚠️ Relayer rodando, mas não sincronizando Terra Classic
