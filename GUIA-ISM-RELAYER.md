# 🔐 Guia: Configuração de ISM no Relayer Hyperlane

## 📋 Resumo

Este documento explica **onde e como** o ISM (Interchain Security Module) é configurado e usado no relayer do Hyperlane, especialmente para Warp Routes.

---

## 🎯 Conceitos Importantes

### O que é um ISM?

O **ISM (Interchain Security Module)** é um contrato que define **quem pode validar mensagens** entre chains. Ele especifica:
- Quais validators podem assinar checkpoints
- Quantos validators são necessários (threshold)
- Como as assinaturas são verificadas

### Tipos de ISM no Hyperlane

1. **ISM da Chain (Padrão)**: Configurado no `agent-config.json` para toda a chain
2. **ISM do Warp Route**: Configurado no contrato do Warp Route (específico por rota)

---

## 📁 Arquivos de Configuração do Relayer

### 1. `agent-config.docker-testnet.json`

**Localização**: `/home/lunc/hyperlane-validator-smart/hyperlane/agent-config.docker-testnet.json`

**Propósito**: Configuração das chains (BSC, Terra Classic, Solana)

**ISM Configurado** (linha 44):
```json
{
  "chains": {
    "bsctestnet": {
      "interchainSecurityModule": "0xe4245cCB6427Ba0DC483461bb72318f5DC34d090",
      // ... outros contratos
    }
  }
}
```

**⚠️ IMPORTANTE**: Este ISM é usado como **padrão para a chain BSC**, mas **NÃO é usado para Warp Routes específicos**.

---

### 2. `relayer.testnet.json`

**Localização**: `/home/lunc/hyperlane-validator-smart/hyperlane/relayer.testnet.json`

**Propósito**: Configuração específica do relayer (whitelist, chains, etc.)

**Conteúdo atual**:
```json
{
  "relayChains": "terraclassictestnet,bsctestnet,solanatestnet",
  "allowLocalCheckpointSyncers": "false",
  "gasPaymentEnforcement": [
    {
      "type": "none"
    }
  ],
  "whitelist": [
    {
      "originDomain": [1325],
      "destinationDomain": [97]
    },
    {
      "originDomain": [97],
      "destinationDomain": [1325]
    }
  ]
}
```

**✅ NÃO contém configuração de ISM** - O relayer consulta o ISM dinamicamente do contrato.

---

## 🔄 Como o Relayer Usa o ISM

### Fluxo de Processamento de Mensagens

```
1. Mensagem enviada no Warp Route (Terra Classic → BSC)
   ↓
2. Validator cria checkpoint e assina
   ↓
3. Relayer detecta a mensagem
   ↓
4. Relayer consulta o ISM do Warp Route dinamicamente
   ↓
5. Relayer verifica se o checkpoint tem assinaturas válidas
   ↓
6. Se válido, relayer entrega a mensagem no destino
```

### Consulta Dinâmica do ISM

O relayer **NÃO precisa** ter o ISM configurado manualmente. Ele consulta automaticamente:

```solidity
// O relayer chama esta função no contrato do Warp Route:
warpRoute.interchainSecurityModule()
```

**Resultado**: O relayer obtém o endereço do ISM atual do Warp Route.

---

## 🆕 Quando um Novo ISM é Configurado

### Cenário: Novo ISM para Warp Route

**Dados do novo ISM**:
```
Warp Route: 0x2144be4477202ba2d50c9a8be3181241878cf7d8
Novo ISM: 0x2b31a08d397b7e508cbe0f5830e8a9182c88b6ca
Domain: 1325 (Terra Classic)
Validators:
  - 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
Threshold: 1
```

### ✅ O que NÃO precisa ser alterado no Relayer

1. **`agent-config.docker-testnet.json`**: O ISM padrão da chain (`0xe4245cCB6427Ba0DC483461bb72318f5DC34d090`) continua o mesmo
2. **`relayer.testnet.json`**: Não contém configuração de ISM
3. **Docker Compose**: Nenhuma alteração necessária

