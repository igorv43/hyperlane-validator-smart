# 🔍 Verificação: Mensagens Terra Classic → BSC

## 📊 Resultado da Verificação

### ✅ Status do Relayer

- **Container:** Rodando
- **Terra Classic:** Sincronizando (domain 1325)
- **BSC:** Sincronizando (domain 97)
- **Whitelist:** Configurada corretamente (1325 → 97)

### ⚠️ Mensagens Detectadas

**Sequências detectadas no Terra Classic:**
- **Sequence 25:** Detectada no bloco `29138547-29138557`
  - `tx_id: 0x0000000000000000000000000000000000000000000000000000000000000000bbef108eb2eabac2de08dda13781d1bb5fe7b19ea85e1b80cef8c43d66deec5c`
  - `num_logs: 1`
- **Sequences 23-28:** Detectadas durante sincronização

### ❌ Problema: Mensagens Não Estão Sendo Processadas

**Evidências:**
- **Pool size: 0** - Nenhuma mensagem aguardando para ser enviada
- **Nenhum log de processamento:**
  - Não há logs de "processing message"
  - Não há logs de "retry message"
  - Não há logs de "deliver message"
  - Não há logs de "relayer::relayer: Processing message"

**Conclusão:** O relayer está **detectando mensagens** no Terra Classic, mas **não está processando** ou **retransmitindo** para o BSC.

## 🔍 Possíveis Causas

### 1. Relayer Não Está Lendo Checkpoints do S3

**Sintoma:** Mensagens detectadas, mas não processadas

**Verificar:**
- Se o relayer está lendo checkpoints do S3
- Se há logs de "Reading checkpoint from S3"
- Se há logs de "checkpoint validation"

**Solução:**
```bash
# Verificar logs de checkpoints
docker logs hpl-relayer-testnet-local | grep -i "checkpoint\|s3"
```

### 2. Validators Não Foram Descobertos

**Sintoma:** Relayer não consegue validar mensagens sem checkpoints

**Verificar:**
- Se o relayer descobriu validators do Terra Classic
- Se há logs de "Discovering validators"
- Se há logs de "Found validator"

**Solução:**
```bash
# Verificar logs de validators
docker logs hpl-relayer-testnet-local | grep -i "discovering\|validator.*announce\|found.*validator"
```

### 3. Checkpoints Não Estão Sendo Validados

**Sintoma:** Mensagens detectadas, mas checkpoints não validados

**Verificar:**
- Se há checkpoints no S3
- Se o relayer está lendo checkpoints
- Se há erros de validação de checkpoint

**Solução:**
```bash
# Verificar checkpoints no S3
./query-validator-s3.sh list

# Verificar se validator anunciou
./query-validator-s3.sh announcement
```

### 4. Mensagens Não Atendem aos Critérios de Finalidade

**Sintoma:** Mensagens detectadas, mas não prontas para retransmissão

**Verificar:**
- Se as mensagens têm finalidade suficiente
- Se há logs de "finality" ou "waiting for finality"

## 📋 Checklist de Diagnóstico

Execute estes comandos para diagnosticar:

```bash
# 1. Verificar se validators foram descobertos
docker logs hpl-relayer-testnet-local | grep -i "discovering\|validator.*announce\|found.*validator" | tail -n 20

# 2. Verificar se checkpoints estão sendo lidos
docker logs hpl-relayer-testnet-local | grep -i "checkpoint\|s3.*read\|reading.*checkpoint" | tail -n 20

# 3. Verificar checkpoints no S3
./query-validator-s3.sh list

# 4. Verificar se validator anunciou
./query-validator-s3.sh announcement

# 5. Verificar pool de mensagens
docker logs hpl-relayer-testnet-local | grep -i "pool_size\|finality.*pool" | tail -n 10

# 6. Verificar mensagens detectadas
docker logs hpl-relayer-testnet-local | grep -E "sequence.*[0-9]+|num_logs.*[1-9]" | tail -n 20
```

## 🎯 Próximos Passos

1. **Verificar se validators foram descobertos:**
   - Se não, verificar se o validator anunciou corretamente
   - Verificar se o relayer tem acesso ao S3

2. **Verificar se checkpoints estão sendo lidos:**
   - Se não, verificar credenciais AWS
   - Verificar permissões do bucket S3

3. **Verificar se há checkpoints no S3:**
   - Se não, o validator pode não estar gerando checkpoints
   - Verificar logs do validator

4. **Verificar se mensagens estão no contrato Mailbox:**
   - Verificar no Terra Classic se há mensagens no contrato Mailbox
   - Verificar se as mensagens são para o BSC (domain 97)

## 📊 Resumo

**Status:** ⚠️ Relayer detectando mensagens, mas não processando

**Problema:** Mensagens detectadas (sequence 25), mas pool vazio e nenhum processamento

**Ação necessária:** Verificar se validators foram descobertos e se checkpoints estão sendo lidos do S3

---

**Data**: 2026-01-23
**Sequence detectada**: 25 (bloco 29138547-29138557)
**Pool size**: 0
