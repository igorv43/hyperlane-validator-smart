# 🔍 Como Localizar e Resolver o Problema do Relayer

## 📊 Problema Identificado

O relayer está:
- ✅ Rodando corretamente
- ✅ Detectando a mensagem sequence 12768
- ❌ **Mas NÃO está processando** (pool_size: 0)

## 🔍 Diagnóstico Passo a Passo

### 1. Executar Script de Diagnóstico

```bash
cd /home/lunc/hyperlane-validator-smart
./diagnosticar-problema-relayer.sh
```

Este script verifica:
- ✅ Se o relayer está rodando
- ✅ Erros nos logs
- ✅ Detecção da mensagem 12768
- ✅ Pool size
- ✅ Tentativas de ler checkpoints
- ✅ Descoberta de validators
- ✅ Validação de mensagens
- ✅ Configuração do relayer

---

## 🎯 Possíveis Causas e Soluções

### Causa 1: Checkpoints Não Estão Disponíveis no S3

**Sintomas:**
- Pool size: 0
- Nenhum erro explícito sobre checkpoints
- Mensagem detectada mas não processada

**Como Verificar:**
```bash
# Verificar logs do relayer para erros de S3
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "s3|bucket|checkpoint.*not found|unable.*checkpoint"
```

**Solução:**
1. Verificar se validators do BSC estão gerando checkpoints
2. Verificar se checkpoints estão sendo salvos no S3
3. Verificar se buckets S3 estão acessíveis

---

### Causa 2: Relayer Não Consegue Descobrir Validators

**Sintomas:**
- Nenhum log sobre descoberta de validators
- Pool size: 0
- Mensagem detectada mas não processada

**Como Verificar:**
```bash
# Verificar se há logs sobre ValidatorAnnounce
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "validator.*announce|announce.*validator|discover.*validator"
```

**Solução:**
1. Verificar se validators estão anunciados no ValidatorAnnounce do BSC
   ```bash
   ./verificar-validators-anunciados-bsc.sh
   ```
2. Verificar se o relayer tem acesso ao RPC do BSC
3. Verificar se o contrato ValidatorAnnounce está correto

---

### Causa 3: Quorum Insuficiente

**Sintomas:**
- Pool size: 0
- Mensagem detectada mas não processada
- Possíveis logs sobre "insufficient quorum" ou "quorum not met"

**Como Verificar:**
```bash
# Verificar logs sobre quorum
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "quorum|insufficient|threshold"
```

**Solução:**
1. Verificar quantos validators estão configurados no ISM (deve ser 3)
2. Verificar threshold (deve ser 2 de 3)
3. Verificar se pelo menos 2 validators geraram checkpoints
   ```bash
   ./verificar-checkpoints-quorum.sh
   ```

---

### Causa 4: Erro ao Ler Checkpoints do S3

**Sintomas:**
- Erros nos logs sobre S3, AWS, ou checkpoints
- Pool size: 0

**Como Verificar:**
```bash
# Verificar erros relacionados a S3/AWS
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "error.*s3|error.*aws|error.*checkpoint|access.*denied|permission.*denied"
```

**Solução:**
1. Verificar se credenciais AWS estão configuradas no `.env`
   ```bash
   grep AWS_ACCESS_KEY_ID .env
   grep AWS_SECRET_ACCESS_KEY .env
   ```
2. Verificar se credenciais AWS estão sendo carregadas no container
   ```bash
   docker exec hpl-relayer-testnet-local env | grep AWS
   ```
3. Verificar se buckets S3 são públicos ou se relayer tem permissão de leitura

---

### Causa 5: Validators Não Estão Gerando Checkpoints para BSC

**Sintomas:**
- Pool size: 0
- Mensagem detectada mas não processada
- Nenhum checkpoint disponível

**Como Verificar:**
1. Verificar se há validators do BSC rodando
2. Verificar se validators estão monitorando mensagens do BSC
3. Verificar se validators estão salvando checkpoints no S3

**Solução:**
1. Verificar se validators do BSC estão configurados e rodando
2. Verificar logs dos validators do BSC
3. Verificar se validators estão salvando checkpoints no S3

---

## 🔧 Comandos Úteis para Diagnóstico

### Ver Logs em Tempo Real
```bash
cd /home/lunc/hyperlane-validator-smart/teste-relayer
docker compose -f docker-compose-relayer-only.yml logs -f relayer
```

### Procurar por Erros Específicos
```bash
# Erros gerais
docker logs hpl-relayer-testnet-local 2>&1 | grep -i error | tail -20

# Erros de checkpoint
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "checkpoint.*error|error.*checkpoint" | tail -20

# Erros de S3/AWS
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "s3.*error|aws.*error|access.*denied" | tail -20

# Erros de validator
docker logs hpl-relayer-testnet-local 2>&1 | grep -iE "validator.*error|error.*validator" | tail -20
```

### Verificar Pool Size
```bash
docker logs hpl-relayer-testnet-local 2>&1 | grep -i "pool_size" | tail -10
```

### Verificar Mensagem Específica
```bash
docker logs hpl-relayer-testnet-local 2>&1 | grep -i "12768" | tail -20
```

### Verificar Configuração do Relayer
```bash
docker exec hpl-relayer-testnet-local cat /etc/hyperlane/relayer.testnet.json | jq .
```

---

## 📋 Checklist de Verificação

- [ ] Relayer está rodando
- [ ] Mensagem 12768 está sendo detectada
- [ ] Pool size está sendo verificado
- [ ] Logs de checkpoints estão sendo analisados
- [ ] Logs de validators estão sendo analisados
- [ ] Credenciais AWS estão configuradas
- [ ] Validators estão anunciados no ValidatorAnnounce
- [ ] Checkpoints estão disponíveis no S3
- [ ] Quorum está sendo atendido (2 de 3)

---

## 🎯 Próximos Passos Recomendados

1. **Executar diagnóstico completo:**
   ```bash
   ./diagnosticar-problema-relayer.sh
   ```

2. **Verificar logs detalhados:**
   ```bash
   docker logs -f hpl-relayer-testnet-local
   ```

3. **Verificar validators anunciados:**
   ```bash
   ./verificar-validators-anunciados-bsc.sh
   ```

4. **Verificar checkpoints e quorum:**
   ```bash
   ./verificar-checkpoints-quorum.sh
   ```

5. **Verificar configuração do ISM:**
   ```bash
   ./consultar-ism-terraclassic-completo.sh
   ```

---

## 📄 Scripts Disponíveis

- `diagnosticar-problema-relayer.sh` - Diagnóstico completo do relayer
- `verificar-checkpoints-via-relayer.sh` - Analisa logs do relayer
- `verificar-validators-anunciados-bsc.sh` - Verifica validators anunciados
- `verificar-checkpoints-quorum.sh` - Verifica checkpoints e quorum
- `consultar-ism-terraclassic-completo.sh` - Consulta ISM do Terra Classic

---

## 🔗 Referências

- [Análise de Checkpoints e Quorum](../teste-relayer/ANALISE-CHECKPOINTS-QUORUM.md)
- [Guia Verificar Checkpoints](../teste-relayer/GUIA-VERIFICAR-CHECKPOINTS-QUORUM.md)
