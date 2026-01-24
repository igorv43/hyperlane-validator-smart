# 📋 Guia: Analisar Logs do Relayer no Easypanel

## 🔍 Como Analisar Logs do Relayer no Easypanel

Como o relayer está rodando no Easypanel, você precisa analisar os logs diretamente na interface do Easypanel ou copiar os logs para análise local.

---

## 📊 Análise Manual no Easypanel

### 1. Acessar Logs no Easypanel

1. Acesse o Easypanel
2. Vá para o serviço do relayer (`hpl-relayer-testnet`)
3. Abra a aba "Logs"

### 2. Procurar por Sequence 12768

No campo de busca dos logs, procure por:
```
12768
```

Isso mostrará todos os logs relacionados à mensagem específica.

### 3. Procurar por Erros de Checkpoint

Procure por:
```
checkpoint
s3
bucket
```

E filtre por erros:
```
error checkpoint
error s3
error bucket
```

### 4. Procurar por Erros de Validator

Procure por:
```
validator
announce
```

E filtre por erros:
```
error validator
not found validator
```

### 5. Verificar Pool Size

Procure por:
```
pool_size
finality pool
```

Isso mostrará se há mensagens no pool de processamento.

---

## 💻 Análise Local (Copiando Logs)

### Opção 1: Usar o Script de Análise

1. **Copiar logs do Easypanel:**
   - No Easypanel, copie os logs do relayer
   - Salve em um arquivo: `relayer-logs.txt`

2. **Executar o script:**
   ```bash
   ./analisar-logs-relayer.sh relayer-logs.txt
   ```

### Opção 2: Análise Manual

1. **Copiar logs do Easypanel para um arquivo:**
   ```bash
   # Cole os logs do Easypanel em um arquivo
   nano relayer-logs.txt
   ```

2. **Procurar por sequence 12768:**
   ```bash
   grep -i "12768" relayer-logs.txt
   ```

3. **Procurar por erros de checkpoint:**
   ```bash
   grep -iE "checkpoint|s3|bucket" relayer-logs.txt | grep -iE "error|fail|warn"
   ```

4. **Procurar por erros de validator:**
   ```bash
   grep -iE "validator|announce" relayer-logs.txt | grep -iE "error|fail|warn|not found"
   ```

5. **Verificar pool size:**
   ```bash
   grep -iE "pool_size|finality.*pool" relayer-logs.txt | tail -20
   ```

---

## 🔍 O Que Procurar nos Logs

### ✅ Sinais Positivos

- `Found log(s) in index range` com `num_logs: 1` e `sequence: Some(12768)`
- `pool_size: > 0` (indica que há mensagens sendo processadas)
- `Processing transactions in finality pool` com `pool_size > 0`
- Logs de leitura de checkpoints do S3
- Logs de validação bem-sucedida

### ❌ Sinais Negativos

- `pool_size: 0` (nenhuma mensagem no pool)
- Erros ao ler checkpoints do S3
- Erros ao descobrir validators
- Erros de validação de assinaturas
- Mensagens sobre checkpoints não encontrados
- Erros de conexão com S3

---

## 📋 Checklist de Verificação

- [ ] Mensagem sequence 12768 foi detectada?
- [ ] Há erros relacionados a checkpoints?
- [ ] Há erros relacionados a validators?
- [ ] O pool_size está em 0?
- [ ] Há logs de leitura de checkpoints do S3?
- [ ] Há logs de validação de mensagens?
- [ ] Há erros gerais nos logs?

---

## 🔗 Referências

- Script de análise: `analisar-logs-relayer.sh`
- [Diagnóstico Completo](./DIAGNOSTICO-COMPLETO-BSC-TO-TERRA.md)