### ⚠️ O que PRECISA ser feito

**O novo ISM deve ser configurado no contrato do Warp Route**, não no relayer!

O relayer consultará automaticamente o novo ISM quando processar mensagens deste Warp Route.

---

## 🔍 Verificando o ISM Atual do Warp Route

### Usando o script fornecido

```bash
./consultar-warp-ism-bsc.sh 0x2144be4477202ba2d50c9a8be3181241878cf7d8
```

**Saída esperada**:
```
✅ ISM encontrado: 0x2b31a08d397b7e508cbe0f5830e8a9182c88b6ca
✅ Tipo do ISM: MESSAGE_ID_MULTISIG (Type 5)
✅ Validators: 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
✅ Threshold: 1
```

### Usando cast (Foundry)

```bash
cast call 0x2144be4477202ba2d50c9a8be3181241878cf7d8 \
  "interchainSecurityModule()" \
  --rpc-url https://bsc-testnet.publicnode.com
```

---

## 📝 Resumo: Onde Alterar o ISM

### ❌ NÃO altere no Relayer

O relayer **não precisa** de configuração manual do ISM para Warp Routes. Ele consulta automaticamente o ISM do contrato.

### ✅ Altere no Contrato do Warp Route

O ISM é configurado **no contrato do Warp Route** na blockchain. Quando você atualiza o ISM do Warp Route:

1. O novo ISM é configurado no contrato (via transação)
2. O relayer consulta automaticamente o novo ISM
3. **Nenhuma alteração no código do relayer é necessária**

---

## 🔧 Configuração Atual vs. Novo ISM

### ISM Padrão da Chain BSC (agent-config.json)

```json
"interchainSecurityModule": "0xe4245cCB6427Ba0DC483461bb72318f5DC34d090"
```

**Uso**: ISM padrão para mensagens genéricas da chain BSC (não Warp Routes)

### Novo ISM do Warp Route

```
Novo ISM: 0x2b31a08d397b7e508cbe0f5830e8a9182c88b6ca
```

**Uso**: ISM específico para o Warp Route `0x2144be4477202ba2d50c9a8be3181241878cf7d8`

**⚠️ Estes são ISMs diferentes e independentes!**

---

## 🚀 Próximos Passos

1. **Verificar se o novo ISM está configurado no Warp Route**:
   ```bash
   ./consultar-warp-ism-bsc.sh 0x2144be4477202ba2d50c9a8be3181241878cf7d8
   ```

2. **Se o ISM ainda não foi atualizado no contrato**, use o script:
   ```bash
   ./alterar-validadores-ism-bsc-evm.sh
   ```

3. **Reiniciar o relayer** (se necessário):
   ```bash
   docker-compose -f docker-compose-testnet.yml restart relayer
   ```

4. **Monitorar logs do relayer**:
   ```bash
   docker-compose -f docker-compose-testnet.yml logs -f relayer
   ```

---

## 📚 Referências

- **Script de Consulta**: `consultar-warp-ism-bsc.sh`
- **Script de Alteração**: `alterar-validadores-ism-bsc-evm.sh`
- **Configuração do Relayer**: `hyperlane/relayer.testnet.json`
- **Configuração das Chains**: `hyperlane/agent-config.docker-testnet.json`

---

## ❓ FAQ

### P: Preciso alterar o `interchainSecurityModule` no `agent-config.json`?

**R**: Não! O ISM no `agent-config.json` é apenas o ISM padrão da chain. Para Warp Routes, o relayer consulta o ISM diretamente do contrato do Warp Route.

### P: O relayer precisa ser reiniciado quando o ISM muda?

**R**: Geralmente não, pois o relayer consulta o ISM dinamicamente. Mas se houver problemas, reiniciar pode ajudar.

### P: Como sei se o relayer está usando o novo ISM?

**R**: Verifique os logs do relayer. Ele consultará o ISM do Warp Route automaticamente quando processar mensagens.

---

**Última atualização**: 2025-01-23
