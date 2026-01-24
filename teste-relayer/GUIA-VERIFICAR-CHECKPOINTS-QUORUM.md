# 📋 Guia: Verificar Checkpoints e Quorum

## 🎯 Objetivo

Verificar se há checkpoints suficientes (quorum) para validar uma mensagem BSC -> Terra Classic.

## ✅ O Que Já Foi Verificado

1. **ISM do Terra Classic:**
   - ✅ 3 validators configurados para domain 97 (BSC)
   - ✅ Threshold: 2 de 3 validators

2. **ValidatorAnnounce do BSC:**
   - ✅ Todos os 3 validators estão anunciados

## ❌ Problema Atual

**Não conseguimos descobrir automaticamente os buckets S3 dos validators.**

Os validators estão anunciados no ValidatorAnnounce, mas não temos acesso direto às storage locations através da função `getAnnouncedStorageLocations()`.

## 🔍 Soluções

### Opção 1: Fornecer Buckets Manualmente

Se você conhece os buckets S3 dos validators, pode editá-los no script:

```bash
# Editar verificar-checkpoints-quorum.sh
# Adicionar buckets conhecidos:

VALIDATOR_BUCKETS=(
    ["0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"]="hyperlane-validator-signatures-validator1-bsc"
    ["0xf620f5e3d25a3ae848fec74bccae5de3edcd8796"]="hyperlane-validator-signatures-validator2-bsc"
    ["0x1f030345963c54ff8229720dd3a711c15c554aeb"]="hyperlane-validator-signatures-validator3-bsc"
)
```

### Opção 2: Listar Buckets da Conta AWS

Se você tem acesso AWS, pode listar todos os buckets e procurar por padrões:

```bash
# Listar todos os buckets
aws s3 ls | grep hyperlane

# Para cada bucket, verificar se há checkpoints
for bucket in $(aws s3 ls | grep hyperlane | awk '{print $3}'); do
    echo "Verificando bucket: $bucket"
    aws s3 ls s3://$bucket/ --recursive | grep "12768" || echo "  Nenhum checkpoint encontrado"
done
```

### Opção 3: Consultar Eventos do ValidatorAnnounce

Os eventos do ValidatorAnnounce contêm as storage locations. Você pode consultá-los:

```bash
# Consultar eventos recentes do ValidatorAnnounce
cast logs \
  --from-block latest-10000 \
  --address 0xf09701B0a93210113D175461b6135a96773B5465 \
  --rpc-url https://bsc-testnet.publicnode.com \
  | grep -i "s3://"
```

### Opção 4: Verificar Manualmente no S3

1. **Listar buckets conhecidos:**
   ```bash
   aws s3 ls | grep hyperlane
   ```

2. **Para cada bucket, verificar checkpoints:**
   ```bash
   # Substitua BUCKET_NAME pelo nome do bucket
   aws s3 ls s3://BUCKET_NAME/ --recursive | grep "12768"
   ```

3. **Verificar conteúdo do checkpoint:**
   ```bash
   # Baixar e visualizar checkpoint
   aws s3 cp s3://BUCKET_NAME/checkpoint_12768.json - | jq .
   ```

## 📊 Formato dos Checkpoints

Os checkpoints no S3 geralmente seguem este formato:

```
s3://bucket-name/
  ├── checkpoint_0x{hash}.json
  ├── checkpoint_0x{hash}.json
  └── ...
```

Ou podem estar organizados por domain:

```
s3://bucket-name/
  ├── checkpoints/
  │   ├── 97/  (BSC Testnet)
  │   │   ├── checkpoint_12768.json
  │   │   └── ...
  │   └── 1325/  (Terra Classic Testnet)
  │       └── ...
```

## 🔍 Verificar Quorum

Para verificar se há quorum suficiente:

1. **Contar checkpoints encontrados:**
   ```bash
   # Para cada validator, verificar se há checkpoint
   CHECKPOINTS_FOUND=0
   
   # Validator 1
   if aws s3 ls s3://bucket1/ --recursive | grep -q "12768"; then
       CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
   fi
   
   # Validator 2
   if aws s3 ls s3://bucket2/ --recursive | grep -q "12768"; then
       CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
   fi
   
   # Validator 3
   if aws s3 ls s3://bucket3/ --recursive | grep -q "12768"; then
       CHECKPOINTS_FOUND=$((CHECKPOINTS_FOUND + 1))
   fi
   
   # Verificar quorum (threshold: 2)
   if [ $CHECKPOINTS_FOUND -ge 2 ]; then
       echo "✅ Quorum suficiente: $CHECKPOINTS_FOUND >= 2"
   else
       echo "❌ Quorum insuficiente: $CHECKPOINTS_FOUND < 2"
   fi
   ```

## 📋 Checklist

- [ ] Validators identificados no ISM (✅ Feito)
- [ ] Validators anunciados no ValidatorAnnounce (✅ Feito)
- [ ] Buckets S3 identificados (❌ Pendente)
- [ ] Checkpoints verificados no S3 (❌ Pendente)
- [ ] Quorum verificado (❌ Pendente)

## 🔗 Referências

- Script: `verificar-checkpoints-quorum.sh`
- [Diagnóstico Completo](./DIAGNOSTICO-COMPLETO-BSC-TO-TERRA.md)
- [Guia AWS S3](../../GUIDE-AWS-S3-AND-KEYS.md)
