# 🔍 Problema: BSC -> Terra Classic não chega

## 📊 Análise dos Logs

### ✅ Mensagem Detectada no BSC

```
Found log(s) in index range, range: 86175955..=86175965, num_logs: 1
sequences: [IndexedTxIdAndSequence { 
  tx_id: 0x5f0b84899319d435b77e064b1b50beb437e557c5b9101e9fca03d1b11930c147, 
  sequence: Some(12768) 
}]
```

**Status:** ✅ O relayer detectou a mensagem com sequence 12768 no BSC.

### ❌ Mensagem Não Processada

```
Processing transactions in finality pool, pool_size: 0
```

**Status:** ❌ A mensagem foi detectada, mas não está no pool de finalização para ser processada.

---

## 🔍 Causa Raiz

### Como o Hyperlane Funciona

Para uma mensagem ser retransmitida de BSC → Terra Classic, o relayer precisa:

1. ✅ **Detectar a mensagem no BSC** (FEITO - sequence 12768 detectada)
2. ❌ **Validar a mensagem usando checkpoints do VALIDATOR DO BSC** (FALTANDO)
3. ❌ **Retransmitir para Terra Classic** (não consegue porque não valida)

### Problema Identificado

**Você só tem um validator do Terra Classic rodando!**

- ✅ `validator-terraclassic` → Valida mensagens do Terra Classic → BSC funciona
- ❌ **Não há validator do BSC** → Não valida mensagens do BSC → BSC → Terra Classic não funciona

### Arquitetura Atual

```
┌─────────────────┐
│ Terra Classic   │
│   (Origin)      │
└────────┬────────┘
         │
         │ Mensagem enviada
         ↓
┌─────────────────┐
│ Validator       │ ✅ Existe
│ Terra Classic   │
└────────┬────────┘
         │
         │ Gera checkpoint
         ↓
┌─────────────────┐
│   AWS S3        │
│  (Checkpoints)  │
└────────┬────────┘
         │
         │ Relayer lê checkpoint
         ↓
┌─────────────────┐
│    Relayer      │
└────────┬────────┘
         │
         │ Valida e retransmite
         ↓
┌─────────────────┐
│      BSC        │ ✅ FUNCIONA
│  (Destination)  │
└─────────────────┘
```

### Problema: BSC → Terra Classic

```
┌─────────────────┐
│      BSC        │
│   (Origin)      │
└────────┬────────┘
         │
         │ Mensagem enviada
         ↓
┌─────────────────┐
│ Validator       │ ❌ NÃO EXISTE!
│      BSC        │
└─────────────────┘
         │
         │ Sem checkpoint
         ↓
┌─────────────────┐
│   AWS S3        │ ❌ Sem checkpoints do BSC
│  (Checkpoints)  │
└────────┬────────┘
         │
         │ Relayer não consegue validar
         ↓
┌─────────────────┐
│    Relayer      │ ❌ Não processa
└────────┬────────┘
         │
         │ Não valida (sem checkpoint)
         ↓
┌─────────────────┐
│ Terra Classic   │ ❌ NÃO CHEGA
│  (Destination)  │
└─────────────────┘
```

---

## ✅ Solução

### Opção 1: Adicionar Validator do BSC (Recomendado)

Adicione um validator do BSC ao `docker-compose-testnet.yml`:

