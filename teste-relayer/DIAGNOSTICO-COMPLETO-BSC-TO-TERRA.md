# 🔍 Diagnóstico Completo: BSC -> Terra Classic não chega

## 📊 Resumo Executivo

**Problema:** Mensagens enviadas de BSC para Terra Classic não estão sendo processadas pelo relayer.

**Causa Raiz:** Os validators configurados no ISM do Terra Classic **NÃO estão anunciados** no ValidatorAnnounce do BSC, impedindo que o relayer descubra onde estão os checkpoints.

---

## ✅ Configuração do ISM Verificada

### ISM Multisig BSC
- **Endereço:** `terra1ksq6cekt0as2f9vv5txld90s854y4pkr2k0jn5p83vqpa5zzzfysuavxr0`
- **Threshold:** 2 de 3 validators
- **Domain:** 97 (BSC Testnet)

### Validators Configurados no ISM

1. `0x242d8a855a8c932dec51f7999ae7d1e48b10c95e`
2. `0xf620f5e3d25a3ae848fec74bccae5de3edcd8796`
3. `0x1f030345963c54ff8229720dd3a711c15c554aeb`

---

## ✅ Verificação dos Validators no ValidatorAnnounce do BSC

**ValidatorAnnounce BSC:** `0xf09701B0a93210113D175461b6135a96773B5465`

**Consulta:**
```bash
cast call 0xf09701B0a93210113D175461b6135a96773B5465 \
  "getAnnouncedValidators()" \
  --rpc-url https://bsc-testnet.publicnode.com
```

**Resultado:**
- ✅ `0x242d8a855a8c932dec51f7999ae7d1e48b10c95e` - **ANUNCIADO**
- ✅ `0xf620f5e3d25a3ae848fec74bccae5de3edcd8796` - **ANUNCIADO**
- ✅ `0x1f030345963c54ff8229720dd3a711c15c554aeb` - **ANUNCIADO**

**Todos os validators do ISM estão anunciados no ValidatorAnnounce do BSC!**

### ⚠️ Problema Real

Se os validators estão anunciados, o problema pode ser:

1. ✅ Validators estão anunciados (VERIFICADO)
2. ❓ Validators não estão gerando checkpoints para mensagens do BSC
3. ❓ Checkpoints não estão sendo salvos no S3 corretamente
4. ❓ Relayer não está conseguindo ler checkpoints do S3
5. ❓ Outro problema na configuração do relayer

Para o relayer processar mensagens **BSC → Terra Classic**, ele precisa:

1. ✅ Detectar a mensagem no BSC (FEITO - sequence 12768 detectada)
2. ✅ Descobrir quais validators são necessários (FEITO - via ISM)
3. ✅ Descobrir onde esses validators armazenam checkpoints (FEITO - via ValidatorAnnounce)
4. ❓ Ler checkpoints do S3 para validar a mensagem (PRECISA VERIFICAR)
5. ❓ Retransmitir para Terra Classic (PRECISA VERIFICAR)

---

## 🔧 Próximos Passos de Investigação

### 1. Verificar se Validators Estão Gerando Checkpoints para BSC

Os validators precisam:

1. **Estar rodando e monitorando o BSC**
2. **Gerar checkpoints para cada mensagem enviada do BSC**
3. **Salvar checkpoints no S3 no bucket anunciado**

**Verificar:**
- Há validators do BSC rodando?
- Os validators estão gerando checkpoints para mensagens do BSC?
- Os checkpoints estão sendo salvos no S3?

### 2. Verificar Logs do Relayer

Verificar logs do relayer para erros específicos:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "checkpoint\|validator\|s3\|error" | tail -100
```

**Procurar por:**
- Erros ao ler checkpoints do S3
- Erros ao descobrir validators
- Mensagens sobre checkpoints não encontrados
- Erros de validação de mensagens

### 3. Verificar Checkpoints no S3

Verificar se há checkpoints no bucket S3 para a mensagem sequence 12768:

```bash
# Listar checkpoints no bucket S3
aws s3 ls s3://BUCKET_NAME/ --recursive | grep "12768"
```

---

## 📋 Checklist de Verificação

- [x] Consultar ISM do Terra Classic para domain 97
- [x] Identificar validators configurados no ISM
- [x] Verificar se validators estão anunciados no ValidatorAnnounce do BSC
- [ ] Anunciar validators no ValidatorAnnounce do BSC
- [ ] Verificar se validators estão gerando checkpoints para mensagens do BSC
- [ ] Verificar se checkpoints estão sendo salvos no S3
- [ ] Testar envio BSC → Terra Classic novamente

---

## 🔗 Referências

- [Problema BSC to Terra](./PROBLEMA-BSC-TO-TERRA.md)
- [Verificar Validators ISM](./VERIFICAR-VALIDATORS-ISM.md)
- Script de consulta: `consultar-ism-terraclassic-completo.sh`

---

## 📝 Comandos Úteis

### Consultar ISM do Terra Classic
```bash
./consultar-ism-terraclassic-completo.sh
```

### Verificar Validators Anunciados no BSC
```bash
cast call 0xf09701B0a93210113D175461b6135a96773B5465 \
  "getAnnouncedValidators()" \
  --rpc-url https://bsc-testnet.publicnode.com
```

### Verificar Logs do Relayer
```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "validator\|checkpoint\|ism" | tail -50
```
