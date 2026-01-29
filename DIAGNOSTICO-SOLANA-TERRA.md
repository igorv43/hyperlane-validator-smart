# 🔍 DIAGNÓSTICO: Mensagens Solana -> Terra Classic / BSC Não Chegam

## 📋 Problema Identificado

**Sintoma:** Mensagens enviadas de Solana para Terra Classic e BSC não chegam ao destino.

**Comportamento observado:**
- ✅ Terra Classic -> Solana: **FUNCIONA**
- ❌ Solana -> Terra Classic: **NÃO FUNCIONA**
- ❌ Solana -> BSC: **NÃO FUNCIONA**

## 🔍 Análise dos Logs do Relayer

### ✅ Configuração Correta

1. **Whitelist configurada corretamente:**
   - Terra Classic (1325) <-> BSC (97) ✅
   - Terra Classic (1325) <-> Solana (1399811150) ✅

2. **Solana está nas chains do relayer:**
   - `relayChains: "terraclassictestnet,bsctestnet,solanatestnet"` ✅

3. **Relayer está sincronizando mensagens de Solana:**
   - Logs mostram: `spawn_cursor_indexer_task with domain: "solanatestnet", label: "dispatched_messages"` ✅

### ❌ Problema Identificado

**NÃO HÁ CHECKPOINTS DE SOLANA SENDO LIDOS DO S3**

- ❌ Nenhum log de checkpoint de Solana sendo buscado
- ❌ Nenhum log de validadores de Solana sendo encontrados
- ❌ Pool de mensagens de Solana está vazio (`pool_size: 0`)

## 🎯 Causa Raiz

**O problema é que não há validadores de Solana gerando checkpoints.**

### Como funciona o Hyperlane:

1. **Para Terra Classic -> Solana funcionar:**
   - ✅ Validator de Terra Classic detecta mensagem
   - ✅ Validator gera checkpoint assinado
   - ✅ Checkpoint é salvo no S3
   - ✅ Relayer lê checkpoint do S3
   - ✅ Relayer entrega mensagem no Solana

2. **Para Solana -> Terra Classic funcionar:**
   - ❌ **FALTA:** Validator de Solana detecta mensagem
   - ❌ **FALTA:** Validator gera checkpoint assinado
   - ❌ **FALTA:** Checkpoint é salvo no S3
   - ❌ Relayer não encontra checkpoints de Solana no S3
   - ❌ Relayer não pode entregar mensagem

## 🔧 Solução

### Opção 1: Configurar Validator de Solana (Recomendado)

Para mensagens de Solana chegarem em Terra Classic ou BSC, é necessário:

1. **Criar um validator de Solana:**
   - Configurar validator para monitorar mensagens de Solana
   - Validator deve gerar checkpoints assinados
   - Checkpoints devem ser salvos no S3

2. **Configuração necessária:**
   ```json
   {
     "db": "/etc/data/db",
     "checkpointSyncer": {
       "type": "s3",
       "bucket": "hyperlane-validator-signatures-SEU-NOME-solanatestnet",
       "region": "us-east-1"
     },
     "originChainName": "solanatestnet",
     "validator": {
       "type": "hexKey",
       "key": "0xSUA_CHAVE_VALIDATOR_SOLANA"
     },
     "chains": {
       "solanatestnet": {
         "signer": {
           "type": "hexKey",
           "key": "0xSUA_CHAVE_SIGNER_SOLANA"
         }
       }
     }
   }
   ```

3. **Adicionar ao docker-compose-testnet.yml:**
   ```yaml
   validator-solana:
     container_name: hpl-validator-solana-testnet
     image: gcr.io/abacus-labs-dev/hyperlane-agent:1.7.0
     # ... configuração similar ao validator-terraclassic
   ```

### Opção 2: Verificar se há Validadores Públicos de Solana

Se houver validadores públicos de Solana gerando checkpoints, verificar:

1. **Se o relayer consegue descobrir esses validadores:**
   - Verificar logs: `docker logs hpl-relayer-testnet | grep -i "validator.*announce"`
   - Verificar se há validadores anunciados no contrato `validatorAnnounce` do Solana

2. **Se os checkpoints estão no S3:**
   - Verificar bucket S3 para checkpoints de Solana
   - Verificar se o relayer tem permissão para ler esses checkpoints

## 📊 Verificações Realizadas

### ✅ Configuração do Relayer
- [x] Whitelist inclui Solana <-> Terra Classic
- [x] Solana está em `relayChains`
- [x] `allowLocalCheckpointSyncers: false` (lê do S3)
- [x] Chaves privadas configuradas para Solana

### ❌ Checkpoints de Solana
- [ ] Nenhum checkpoint de Solana sendo lido do S3
- [ ] Nenhum validator de Solana encontrado
- [ ] Pool de mensagens de Solana vazio

## 🚀 Próximos Passos

1. **Verificar se há validadores públicos de Solana:**
   ```bash
   # Consultar contrato validatorAnnounce do Solana
   # Endereço: 8qNYSi9EP1xSnRjtMpyof88A26GBbdcrsa61uSaHiwx3
   ```

2. **Se não houver validadores públicos, configurar validator de Solana:**
   - Seguir guia de configuração de validator
   - Configurar S3 bucket para checkpoints de Solana
   - Adicionar validator ao docker-compose

3. **Monitorar logs após configuração:**
   ```bash
   docker logs hpl-relayer-testnet -f | grep -i "solana\|checkpoint"
   ```

## 📝 Notas Importantes

- **Terra Classic -> Solana funciona** porque há validator de Terra Classic gerando checkpoints
- **Solana -> Terra Classic não funciona** porque não há validator de Solana gerando checkpoints
- O relayer está configurado corretamente, mas não encontra checkpoints de Solana para processar

---

**Data do diagnóstico:** 2026-01-29
**Relayer testnet:** hpl-relayer-testnet
**Status:** Aguardando configuração de validator de Solana