```yaml
validator-bsc:
  container_name: hpl-validator-bsc-testnet
  image: gcr.io/abacus-labs-dev/hyperlane-agent:1.7.0
  user: root
  entrypoint: ['sh', '-c']
  environment:
    - RUST_LOG=debug,hyperlane=debug,validator=debug
    - HYP_BASE_TRACING_LEVEL=debug
    - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    - AWS_REGION=${AWS_REGION:-us-east-1}
    - HYP_DB=${HYP_DB:-/etc/data/db}
    - HYP_CHECKPOINT_SYNCER_BUCKET=${HYP_CHECKPOINT_SYNCER_BUCKET_BSC}
    - HYP_CHECKPOINT_SYNCER_REGION=${HYP_CHECKPOINT_SYNCER_REGION}
    - HYP_VALIDATOR_KEY=${HYP_VALIDATOR_KEY_BSC}
    - HYP_CHAINS_BSCTESTNET_SIGNER_KEY=${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}
  command:
    - |
      rm -rf /app/config/* && \
      cp "/etc/hyperlane/agent-config.docker-testnet.json" "/app/config/agent-config.json" && \
      if [ -z "${HYP_VALIDATOR_KEY_BSC}" ] || [ "${HYP_VALIDATOR_KEY_BSC}" = "" ]; then \
        echo "ERROR: HYP_VALIDATOR_KEY_BSC is required!" && \
        exit 1; \
      fi && \
      DB_PATH="${HYP_DB:-/etc/data/db}" && \
      BUCKET="${HYP_CHECKPOINT_SYNCER_BUCKET_BSC}" && \
      REGION_VAL="${HYP_CHECKPOINT_SYNCER_REGION:-${AWS_REGION:-us-east-1}}" && \
      VALIDATOR_KEY="${HYP_VALIDATOR_KEY_BSC}" && \
      SIGNER_KEY="${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" && \
      printf '{\n  "db": "%s",\n  "checkpointSyncer": {\n    "type": "s3",\n    "bucket": "%s",\n    "region": "%s"\n  },\n  "originChainName": "bsctestnet",\n  "validator": {\n    "type": "hexKey",\n    "key": "%s"\n  },\n  "chains": {\n    "bsctestnet": {\n      "signer": {\n        "type": "hexKey",\n        "key": "%s"\n      }\n    }\n  }\n}' \
        "$$DB_PATH" \
        "$$BUCKET" \
        "$$REGION_VAL" \
        "$$VALIDATOR_KEY" \
        "$$SIGNER_KEY" > "/etc/hyperlane/validator.bsc-testnet.json" && \
      CONFIG_FILES="/etc/hyperlane/validator.bsc-testnet.json" \
        ./validator --metrics 0.0.0.0:9090
  ports:
    - "19030:9090"
  volumes:
    - ./hyperlane:/etc/hyperlane
    - ./validator-bsc-testnet:/etc/data
  restart: unless-stopped
```

**Variáveis necessárias no Easypanel:**
- `HYP_VALIDATOR_KEY_BSC` - Chave privada do validator do BSC
- `HYP_CHECKPOINT_SYNCER_BUCKET_BSC` - Bucket S3 para checkpoints do BSC
- `HYP_CHAINS_BSCTESTNET_SIGNER_KEY` - Já existe (usado pelo relayer)

### Opção 2: Usar Validator Público do BSC (Se disponível)

Se houver validators públicos do BSC anunciados no contrato ValidatorAnnounce, o relayer pode descobri-los automaticamente. Verifique se há validators públicos:

```bash
# Consultar ValidatorAnnounce no BSC
cast call 0xf09701B0a93210113D175461b6135a96773B5465 \
  "getAnnouncedValidators()" \
  --rpc-url https://bsc-testnet.publicnode.com
```

---

## 📋 Checklist de Verificação

- [ ] Verificar se há validators do BSC anunciados no ValidatorAnnounce
- [ ] Se não houver, adicionar validator do BSC ao docker-compose
- [ ] Configurar variáveis de ambiente no Easypanel
- [ ] Criar bucket S3 para checkpoints do BSC (ou usar o mesmo bucket)
- [ ] Gerar chave privada do validator do BSC
- [ ] Reiniciar containers
- [ ] Testar envio BSC → Terra Classic novamente

---

## 🔗 Referências

- [Arquitetura S3](./ARCHITECTURE-S3.md)
- [Guia AWS S3](../GUIDE-AWS-S3-AND-KEYS.md)
