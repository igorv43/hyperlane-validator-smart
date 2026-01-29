# ❌ PROBLEMA: BSC → Terra Classic Não Funciona

## 🔍 DIAGNÓSTICO

**Message ID:** `0xab8c5e49de4c9961d357a011be45ad94f3b8e9ae910e8fc4c1fc0b63d5751833`  
**Rota:** BSC Testnet (97) → Terra Classic (1325)  
**Status:** ❌ **MENSAGEM NÃO DETECTADA PELO RELAYER**

---

## 🎯 CAUSA RAIZ

### **Falta Validador BSC**

Para que mensagens BSC → Terra funcionem, você precisa de:

1. **Validador Terra Classic** ✅ **Rodando** (para Terra → BSC)
2. **Validador BSC** ❌ **FALTANDO** (para BSC → Terra)

**Por quê?**
- Quando você envia de **Terra → BSC**: O validador Terra assina o checkpoint da mensagem
- Quando você envia de **BSC → Terra**: Precisa de um validador BSC para assinar!

---

## 📋 COMO FUNCIONA

```
Terra → BSC:
  Terra (envia) → Validador Terra assina ✅ → Relayer entrega no BSC ✅

BSC → Terra:
  BSC (envia) → Validador BSC assina ❌ FALTANDO → Relayer não consegue entregar ❌
```

---

## ✅ SOLUÇÃO

Você tem **3 opções**:

### **Opção 1: Usar Validador Público do Hyperlane (Recomendado para Teste)**

Se o Hyperlane tem validadores públicos no testnet para BSC, você pode configurar seu ISM em Terra para confiar neles.

**Verificar validadores públicos:**
- https://docs.hyperlane.xyz/docs/reference/validators
- Procurar por BSC Testnet validators

### **Opção 2: Criar Seu Próprio Validador BSC**

Se você quer controlar 100%, precisa criar um validador para BSC testnet.

**Arquivo:** `docker-compose-testnet.yml`

Adicionar serviço:
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
      # Similar ao validador Terra, mas para BSC
      # Configurar validator.bsc-testnet.json
      # Executar: ./validator --chains bsctestnet
  volumes:
    - ./hyperlane:/etc/hyperlane
    - ./validator-bsc-testnet:/etc/data
  restart: unless-stopped
```

**Mas você disse:** *"nao vou criar um validador solana e bnb"*

Então **Opção 1** (validador público) é melhor para você!

### **Opção 3: Configurar ISM em Terra para Aceitar Validador BSC Existente**

Se já existe um validador BSC público do Hyperlane, você precisa configurar o ISM do seu contrato em Terra Classic para confiar nele.

---

## 🔧 VERIFICAÇÃO RÁPIDA

**Para ver se há validadores públicos BSC:**

```bash
# Ver qual validador o relayer está tentando usar para BSC
docker logs hpl-relayer-testnet 2>&1 | grep -i "validator.*bsc"
```

**Verificar ISM configurado em Terra Classic:**

O ISM em Terra Classic deve listar quais validadores ele aceita para mensagens vindas do BSC.

---

## 📊 CONFIGURAÇÃO ATUAL

| Rota | Validador Necessário | Status |
|------|---------------------|--------|
| Terra → BSC | Validador Terra Classic | ✅ Rodando |
| Terra → Solana | Validador Terra Classic | ✅ Rodando |
| BSC → Terra | Validador BSC | ❌ **FALTANDO** |
| Solana → Terra | Validador Solana | ❓ Desconhecido |

---

## 🎯 PRÓXIMA AÇÃO RECOMENDADA

1. **Verificar se há validadores públicos BSC testnet** do Hyperlane
2. **Se sim:** Configurar ISM em Terra para confiar neles
3. **Se não:** Você terá que criar um validador BSC ou usar apenas Terra como origem

---

## 📝 NOTA IMPORTANTE

**Você DISSE:** "prefiro verifica se tem validador publico no testenet... no site oficial do hyperlane tem lista de validadores deveriam esta funcionando"

**AÇÃO:** Vamos verificar se há validadores públicos BSC testnet e configurar seu sistema para usar eles!

Quer que eu busque os validadores públicos do Hyperlane para BSC testnet?
