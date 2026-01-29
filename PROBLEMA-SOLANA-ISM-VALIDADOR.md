# 🐛 PROBLEMA: Validador Incorreto no ISM do Solana

Data: 2026-01-29  
Message ID: `0x654e15527433aa98f2aec1365aebabc38a38f7547ada4abd79b479457370ee57`

---

## 🔍 DIAGNÓSTICO

### Mensagem Detectada:
```
✅ Message ID: 0x654e15527433aa98f2aec1365aebabc38a38f7547ada4abd79b479457370ee57
✅ Nonce: 681
✅ Origin: solanatestnet → terraclassictestnet (1325)
✅ Sender: 0xf35ac96952cd5f87be0a99b173927e2fe0a814079ceb9ce8f5237f775fc940fa
✅ Recipient: 0x17f6fba8dcd0ef3962f3516e698583f57863032be8ca4f5058cdc8656c19120b
```

### ❌ Problema Identificado:

**ISM do Warp Solana está configurado com validador ERRADO:**

```
Validador no ISM:         0xd4ce8fa138d4e083fc0e480cca0dbfa4f5f30bd5
SEU validador (correto):  0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
Threshold:                1/1
```

---

## 🎯 CAUSA RAIZ

O mesmo problema que tivemos com BSC!

Quando você criou o warp route no Solana, o ISM foi configurado com um **validador público do Hyperlane** (`0xd4ce...`) ao invés do **SEU validador Terra Classic** (`0x8804...`).

### Por que falha:

1. Relayer detecta a mensagem ✅
2. Relayer consulta o ISM do destino (Terra Classic) ✅
3. ISM diz: "Preciso da assinatura do validador `0xd4ce...`" ✅
4. Relayer procura checkpoint desse validador ❌
5. Validador `0xd4ce...` NÃO está ativo/assinando ❌
6. Mensagem fica travada ❌

### Comparação:

| Chain | ISM Validator | Status |
|-------|---------------|--------|
| **Terra → BSC** | `0x8804...` (SEU) | ✅ Funciona |
| **Terra → Solana** | `0x8804...` (SEU) | ✅ Funciona |
| **BSC → Terra** | `0xd4ce...` (público) | ❌ NÃO funciona |
| **Solana → Terra** | `0xd4ce...` (público) | ❌ NÃO funciona |

---

## 💡 SOLUÇÃO

### Opção A: Reconfigurar ISM do Warp Solana (RECOMENDADO)

Atualizar o ISM do warp Solana para usar **SEU validador**:

```
Novo Validador: 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
S3 Bucket:      hyperlane-validator-signatures-igorverasvalidador-terraclassic
Threshold:      1/1
```

**Passos:**

1. Criar novo ISM no Solana com seu validador
2. Atualizar warp Solana com `setInterchainSecurityModule()`
3. Reenviar transações

### Opção B: Validador Público Ativo (NÃO POSSÍVEL)

Esperar que o validador público `0xd4ce...` volte a funcionar (improvável no testnet).

---

## 🔧 COMO CORRIGIR

### 1. Identificar o Warp Solana:

```bash
# Seu warp Solana
WARP_SOLANA="HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw"
MINT="3yhG9dDHVX6K1duf8znEcaJcuTiKSLYvfBD4xy6akxfu"
```

### 2. Consultar ISM Atual:

```bash
# Ver qual ISM está configurado
solana account $WARP_SOLANA --output json
```

### 3. Criar Novo ISM:

Você precisa criar um novo `StaticMessageIdMultisigIsm` no Solana que use:

```
Validators: ["0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0"]
Threshold: 1
```

### 4. Atualizar Warp:

Chamar função para atualizar o ISM do warp Solana.

---

## ⚠️ IMPORTANTE

### Mensagens Antigas:

A mensagem `0x654e1552...` NÃO será entregue porque:
- Foi assinada com expectativa do validador antigo (`0xd4ce...`)
- Esse validador não está ativo
- Mesmo mudando o ISM, a mensagem antiga ainda vai procurar esse validador

**Você precisará reenviar a transação após atualizar o ISM.**

### Mesmo Problema no BSC:

O BSC tem o MESMO problema:
- ISM: `0x2b31a08d397b7e508cbE0F5830E8a9182C88b6cA`
- Validators: Públicos do Hyperlane (inativos)

Ambos precisam ser atualizados para usar SEU validador.

---

## 📊 EVIDÊNCIA

### Log do Relayer:

```
INFO relayer::msg::metadata::multisig::base: List of validators and threshold for message
hyp_message: HyperlaneMessage { 
  id: 0x654e15527433aa98f2aec1365aebabc38a38f7547ada4abd79b479457370ee57,
  nonce: 681, 
  origin: solanatestnet, 
  destination: 1325
}
validators: [0x000000000000000000000000d4ce8fa138d4e083fc0e480cca0dbfa4f5f30bd5]
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                            ESTE validador NÃO é o seu!
threshold: 1
```

---

## 🎯 PRÓXIMOS PASSOS

### Imediato:
1. Verificar se o validador `0xd4ce...` está assinando (improvável)
2. Se não estiver, precisamos reconfigurar o ISM

### Correção:
1. Criar novo ISM no Solana com seu validador
2. Atualizar warp Solana
3. Reenviar transações Solana → Terra
4. Fazer o mesmo para BSC → Terra

---

**Status**: ❌ BLOQUEADO - ISM com validador inativo  
**Solução**: Reconfigurar ISM para usar seu validador ativo
