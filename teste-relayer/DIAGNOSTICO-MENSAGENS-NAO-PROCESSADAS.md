# Diagnóstico: Mensagens Detectadas mas Não Processadas

Este documento explica como diagnosticar quando o relayer detecta mensagens (`num_logs: 1`) mas não as processa (`pool_size: 0`).

---

## 🔍 Problema Identificado nos Logs

### Sintomas:
- ✅ Relayer detecta mensagens: `num_logs: 1` em `range: 29139682..=29139692`
- ✅ Terra Classic sincronizando: sequence 31 detectada
- ✅ BSC sincronizando: do bloco 86149783 (correto)
- ❌ Pool size: 0 (mensagens não estão sendo processadas)
- ⚠️ `sequence: None` na mensagem detectada

### Causa Provável:
O relayer detecta as mensagens, mas **não consegue validá-las** porque:
1. Não está lendo checkpoints do S3
2. Validators não foram descobertos
3. Sem checkpoints, o relayer não pode validar as mensagens

---

## 📋 Checklist de Diagnóstico

### 1️⃣ Verificar se o Validator está Gerando Checkpoints

Execute no host:
```bash
./query-validator-s3.sh list
```

**O que procurar:**
- ✅ Checkpoints recentes aparecem na lista
- ❌ Se não aparecer → Validator não está funcionando

---

### 2️⃣ Verificar se o Validator Anunciou

Execute no host:
```bash
./query-validator-s3.sh announcement
```

**O que procurar:**
- ✅ `announcement.json` aparece com o endereço do validator
- ❌ Se não aparecer → Validator não anunciou corretamente

---

### 3️⃣ Verificar se o Relayer Descobriu Validators

**No Easypanel, acesse o terminal do container `hpl-relayer-testnet` e execute:**

```bash
curl -s http://localhost:9090/validators | jq '.["1325"]'
```

**O que procurar:**
- ✅ Lista de validators do Terra Classic (domain 1325)
- ❌ Se retornar `null` → Relayer não descobriu validators

**Alternativa (se jq não estiver disponível):**
```bash
curl -s http://localhost:9090/validators
```

Procure por `"1325"` na resposta.

---

### 4️⃣ Verificar se o Relayer está Lendo Checkpoints do S3

**No terminal do container, execute:**

```bash
curl -s http://localhost:9090/checkpoints/1325 | jq '.'
```

**O que procurar:**
- ✅ `lastCheckpoint` com um número (ex: `18`, `19`, `20`)
- ❌ Se retornar `null` ou vazio → Relayer não está lendo checkpoints

**Alternativa (se jq não estiver disponível):**
```bash
curl -s http://localhost:9090/checkpoints/1325
```

---

### 5️⃣ Verificar Variáveis de Ambiente AWS

**No terminal do container, execute:**

```bash
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}..."
echo "AWS_REGION: ${AWS_REGION}"
```

**O que procurar:**
- ✅ Todas as variáveis devem estar definidas e não vazias
- ❌ Se alguma estiver vazia → Configurar no Easypanel

---

### 6️⃣ Verificar Logs do Relayer para Descoberta de Validators

**Nos logs do Easypanel, procure por:**

```bash
# No terminal do container ou nos logs do Easypanel
grep -i "discovering\|validator.*announce\|checkpoint\|s3" /proc/1/fd/1 2>/dev/null | tail -n 50
```

**O que procurar:**
- ✅ `"Discovering validators for domain 1325"`
- ✅ `"Found validator: 0x..."`
- ✅ `"Reading checkpoint from S3"`
- ❌ Se não aparecer → Relayer não está descobrindo validators ou lendo checkpoints

---

### 7️⃣ Verificar Permissões do Bucket S3

**No host (com AWS CLI configurado), execute:**

```bash
aws s3 ls s3://SEU_BUCKET_NAME/checkpoints/1325/ --recursive | head -n 10
```

Substitua `SEU_BUCKET_NAME` pelo nome do seu bucket.

**O que procurar:**
- ✅ Lista de arquivos de checkpoint
- ❌ Se retornar erro de acesso → Problema de permissões AWS

---

## 🔧 Soluções por Problema

### Problema 1: Validator Não Está Gerando Checkpoints

**Sintoma:** `./query-validator-s3.sh list` não retorna checkpoints.

**Solução:**
1. Verificar logs do validator no Easypanel
2. Verificar se o validator está rodando
3. Verificar variáveis de ambiente do validator:
   - `HYP_VALIDATOR_KEY`
   - `HYP_CHECKPOINT_SYNCER_BUCKET`
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

