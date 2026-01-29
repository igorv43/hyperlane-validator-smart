# 🔧 SEPOLIA (ETH TESTNET) - Configuração

Data: 2026-01-29

---

## ✅ SEPOLIA ADICIONADO AO SISTEMA

### Informações da Rede:

```
Nome:         Sepolia
Chain ID:     11155111
Domain ID:    11155111
Protocol:     Ethereum
Native Token: ETH
```

---

## 📋 CONFIGURAÇÕES APLICADAS

### 1. agent-config.docker-testnet.json

```json
{
  "sepolia": {
    "chainId": 11155111,
    "domainId": 11155111,
    "name": "sepolia",
    "protocol": "ethereum",
    "displayName": "Sepolia",
    "rpcUrls": [
      {"http": "https://ethereum-sepolia.publicnode.com"},
      {"http": "https://gateway.tenderly.co/public/sepolia"},
      {"http": "https://sepolia.drpc.org"},
      {"http": "https://1rpc.io/sepolia"}
    ],
    "mailbox": "0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766",
    "interchainGasPaymaster": "0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56",
    "validatorAnnounce": "0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9",
    "merkleTreeHook": "0x4917a9746A7B6E0A57159cCb7F5a6744247f2d0d",
    "interchainSecurityModule": "0x81c12361c6f7024E6f67f7284B361Ed59003cFB1",
    "index": {
      "from": 1,
      "chunk": 10
    }
  }
}
```

### 2. relayer.testnet.json

```json
{
  "relayChains": "terraclassictestnet,bsctestnet,solanatestnet,sepolia",
  "chains": {
    "sepolia": {
      "signer": {
        "type": "hexKey",
        "key": ""
      }
    }
  },
  "whitelist": [
    {
      "originDomain": [1325],
      "destinationDomain": [11155111]
    },
    {
      "originDomain": [11155111],
      "destinationDomain": [1325]
    }
  ]
}
```

### 3. docker-compose-testnet.yml

Adicionado:
- `HYP_CHAINS_SEPOLIA_SIGNER_KEY` nas variáveis de ambiente
- Validação da chave Sepolia obrigatória
- AWK para injetar chave Sepolia no relayer

### 4. .env

```bash
# Sepolia (ETH Testnet)
HYP_CHAINS_SEPOLIA_SIGNER_KEY=
```

---

## 🔑 PRÓXIMOS PASSOS

### 1. Gerar Chave Privada Sepolia

```bash
# Usando cast (Foundry)
cast wallet new

# Ou usar MetaMask/qualquer wallet Ethereum
# Obter ETH de teste: https://sepoliafaucet.com/
```

### 2. Adicionar Chave ao .env

```bash
nano .env

# Adicionar a chave:
HYP_CHAINS_SEPOLIA_SIGNER_KEY=0x...
```

### 3. Obter ETH de Teste

Faucets disponíveis:
- https://sepoliafaucet.com/
- https://faucet.quicknode.com/ethereum/sepolia
- https://www.alchemy.com/faucets/ethereum-sepolia

### 4. Configurar Warp Route (se necessário)

Se você quiser enviar tokens Terra ↔ Sepolia, precisa criar um warp route no Sepolia que use **SEU validador Terra Classic**:

```
Validador: 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
S3 Bucket: hyperlane-validator-signatures-igorverasvalidador-terraclassic
Threshold: 1
```

### 5. Iniciar Relayer

```bash
docker-compose -f docker-compose-testnet.yml up -d
```

---

## 📊 ROTAS CONFIGURADAS

Após adicionar chave e iniciar:

| Route | Domain IDs | Status |
|-------|-----------|--------|
| **Terra → Sepolia** | 1325 → 11155111 | ⏳ Pendente (adicionar chave) |
| **Sepolia → Terra** | 11155111 → 1325 | ⏳ Pendente (adicionar chave) |

### Rotas Existentes (Funcionando):

| Route | Domain IDs | Status |
|-------|-----------|--------|
| Terra → BSC | 1325 → 97 | ✅ Funcionando |
| BSC → Terra | 97 → 1325 | ✅ Funcionando |
| Terra → Solana | 1325 → 1399811150 | ✅ Funcionando |
| Solana → Terra | 1399811150 → 1325 | ✅ Funcionando |

---

## 🔐 CONTRATOS HYPERLANE SEPOLIA

```
Mailbox:              0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766
IGP:                  0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56
ValidatorAnnounce:    0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9
MerkleTreeHook:       0x4917a9746A7B6E0A57159cCb7F5a6744247f2d0d
ISM:                  0x81c12361c6f7024E6f67f7284B361Ed59003cFB1
ProxyAdmin:           0x97Bbc6bBaFa5Ce3b2FA966c121Af63bD09e940f8
```

---

## ⚠️ IMPORTANTE

### Segurança:
- ✅ Chave Sepolia no `.env` (não commitada)
- ✅ Docker-compose injeta chave em runtime
- ✅ Arquivo `relayer.testnet.json` com chave vazia
- ✅ AWK atualizado para 4 chains

### ISM do Warp:
Se criar warp route Sepolia ↔ Terra, certifique-se de:
1. Configurar ISM com **SEU validador** (`0x8804...`)
2. **NÃO usar validadores públicos** (podem estar inativos)
3. Threshold: 1/1

### Gas:
- Sepolia usa EIP-1559 (maxFeePerGas, maxPriorityFeePerGas)
- Configuração já aplicada no agent-config:
  ```json
  "transactionOverrides": {
    "maxFeePerGas": 150000000000,
    "maxPriorityFeePerGas": 5000000000
  }
  ```

---

## 🚀 TESTE

Após configurar tudo:

```bash
# 1. Verificar que Sepolia foi adicionado
docker logs hpl-relayer-testnet -f | grep -i sepolia

# 2. Monitorar sincronização
docker logs hpl-relayer-testnet 2>&1 | grep "sepolia" | tail -20

# 3. Verificar whitelist
docker logs hpl-relayer-testnet 2>&1 | grep "Whitelist configuration"
```

---

## 📚 REFERÊNCIAS

- Sepolia Etherscan: https://sepolia.etherscan.io
- Sepolia Faucet: https://sepoliafaucet.com/
- Hyperlane Docs: https://docs.hyperlane.xyz/
- Foundry (cast): https://book.getfoundry.sh/

---

**Status**: ⏳ CONFIGURADO - Aguardando chave Sepolia no `.env`  
**Próximo**: Adicionar `HYP_CHAINS_SEPOLIA_SIGNER_KEY` e reiniciar
