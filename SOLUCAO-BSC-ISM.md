# 🔧 SOLUÇÃO: Reconfigurar ISM do Warp BSC

## 📋 PROBLEMA IDENTIFICADO

**Validadores públicos do Hyperlane não estão ativos no BSC testnet.**

### Evidências:
- ✅ Relayer detecta as mensagens BSC → Terra
- ❌ Mas não consegue alcançar quorum (2/3 validadores)
- ❌ Nenhum dos 3 validadores públicos fez announcements recentes:
  - `0x242d8a855a8c932dec51f7999ae7d1e48b10c95e`
  - `0xf620f5e3d25a3ae848fec74bccae5de3edcd8796`
  - `0x1f030345963c54ff8229720dd3a711c15c554aeb`

### Mensagens Afetadas:
- `0xab8c5e49de4c9961d357a011be45ad94f3b8e9ae910e8fc4c1fc0b63d5751833`
- `0xc3c2066f97831986ea864434541f3ef62abb9c059cbe091bab1c66e9e6d0ee98`

---

## 💡 SOLUÇÃO

**Reconfigurar o ISM do warp BSC para usar SEU validador Terra Classic.**

### Por que isso funciona?

Terra → BSC já funciona perfeitamente porque o ISM do Terra usa seu validador:
- ✅ Validador: `0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`
- ✅ S3: `hyperlane-validator-signatures-igorverasvalidador-terraclassic`
- ✅ Threshold: 1
- ✅ Validator está rodando e assinando checkpoints

Você precisa fazer o mesmo para BSC → Terra.

---

## 🛠️ PASSOS PARA CORRIGIR

### 1️⃣ Criar um novo ISM para o Warp BSC

Você precisa criar (deploy) um novo `StaticMessageIdMultisigIsm` no BSC que use **SEU validador**.

**Configuração do novo ISM:**
```solidity
validators: ["0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0"]
threshold: 1
```

### 2️⃣ Atualizar o Warp BSC com o novo ISM

Depois de criar o ISM, você precisa chamar a função `setInterchainSecurityModule()` no seu warp BSC:

```bash
# Endereço do warp BSC
WARP_BSC="0x2144Be4477202ba2d50c9A8be3181241878cf7D8"

# Novo ISM (você vai criar)
NEW_ISM="<endereço do novo ISM>"

# Atualizar o warp
cast send $WARP_BSC \
  "setInterchainSecurityModule(address)" \
  $NEW_ISM \
  --rpc-url https://bsc-testnet.publicnode.com \
  --private-key $YOUR_PRIVATE_KEY
```

### 3️⃣ Atualizar o agent-config.docker-testnet.json

Depois de atualizar o warp, atualize o arquivo de configuração:

```bash
# Atualizar ISM no agent-config
jq '.chains.bsctestnet.interchainSecurityModule = "<novo_ISM>"' \
  hyperlane/agent-config.docker-testnet.json > temp.json && \
  mv temp.json hyperlane/agent-config.docker-testnet.json

# Reiniciar relayer
docker-compose -f docker-compose-testnet.yml restart relayer
```

### 4️⃣ Reenviar as mensagens travadas

As mensagens antigas (`0xab8c5e49...` e `0xc3c2066f...`) não serão entregues porque foram assinadas com o ISM antigo.

**Você precisará enviar novas transações BSC → Terra.**

---

## 🎯 RESULTADO ESPERADO

Após essas mudanças:

✅ BSC → Terra funcionará como Terra → BSC funciona  
✅ Seu validador assinará os checkpoints para ambas as direções  
✅ Relayer conseguirá alcançar quorum (1/1)  
✅ Mensagens serão entregues imediatamente  

---

## 📚 REFERÊNCIA

**Como criar um StaticMessageIdMultisigIsm:**

1. Use o Hyperlane CLI:
```bash
hyperlane core deploy-ism
```

2. Ou use o Factory Contract:
```solidity
// StaticMessageIdMultisigIsmFactory no BSC testnet
address factory = 0x...; // Verifique no agent-config

// Deploy novo ISM
address newIsm = IStaticMessageIdMultisigIsmFactory(factory).deploy(
    [0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0], // validators
    1 // threshold
);
```

---

## ⚠️ IMPORTANTE

- As mensagens antigas (`0xab8c5e49...` e `0xc3c2066f...`) NÃO serão entregues
- Você precisará enviar novas transações após atualizar o ISM
- Certifique-se de que o validador Terra Classic continue rodando

---

## 📊 COMPARAÇÃO

### Antes (não funciona):
```
BSC → Terra: ISM com 3 validadores públicos inativos ❌
Threshold: 2/3
Resultado: Unable to reach quorum
```

### Depois (vai funcionar):
```
BSC → Terra: ISM com SEU validador ✅
Threshold: 1/1
Resultado: Mensagens entregues imediatamente
```

---

Data: 2026-01-29
Status: SOLUÇÃO IDENTIFICADA - Aguardando implementação
