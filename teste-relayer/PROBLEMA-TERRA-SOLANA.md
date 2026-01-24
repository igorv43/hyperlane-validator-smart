# 🎯 PROBLEMA: Mensagem Terra Classic -> Solana Não Chegou

## 📋 Informações da Mensagem

- **Hash fornecido:** `HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw`
- **Direção:** Terra Classic → Solana
- **Status:** ❌ Não encontrada no Solana

## 🔍 Diagnóstico

### 1. Verificação no Solana

O hash fornecido não foi encontrado no Solana, indicando que:
- ❌ A mensagem não foi entregue no Solana
- ❌ A transação não existe ou ainda não foi processada

### 2. Validators do Terra Classic

**Status:** ✅ 1 validator anunciado no Terra Classic
- Validator: `0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`

### 3. Possíveis Causas

#### A. Validator não está gerando checkpoints

**Sintomas:**
- Validator está rodando mas não gera checkpoints
- Não há checkpoints no S3 para mensagens Terra->Solana

**Verificação:**
```bash
# Verificar logs do validator
docker logs hpl-validator-terraclassic-testnet | grep -i checkpoint

# Verificar checkpoints no S3
aws s3 ls s3://SEU-BUCKET/ --recursive | grep checkpoint
```

#### B. Relayer não está processando mensagens Terra->Solana

**Sintomas:**
- Relayer não está configurado para Solana
- Relayer não está lendo checkpoints do Terra Classic

**Verificação:**
```bash
# Verificar logs do relayer
docker logs hpl-relayer-testnet | grep -i solana

# Verificar configuração
cat hyperlane/relayer.testnet.json | jq '.relayChains'
```

#### C. ISM do Solana não tem validators do Terra Classic

**Sintomas:**
- ISM do Solana não está configurado para aceitar mensagens do Terra Classic
- Validators do Terra Classic não estão no ISM do Solana

**Verificação:**
- Consultar ISM do Solana para domain 1325 (Terra Classic)
- Verificar se há validators do Terra Classic configurados

#### D. Quorum não está sendo atingido

**Sintomas:**
- Há checkpoints, mas não suficientes para atingir o threshold
- Threshold do ISM requer mais validators do que estão disponíveis

**Verificação:**
- Verificar threshold do ISM do Solana
- Verificar quantos validators têm checkpoints disponíveis

## 🎯 Próximos Passos

1. **Verificar logs do validator:**
   ```bash
   docker logs hpl-validator-terraclassic-testnet --tail 100 | grep -i "checkpoint\|error"
   ```

2. **Verificar logs do relayer:**
   ```bash
   docker logs hpl-relayer-testnet --tail 100 | grep -i "solana\|terra\|message"
   ```

3. **Verificar checkpoints no S3:**
   ```bash
   # Obter storage location do validator
   # Verificar se há checkpoints recentes
   ```

4. **Verificar ISM do Solana:**
   - Consultar Mailbox do Solana
   - Verificar ISM configurado para domain 1325
   - Verificar validators configurados

5. **Verificar configuração do relayer:**
   - Confirmar que Solana está nas chains configuradas
   - Verificar se há credenciais AWS corretas

## 📄 Arquivos Relacionados

- `diagnosticar-mensagem-terra-solana.sh` - Script de diagnóstico
- `verificar-mensagem-terra-solana-completo.sh` - Verificação completa