---

### Problema 2: Validator Não Anunciou

**Sintoma:** `./query-validator-s3.sh announcement` não retorna o `announcement.json`.

**Solução:**
1. Verificar logs do validator para erros de anúncio
2. Verificar se o validator tem permissão de escrita no S3
3. Reiniciar o validator

---

### Problema 3: Relayer Não Descobriu Validators

**Sintoma:** `curl http://localhost:9090/validators | jq '.["1325"]'` retorna `null`.

**Solução:**
1. Verificar se as variáveis AWS estão configuradas no relayer
2. Verificar se o relayer tem permissão de leitura no S3
3. Verificar logs do relayer para erros de descoberta
4. Aguardar alguns minutos (a descoberta pode levar tempo)

---

### Problema 4: Relayer Não Está Lendo Checkpoints

**Sintoma:** `curl http://localhost:9090/checkpoints/1325` retorna `null` ou vazio.

**Solução:**
1. Verificar se o validator está gerando checkpoints
2. Verificar se o relayer tem permissão de leitura no S3
3. Verificar se o bucket está correto
4. Verificar logs do relayer para erros de leitura de checkpoints

---

### Problema 5: Variáveis AWS Não Configuradas

**Sintoma:** Variáveis AWS estão vazias no container.

**Solução:**
1. No Easypanel, verificar se as variáveis estão configuradas:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
2. Reiniciar o relayer após configurar

---

## 🎯 Script de Diagnóstico Rápido

Crie um script para executar no terminal do container do relayer:

```bash
#!/bin/bash

echo "=== DIAGNÓSTICO RÁPIDO DO RELAYER ==="
echo ""

echo "--- 1. VALIDATORS DESCOBERTOS (TERRA CLASSIC) ---"
curl -s http://localhost:9090/validators | grep -o '"1325":{[^}]*}' || echo "Nenhum validator descoberto para domain 1325"
echo ""

echo "--- 2. ÚLTIMO CHECKPOINT LIDO (TERRA CLASSIC) ---"
curl -s http://localhost:9090/checkpoints/1325 | grep -o '"lastCheckpoint":[0-9]*' || echo "Nenhum checkpoint lido"
echo ""

echo "--- 3. STATUS DE SINCRONIZAÇÃO (TERRA CLASSIC) ---"
curl -s http://localhost:9090/sync/1325 | grep -o '"synced":[^,]*\|"lastIndexedBlock":[0-9]*\|"messagesProcessed":[0-9]*'
echo ""

echo "--- 4. MENSAGENS NO POOL ---"
curl -s http://localhost:9090/pool | grep -o '"size":[0-9]*'
echo ""

echo "--- 5. VARIÁVEIS AWS (PARCIAL) ---"
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "AWS_REGION: ${AWS_REGION}"
echo ""

echo "--- 6. LOGS RECENTES (VALIDATORS/CHECKPOINTS) ---"
grep -i "discovering\|validator.*announce\|checkpoint\|s3" /proc/1/fd/1 2>/dev/null | tail -n 10 || echo "Nenhum log relevante encontrado"
echo ""

echo "=== FIM DO DIAGNÓSTICO ==="
```

---

## 📊 Interpretação dos Resultados

### Cenário 1: Validators Não Descobertos
- **Causa:** Relayer não consegue acessar o S3 ou o validator não anunciou
- **Ação:** Verificar permissões AWS e se o validator anunciou

### Cenário 2: Checkpoints Não Lidos
- **Causa:** Relayer não consegue ler do S3 ou não há checkpoints
- **Ação:** Verificar se o validator está gerando checkpoints e permissões S3

### Cenário 3: Tudo OK, mas Pool Size: 0
- **Causa:** Mensagens detectadas mas não validadas (aguardando checkpoints)
- **Ação:** Aguardar alguns minutos para o relayer processar ou verificar se há checkpoints suficientes

---

## ⚠️ Observações Importantes

1. **Tempo de Descoberta:** O relayer pode levar alguns minutos para descobrir validators e ler checkpoints após iniciar.

2. **Checkpoints Necessários:** O relayer precisa de checkpoints para validar mensagens. Se não houver checkpoints, as mensagens não serão processadas.

3. **Permissões S3:** O relayer precisa de permissão de **leitura** no bucket S3 para ler checkpoints e announcements.

4. **Sequence None:** Se você vê `sequence: None` nos logs, isso indica que a mensagem foi detectada mas não foi indexada corretamente. Isso pode ser normal durante a sincronização inicial.

---

**Última atualização:** 2026-01-23
