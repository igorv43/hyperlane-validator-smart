# 📊 Análise: Buckets S3 dos Validators

## 🔍 Objetivo

Descobrir se os validators estão criando checkpoints e onde estão armazenados (buckets S3).

## ✅ O Que Foi Verificado

### 1. Validators Anunciados no ValidatorAnnounce

- ✅ **Total de validators anunciados:** 44
- ✅ **Validators do ISM estão anunciados:**
  - `0x242d8a855a8c932dec51f7999ae7d1e48b10c95e` ✅
  - `0xf620f5e3d25a3ae848fec74bccae5de3edcd8796` ✅
  - `0x1f030345963c54ff8229720dd3a711c15c554aeb` ✅

### 2. Storage Locations (Buckets S3)

**Problema Identificado:**
- ❌ Função `getAnnouncedStorageLocations(address)` não está retornando dados
- ❌ Eventos do ValidatorAnnounce não contêm storage locations facilmente extraíveis

**Possíveis Causas:**
1. Storage locations podem estar em eventos mais antigos
2. Função pode não estar implementada corretamente
3. Storage locations podem estar em formato diferente

## 🔧 Como Descobrir Buckets S3

### Método 1: Consultar Eventos Antigos

Os eventos de anúncio podem estar em blocos mais antigos. Tente:

```bash
# Consultar eventos de um range maior (em partes)
cast logs --from-block 86000000 --to-block 86050000 \
  --address 0xf09701B0a93210113D175461b6135a96773B5465 \
  --rpc-url https://bsc-testnet.publicnode.com | \
  grep -iE "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e|s3://"
```

### Método 2: Consultar Via Explorer

Use um block explorer para ver eventos do contrato:
- BSCScan Testnet: https://testnet.bscscan.com/address/0xf09701B0a93210113D175461b6135a96773B5465#events

### Método 3: Verificar Logs dos Validators

Se você tem acesso aos validators, verifique seus logs para ver qual bucket S3 estão usando:

```bash
# Verificar logs do validator (se rodando localmente)
docker logs hpl-validator-terraclassic-testnet | grep -i "bucket\|s3"
```

## 📋 Próximos Passos

1. **Consultar eventos mais antigos do ValidatorAnnounce**
   - Os anúncios podem ter sido feitos há muito tempo
   - Tentar ranges de blocos diferentes

2. **Verificar configuração dos validators**
   - Verificar se validators têm buckets S3 configurados
   - Verificar se validators estão gerando checkpoints para BSC

3. **Verificar se há validators do BSC rodando**
   - Os validators do ISM são para Terra Classic
   - Pode ser necessário ter validators do BSC também

4. **Consultar documentação do Hyperlane**
   - Verificar formato exato dos eventos ValidatorAnnounce
   - Verificar como o relayer descobre storage locations

## 🎯 Conclusão

- ✅ Validators estão anunciados no ValidatorAnnounce
- ❓ Storage locations (buckets S3) não foram encontradas facilmente
- ❓ Não sabemos se validators estão gerando checkpoints para BSC

**Recomendação:**
- Consultar eventos mais antigos do ValidatorAnnounce
- Verificar logs dos validators para ver qual bucket S3 estão usando
- Verificar se há validators do BSC rodando e gerando checkpoints
