# Comparação: Container Local (Funciona) vs Easypanel (Não Funciona)

Este documento compara as configurações do container local que funciona com a do Easypanel que não está processando mensagens.

---

## 📊 Diferenças Encontradas

### 1. `env_file` (NÃO é o problema)

**Container Local:**
```yaml
env_file:
  - ../.env
```

**Easypanel:**
```yaml
# Não tem env_file (variáveis configuradas diretamente no painel)
```

**Análise:** Isso está **CORRETO** para o Easypanel. O Easypanel gerencia variáveis de ambiente diretamente no painel, então não precisa do `env_file`.

---

### 2. Comando de Inicialização (IDÊNTICOS)

Ambos usam exatamente os mesmos comandos `sed` para substituir as chaves:
```bash
sed -i "s|0xYOUR_PRIVATE_KEY_HERE|${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}|g"
sed -i "s|0xYOUR_PRIVATE_KEY_HERE|${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}|g"
sed -i "s|0xYOUR_PRIVATE_KEY_HERE|${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}|g"
```

**Análise:** Os comandos são idênticos. ✅

---

### 3. Volumes (DIFERENÇA DE CAMINHO, mas normal)

**Container Local:**
```yaml
volumes:
  - ../hyperlane:/etc/hyperlane
  - ./relayer-data:/etc/data
```

**Easypanel:**
```yaml
volumes:
  - ./hyperlane:/etc/hyperlane
  - ./relayer-testnet:/etc/data
```

**Análise:** Diferença de caminho é normal (local está em subpasta). ✅

---

## 🔍 Problema Real: Variáveis AWS no Easypanel

O relayer precisa das credenciais AWS para:
1. **Descobrir validators** através do contrato ValidatorAnnounce
2. **Ler checkpoints do S3** para validar mensagens

### Variáveis Obrigatórias no Easypanel

Certifique-se de que estas variáveis estão configuradas no Easypanel:

```bash
AWS_ACCESS_KEY_ID=sua_access_key_aqui
AWS_SECRET_ACCESS_KEY=sua_secret_key_aqui
AWS_REGION=us-east-1  # ou a região do seu bucket
```

**⚠️ IMPORTANTE:** O relayer **NÃO precisa** de `HYP_CHECKPOINT_SYNCER_BUCKET` porque ele descobre o bucket através do ValidatorAnnounce. Mas ele **PRECISA** das credenciais AWS para acessar o S3.

---

## 🔧 Verificações no Easypanel

### 1. Verificar se Variáveis AWS Estão Configuradas

No Easypanel, vá para:
- **Serviço:** `hpl-relayer-testnet`
- **Aba:** "Environment Variables" ou "Variáveis de Ambiente"
- **Verifique se existem:**
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`

### 2. Verificar se Variáveis Estão Sendo Carregadas

No terminal do container, execute:
```bash
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}..."
echo "AWS_REGION: ${AWS_REGION}"
```

**Se alguma estiver vazia:** Configure no Easypanel.

### 3. Verificar se Relayer Descobriu Validators

No terminal do container, execute:
```bash
curl -s http://localhost:9090/validators | grep "1325"
```

**Se retornar vazio:** Relayer não descobriu validators (problema de S3 ou ValidatorAnnounce).

### 4. Verificar se Relayer Está Lendo Checkpoints

No terminal do container, execute:
```bash
curl -s http://localhost:9090/checkpoints/1325
```

**Se retornar `null`:** Relayer não está lendo checkpoints (problema de S3 ou permissões).

---

## 🚨 Possíveis Causas do Problema

### Causa 1: Credenciais AWS Não Configuradas no Easypanel

**Sintoma:** Variáveis AWS vazias no container.

**Solução:** Configurar `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_REGION` no Easypanel.

---

### Causa 2: Permissões AWS Insuficientes

**Sintoma:** Relayer não consegue ler do S3.

**Solução:** Verificar se as credenciais AWS têm permissão de **leitura** no bucket S3 onde os checkpoints estão armazenados.

**Permissões necessárias:**
- `s3:GetObject` no bucket de checkpoints
- `s3:ListBucket` no bucket de checkpoints

---

### Causa 3: Validator Não Anunciou

**Sintoma:** Relayer não descobre validators.

**Solução:** 
1. Verificar se o validator está rodando
2. Verificar se o validator anunciou: `./query-validator-s3.sh announcement`
3. Verificar logs do validator para erros de anúncio

---

### Causa 4: Bucket S3 Não Acessível

**Sintoma:** Relayer não consegue ler checkpoints.

**Solução:**
1. Verificar se o bucket existe
2. Verificar se o bucket tem política de leitura pública (ou se as credenciais têm acesso)
3. Verificar se há checkpoints no bucket: `./query-validator-s3.sh list`

---

## ✅ Checklist para Easypanel

Antes de reportar problemas, verifique:

- [ ] `AWS_ACCESS_KEY_ID` configurada no Easypanel
- [ ] `AWS_SECRET_ACCESS_KEY` configurada no Easypanel
- [ ] `AWS_REGION` configurada no Easypanel
- [ ] Variáveis AWS não estão vazias no container
- [ ] Credenciais AWS têm permissão de leitura no bucket S3
- [ ] Validator está gerando checkpoints (`./query-validator-s3.sh list`)
- [ ] Validator anunciou (`./query-validator-s3.sh announcement`)
- [ ] Relayer descobriu validators (`curl http://localhost:9090/validators`)
- [ ] Relayer está lendo checkpoints (`curl http://localhost:9090/checkpoints/1325`)

---

## 📋 Comandos de Diagnóstico para Executar no Easypanel

Copie e cole estes comandos no terminal do container `hpl-relayer-testnet`:

```bash
echo "=== DIAGNÓSTICO COMPLETO ==="
echo ""
echo "--- 1. VARIÁVEIS AWS ---"
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}..."
echo "AWS_REGION: ${AWS_REGION}"
echo ""
echo "--- 2. VALIDATORS DESCOBERTOS ---"
curl -s http://localhost:9090/validators | grep -o '"1325":{[^}]*}' || echo "Nenhum validator descoberto"
echo ""
echo "--- 3. CHECKPOINTS LIDOS ---"
curl -s http://localhost:9090/checkpoints/1325 | grep -o '"lastCheckpoint":[0-9]*' || echo "Nenhum checkpoint lido"
echo ""
echo "--- 4. POOL DE MENSAGENS ---"
curl -s http://localhost:9090/pool | grep -o '"size":[0-9]*'
echo ""
echo "--- 5. LOGS (VALIDATORS/CHECKPOINTS) ---"
grep -i "discovering\|validator.*announce\|checkpoint\|s3" /proc/1/fd/1 2>/dev/null | tail -n 20 || echo "Nenhum log relevante"
echo ""
echo "=== FIM DO DIAGNÓSTICO ==="
```

---

## 🎯 Próximos Passos

1. **Execute o diagnóstico acima** no terminal do container do Easypanel
2. **Compare os resultados** com o container local que funciona
3. **Identifique a diferença** (provavelmente variáveis AWS ou permissões)
4. **Corrija a diferença** no Easypanel

---

**Última atualização:** 2026-01-23
