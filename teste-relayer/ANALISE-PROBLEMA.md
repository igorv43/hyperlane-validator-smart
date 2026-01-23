# 🔍 Análise do Problema: Relayer Não Envia Mensagens Terra Classic → BSC

## ✅ Status Atual

- ✅ Relayer está rodando
- ✅ Variáveis de ambiente carregadas do `.env`
- ✅ Sincronizando BSC (bsctestnet) corretamente
- ❌ **Nenhum log do Terra Classic encontrado**

## 🚨 Problema Principal

**O relayer não está sincronizando mensagens do Terra Classic.**

### Evidências

1. **Nenhum log do Terra Classic:**
   - Não há logs de sincronização do Terra Classic
   - Não há logs de descoberta de validators do Terra Classic
   - Não há logs de leitura de checkpoints do Terra Classic

2. **Apenas BSC aparece nos logs:**
   - Todos os logs mostram apenas `bsctestnet`
   - Pool size: 0 (pode ser normal se não houver mensagens)

## 🔍 Possíveis Causas

### 1. Relayer Não Descobriu Validators do Terra Classic

**Sintoma:** Nenhum log de "Discovering validators" para domain 1325

**Verificar:**
- Se o validator anunciou no contrato ValidatorAnnounce
- Se o relayer está consultando ValidatorAnnounce
- Se há `announcement.json` no S3

**Solução:**
```bash
# Verificar se o validator anunciou
./query-validator-s3.sh announcement

# Verificar logs do relayer por "Discovering validators"
docker logs hpl-relayer-testnet-local | grep -i "discovering\|validator.*announce"
```

### 2. Relayer Não Está Lendo Checkpoints do S3

**Sintoma:** Nenhum log de leitura de checkpoints

**Verificar:**
- Credenciais AWS estão corretas
- Permissões do IAM user (precisa de `s3:GetObject`)
- Se o bucket está acessível

**Solução:**
```bash
# Verificar variáveis AWS no container
docker exec hpl-relayer-testnet-local sh -c 'echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."'

# Testar acesso ao S3 (se aws cli estiver disponível)
docker exec hpl-relayer-testnet-local aws s3 ls s3://bucket/ --region us-east-1
```

### 3. Configuração do Terra Classic Incorreta

**Sintoma:** Relayer não inicia sincronização do Terra Classic

**Verificar:**
- `relayChains` no `relayer.testnet.json` inclui `terraclassictestnet`
- Configuração do Terra Classic no `agent-config.docker-testnet.json` está correta
- `whitelist` inclui rota 1325 → 97

**Solução:**
```bash
# Verificar relayChains
docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | grep relayChains'

# Verificar configuração do Terra Classic
docker exec hpl-relayer-testnet-local sh -c 'cat /app/config/agent-config.json | grep -A 5 terraclassictestnet'
```

### 4. Database do Relayer Não Tem Cursor do Terra Classic

**Sintoma:** Relayer não sincroniza porque não tem estado salvo

**Solução:**
- Resetar database do relayer (se necessário)
- Verificar se o database tem dados do Terra Classic

## 📋 Checklist de Diagnóstico

Execute estes comandos para diagnosticar:

```bash
# 1. Verificar se relayChains inclui Terra Classic
docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | grep relayChains'

# 2. Verificar configuração do Terra Classic
docker exec hpl-relayer-testnet-local sh -c 'cat /app/config/agent-config.json | grep -A 10 terraclassictestnet | head -n 15'

# 3. Verificar logs por Terra Classic
docker logs hpl-relayer-testnet-local | grep -i "terraclassic\|1325" | head -n 20

# 4. Verificar logs por validators
docker logs hpl-relayer-testnet-local | grep -i "validator\|announce\|discovering" | head -n 20

# 5. Verificar logs por checkpoints
docker logs hpl-relayer-testnet-local | grep -i "checkpoint\|s3" | head -n 20
```

## 🎯 Próximos Passos Recomendados

1. **Verificar se o validator anunciou:**
   ```bash
   ./query-validator-s3.sh announcement
   ```

2. **Verificar se há checkpoints no S3:**
   ```bash
   ./query-validator-s3.sh list
   ```

3. **Verificar configuração do relayer:**
   - Confirmar que `relayChains` inclui `terraclassictestnet`
   - Confirmar que `allowLocalCheckpointSyncers` é `false`

4. **Monitorar logs em tempo real:**
   ```bash
   docker logs -f hpl-relayer-testnet-local | grep -i "terraclassic\|1325\|checkpoint\|validator"
   ```

## 📊 Resumo

**Status:** ⚠️ Relayer rodando, mas não sincronizando Terra Classic

**Problema:** Nenhum log do Terra Classic indica que o relayer não está:
- Descobrindo validators do Terra Classic
- Lendo checkpoints do S3
- Sincronizando mensagens do Terra Classic

**Ação necessária:** Investigar por que o relayer não está processando o Terra Classic, começando pela verificação de validators e checkpoints.

---

**Data**: 2026-01-23
