# 🎯 Causa Raiz: Mensagem BSC -> Terra Classic Não Está Sendo Processada

## ✅ Descoberta Importante

### Mensagem 12768 Está Sendo Detectada!

**Métricas do Relayer:**
- ✅ `hyperlane_cursor_current_sequence` (forward): **12768**
- ✅ `hyperlane_cursor_max_sequence`: **12768**
- ✅ Bloco atual BSC: **86192098**

### ❌ Mas Não Está Sendo Processada

**Pool vazio:**
- ❌ `finality_stage_pool_length`: **0**
- ❌ `inclusion_stage_pool_length`: **0**
- ❌ `message_processed` (bsctestnet -> terraclassictestnet): **0**

## 🔍 Análise

### O Que Está Funcionando

1. ✅ **Sincronização:** Relayer está sincronizando corretamente
2. ✅ **Detecção de Mensagens:** Mensagem 12768 está sendo detectada
3. ✅ **Configuração:** Arquivos e variáveis de ambiente estão corretos

### O Que NÃO Está Funcionando

1. ❌ **Processamento:** Mensagem detectada não está entrando no pool
2. ❌ **Checkpoints:** Nenhuma tentativa de ler checkpoints encontrada nos logs
3. ❌ **Validação:** Mensagem não está sendo validada

## 🎯 Causa Raiz Provável

A mensagem está sendo **detectada** mas **não está sendo processada** porque:

### 1. Validators Não Têm Storage Locations Anunciadas no BSC

**CORREÇÃO IMPORTANTE:**
Para mensagens BSC -> Terra Classic:
- ✅ Relayer consulta **ValidatorAnnounce do BSC** (origem), não do Terra Classic
- ❌ Validators do ISM NÃO têm buckets S3 anunciados no **BSC ValidatorAnnounce**
- ❌ Relayer não consegue descobrir onde estão os checkpoints dos validators do BSC

### 2. Fluxo de Processamento

Para uma mensagem BSC -> Terra Classic ser processada:

1. ✅ **Detecção:** Mensagem detectada na chain BSC (FUNCIONANDO)
2. ❌ **Descoberta de Validators:** Relayer consulta ValidatorAnnounce do Terra Classic (PROBLEMA)
3. ❌ **Leitura de Checkpoints:** Relayer tenta ler checkpoints do S3 (NÃO ACONTECE)
4. ❌ **Validação:** Verificar quorum de assinaturas (NÃO ACONTECE)
5. ❌ **Entrega:** Enviar mensagem para Terra Classic (NÃO ACONTECE)

### 3. Por Que Pool Está Vazio

O relayer só adiciona mensagens ao pool quando:
- ✅ Mensagem foi detectada (OK)
- ❌ Checkpoints estão disponíveis (FALHANDO)
- ❌ Quorum de assinaturas foi verificado (FALHANDO)

Como os validators não têm storage locations anunciadas, o relayer não consegue:
- Descobrir buckets S3 dos validators
- Ler checkpoints do S3
- Validar a mensagem
- Adicionar ao pool para entrega

## ✅ Solução

### Passo 1: Validators Precisam Anunciar Buckets S3 no BSC

**CORREÇÃO:** Os 3 validators do ISM precisam anunciar seus buckets S3 no **ValidatorAnnounce do BSC** (não do Terra Classic):

- Contrato BSC: `0xf09701B0a93210113D175461b6135a96773B5465`
- RPC: `https://bsc-testnet.publicnode.com`
- Função: `announce(address validator, string storageLocation)`

### Passo 2: Validators Precisam Gerar Checkpoints

Os validators precisam estar rodando e gerando checkpoints para mensagens do BSC.

### Passo 3: Verificar Quorum

Após anunciar buckets S3, verificar se pelo menos 2 de 3 validators estão gerando checkpoints (threshold do ISM é 2).

## 📊 Resumo

| Item | Status | Observação |
|------|--------|------------|
| Container rodando | ✅ | OK |
| Sincronização | ✅ | OK |
| Detecção de mensagens | ✅ | Mensagem 12768 detectada |
| Descoberta de validators | ❌ | Validators não têm S3 anunciado |
| Leitura de checkpoints | ❌ | Não acontece (sem S3) |
| Validação | ❌ | Não acontece (sem checkpoints) |
| Pool de mensagens | ❌ | Vazio (0 mensagens) |
| Entrega | ❌ | Não acontece |

## 🔗 Referências

- Script de diagnóstico: `diagnostico-relayer-bsc-terra.sh`
- Análise de validators: `resultado-validatorannounce-bsc.json`
- Problema identificado: `teste-relayer/PROBLEMA-IDENTIFICADO-BUCKETS-S3.md`
