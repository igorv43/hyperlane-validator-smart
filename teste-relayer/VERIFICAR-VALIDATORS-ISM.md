# 🔍 Verificar Validators do ISM para BSC -> Terra Classic

## 📊 Situação

Você tem validators configurados no ISM do Warp Route do Terra Classic:
- **Warp Route:** `terra1zlm0h2xu6rhnjchn29hxnpvr74uxxqetar9y75zcehyx2mqezg9slj09ml`
- **ISM:** `terra1na6ljyf4m5x2u7llfvvxxe2nyq0t8628qyk0vnwu4ttpq86tt0cse47t68`

## 🔍 Como o Relayer Descobre Validators

Para mensagens **BSC → Terra Classic**, o relayer precisa:

1. ✅ **Consultar o ISM do Warp Route no Terra Classic** para descobrir quais validators são necessários
2. ✅ **Descobrir onde esses validators armazenam checkpoints** através do `ValidatorAnnounce` no **BSC**
3. ❌ **Ler checkpoints do S3** para validar mensagens do BSC

### ⚠️ Problema Identificado

O relayer pode estar:
- ✅ Consultando o ISM corretamente
- ❌ Não encontrando os validators no `ValidatorAnnounce` do **BSC**
- ❌ Não conseguindo ler checkpoints do S3

**IMPORTANTE:** Os validators precisam estar anunciados no `ValidatorAnnounce` do **BSC** (não do Terra Classic) para que o relayer possa descobrir onde estão os checkpoints das mensagens do BSC.

---

## 📋 Verificações Necessárias

### 1. Verificar Validators no ISM do Terra Classic

```bash
# Consultar ISM do Warp Route no Terra Classic
# (usar ferramenta Terra Classic para consultar o contrato ISM)
```

### 2. Verificar se Validators estão Anunciados no ValidatorAnnounce do BSC

```bash
# Consultar ValidatorAnnounce no BSC Testnet
cast call 0xf09701B0a93210113D175461b6135a96773B5465 \
  "getAnnouncedValidators()" \
  --rpc-url https://bsc-testnet.publicnode.com
```

**O que verificar:**
- Os validators do ISM estão na lista de validators anunciados no BSC?
- Os validators anunciaram seu bucket S3 no ValidatorAnnounce do BSC?

### 3. Verificar se Validators estão Gerando Checkpoints para BSC

Os validators precisam estar rodando e gerando checkpoints para mensagens do **BSC** (não apenas do Terra Classic).

**Verificar:**
- Há validators do BSC rodando?
- Os validators estão gerando checkpoints para mensagens do BSC?
- Os checkpoints estão sendo salvos no S3?

---

## 🔧 Solução

### Opção 1: Validators Devem Anunciar no BSC

Os validators configurados no ISM do Terra Classic precisam:

1. **Anunciar no ValidatorAnnounce do BSC:**
   - Cada validator precisa chamar `announce()` no contrato `ValidatorAnnounce` do BSC
   - Informar o bucket S3 onde os checkpoints do BSC são armazenados

2. **Gerar Checkpoints para Mensagens do BSC:**
   - Os validators precisam estar rodando e monitorando o BSC
   - Gerar checkpoints para cada mensagem enviada do BSC

### Opção 2: Verificar Logs do Relayer

Verifique os logs do relayer para ver se há erros ao descobrir validators:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "validator\|checkpoint\|ism" | tail -50
```

**Procurar por:**
- Erros ao consultar ISM
- Erros ao descobrir validators
- Erros ao ler checkpoints do S3
- Mensagens sobre validators não encontrados

### Opção 3: Verificar API do Relayer

O relayer expõe uma API em `http://localhost:19010` (ou porta configurada):

```bash
# Verificar status do relayer
curl http://localhost:19010/health

# Verificar mensagens pendentes
curl http://localhost:19010/metrics | grep -i "message\|pool"
```

---

## 📝 Checklist

- [ ] Verificar quais validators estão configurados no ISM do Terra Classic
- [ ] Verificar se esses validators estão anunciados no ValidatorAnnounce do BSC
- [ ] Verificar se os validators estão gerando checkpoints para mensagens do BSC
- [ ] Verificar logs do relayer para erros de descoberta de validators
- [ ] Verificar se há checkpoints do BSC no bucket S3
- [ ] Testar envio BSC → Terra Classic novamente

---

## 🔗 Referências

- [Problema BSC to Terra](./PROBLEMA-BSC-TO-TERRA.md)
- [Script Consultar ISM](../consultar-warp-ism-bsc.sh)
