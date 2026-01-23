# ✅ Nova Mensagem Detectada - Sequence 28

## 📊 Detalhes da Mensagem

**Data/Hora:** 2026-01-23 17:48:06 UTC

**Informações:**
- **Sequence:** 28
- **Bloco:** 29139683-29139684
- **Domain:** terraclassictestnet (1325)
- **tx_id:** `0x3850017cd079489f9b6bf8025b94144be02487f40993c42197c3c75006863462`
- **num_logs:** 1

## ✅ Status: Mensagem Detectada

O relayer **detectou e indexou** a mensagem:

```
INFO hyperlane_base::contract_sync: Found log(s) in index range, 
  range: 29139683..=29139684, 
  num_logs: 1, 
  sequences: [IndexedTxIdAndSequence { 
    tx_id: 0x3850017cd079489f9b6bf8025b94144be02487f40993c42197c3c75006863462, 
    sequence: Some(28) 
  }]

INFO hyperlane_base::contract_sync: Found log(s) for tx id, 
  num_logs: 1, 
  tx_id: 0x3850017cd079489f9b6bf8025b94144be02487f40993c42197c3c75006863462, 
  sequences: [Some(28)]
```

## ❌ Problema: Mensagem Não Está Sendo Processada

**Evidências:**
- **Pool size:** 0 (mensagem não está no pool aguardando retransmissão)
- **Nenhum log de processamento:** Não há logs de "processing message", "retry", ou "deliver"
- **Nenhum log de checkpoint:** Não há logs de leitura de checkpoints do S3

## 🔍 Causa Raiz

A mensagem foi **detectada**, mas o relayer **não consegue processá-la** porque:

1. **Relayer não está lendo checkpoints do S3**
   - Sem checkpoints, o relayer não pode validar a mensagem
   - Sem validação, a mensagem não pode ser retransmitida

2. **Validators não foram descobertos**
   - O relayer precisa descobrir validators através do ValidatorAnnounce
   - Sem validators descobertos, não há checkpoints para validar

## 📋 Checklist de Verificação

Execute estes comandos para diagnosticar:

```bash
# 1. Verificar se validator está gerando checkpoints
./query-validator-s3.sh list

# 2. Verificar se validator anunciou
./query-validator-s3.sh announcement

# 3. Verificar logs do relayer por checkpoints
docker logs hpl-relayer-testnet-local | grep -i "checkpoint\|s3\|validator.*announce" | tail -n 30

# 4. Verificar pool de mensagens
docker logs hpl-relayer-testnet-local | grep -i "pool_size" | tail -n 10

# 5. Monitorar logs em tempo real
docker logs -f hpl-relayer-testnet-local | grep -i "message\|pool\|checkpoint\|sequence.*28"
```

## 🎯 Próximos Passos

1. **Verificar se o validator está gerando checkpoints:**
   - Se não estiver, verificar logs do validator
   - Verificar se o validator está rodando

2. **Verificar se o validator anunciou:**
   - Se não anunciou, o relayer não consegue descobri-lo
   - Verificar se há `announcement.json` no S3

3. **Verificar credenciais AWS no relayer:**
   - Verificar se `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` estão configuradas
   - Verificar se o relayer tem permissões de leitura no bucket S3

4. **Aguardar alguns minutos:**
   - Às vezes o relayer leva alguns minutos para processar mensagens
   - Monitorar o pool_size para ver se aumenta

## 📊 Resumo

**Status:** ⚠️ Mensagem detectada, mas não processada

**Sequence:** 28

**Problema:** Relayer não está lendo checkpoints do S3, impedindo a validação e retransmissão da mensagem

**Ação necessária:** Verificar se o validator está gerando checkpoints e se o relayer tem acesso ao S3

---

**Data**: 2026-01-23 17:48:06 UTC
**Sequence**: 28
**Bloco**: 29139683-29139684
