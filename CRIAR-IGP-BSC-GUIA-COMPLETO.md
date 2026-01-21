# 🚀 Guia Completo: Criar e Configurar IGP no BSC Testnet

## 📋 Visão Geral

Este guia explica como criar um novo IGP (Interchain Gas Paymaster) no BSC testnet, associá-lo ao Warp Route e configurar o Gas Oracle para Terra Classic. O processo segue a mesma lógica usada em Solana, mas adaptado para EVM chains.

## 🎯 Opções Disponíveis

O script `criar-igp-bsc-e-associar-warp-completo.sh` oferece duas opções:

### Opção 1: Criar Novo IGP e Associar ao Warp Route
- Cria um novo proxy IGP apontando para a implementação existente
- Inicializa o IGP com owner e beneficiary
- Configura o Gas Oracle para Terra Classic
- Associa o IGP ao Warp Route via `setHook(address)`

### Opção 2: Usar IGP Existente e Apenas Configurar Taxa de Gas
- Usa um IGP já criado
- Configura/atualiza apenas o Gas Oracle para Terra Classic
- Não modifica a associação com o Warp Route

## 📚 Conceitos Importantes

### Padrão de Proxy do Hyperlane

O Hyperlane usa um padrão de proxy onde:
- **Implementação**: O contrato IGP já está deployado (`0x795B9b7AA901C8B999b62B8c80299e79a5c96057`)
- **Proxy**: Cada usuário cria seu próprio proxy apontando para a implementação
- **Vantagem**: Não precisa fazer deploy completo, apenas instanciar um novo proxy

### IGP como Hook

Em Hyperlane, o IGP é configurado como um **hook** no Warp Route:
- **Solana**: `cargo run token igp set <IGP_PROGRAM_ID> igp <NEW_IGP_ACCOUNT>`
- **BSC (EVM)**: `setHook(address)` - mesma lógica!

### Gas Oracle

O Gas Oracle fornece:
- **token_exchange_rate**: Taxa de câmbio do token remoto para o token local
- **gas_price**: Preço do gas na chain remota

## 🔧 Pré-requisitos

1. **Foundry (cast)** instalado
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Chave privada BSC** ou **AWS KMS alias**
   - Chave privada: `export BSC_PRIVATE_KEY="0x..."`
   - KMS alias: `export BSC_KMS_ALIAS="alias/hyperlane-relayer-signer-bsc"`

3. **Monorepo Hyperlane compilado**
   - O bytecode do `TransparentUpgradeableProxy` precisa estar compilado
   - Localização: `~/hyperlane-monorepo/solidity/out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json`

## 📝 Endereços Conhecidos - BSC Testnet

| Contrato | Endereço | Descrição |
|----------|----------|-----------|
| **Proxy Admin** | `0xb12282d2E838Aa5f2A4F9Ee5f624a77b7199A078` | Administrador dos proxies |
| **IGP Implementation** | `0x795B9b7AA901C8B999b62B8c80299e79a5c96057` | Implementação do IGP |
| **IGP Padrão** | `0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949` | IGP padrão (proxy) |
| **StorageGasOracle** | `0x124EBCBC018A5D4Efe639f02ED86f95cdC3f6498` | Gas Oracle padrão |
| **Warp Route** | `0x2144Be4477202ba2d50c9A8be3181241878cf7D8` | Warp Route BSC |

## 🚀 Como Usar o Script

### Modo 1: Criar Novo IGP

```bash
export BSC_PRIVATE_KEY="0x819b680e3578eac4f79b8fde643046e88f3f9bb10a3ce1424e3642798ef39b42"
./criar-igp-bsc-e-associar-warp-completo.sh
# Escolha opção 1 quando solicitado
```

### Modo 2: Usar IGP Existente

```bash
export BSC_PRIVATE_KEY="0x819b680e3578eac4f79b8fde643046e88f3f9bb10a3ce1424e3642798ef39b42"
export USE_EXISTING_IGP="0xdfb118e0a9b4a4c523a2297f73a87b58e9795e6e"
export AUTO_CONFIRM=1
./criar-igp-bsc-e-associar-warp-completo.sh
```

### Modo Automático (Não Interativo)

```bash
export BSC_PRIVATE_KEY="0x819b680e3578eac4f79b8fde643046e88f3f9bb10a3ce1424e3642798ef39b42"
export AUTO_CONFIRM=1
export TOKEN_EXCHANGE_RATE=40000000000000000
export GAS_PRICE=1
export GAS_OVERHEAD=0
./criar-igp-bsc-e-associar-warp-completo.sh
```

## 📊 Processo Detalhado

### Passo 1: Criar Novo Proxy IGP

1. **Localizar bytecode do TransparentUpgradeableProxy**
   - Busca em: `~/hyperlane-monorepo/solidity/out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json`
   - Se não encontrar, tenta compilar automaticamente

2. **Preparar dados de inicialização**
   - Função: `initialize(address owner, address beneficiary)`
   - Owner e beneficiary: mesmo endereço (seu endereço)

3. **Deployar proxy**
   - Constructor: `constructor(address _logic, address admin_, bytes memory _data)`
   - `_logic`: `0x795B9b7AA901C8B999b62B8c80299e79a5c96057` (IGP Implementation)
   - `admin_`: `0xb12282d2E838Aa5f2A4F9Ee5f624a77b7199A078` (Proxy Admin)
   - `_data`: calldata do `initialize`

4. **Verificar inicialização**
   - Verifica se o owner está correto

### Passo 2: Configurar Gas Oracle

1. **Configurar destino Gas Config no IGP**
   - Função: `setDestinationGasConfigs((uint32,(address,uint96))[])`
   - Parâmetros:
     - `remoteDomain`: `1325` (Terra Classic)
     - `gasOracle`: `0x124EBCBC018A5D4Efe639f02ED86f95cdC3f6498` (StorageGasOracle)
     - `gasOverhead`: `0` (ou valor desejado)

2. **Configurar token_exchange_rate e gas_price**
   - Função: `setRemoteGasData((uint32,uint128,uint128))`
   - Parâmetros:
     - `remoteDomain`: `1325`
     - `tokenExchangeRate`: `40000000000000000`
     - `gasPrice`: `1`
   - **Nota**: Só funciona se você for o owner do StorageGasOracle

### Passo 3: Associar IGP ao Warp Route

1. **Verificar owner do Warp Route**
   - Confirma que você tem permissão para modificar

2. **Associar via setHook(address)**
   - Função: `setHook(address _hook)`
   - Parâmetro: endereço do novo IGP
   - **Esta é a mesma lógica usada em Solana!**

3. **Verificar associação**
   - Chama `hook()(address)` no Warp Route
   - Confirma que retorna o endereço do novo IGP

## 📋 Resultado da Execução

### ✅ Novo IGP Criado com Sucesso

```
📋 Resumo Final:
  ✅ Novo IGP Proxy: 0xdfb118e0a9b4a4c523a2297f73a87b58e9795e6e
  ✅ Implementation: 0x795B9b7AA901C8B999b62B8c80299e79a5c96057
  ✅ Owner: 0x8BD456605473ad4727ACfDCA0040a0dBD4be2DEA
  ✅ IGP associado ao Warp Route via setHook(address)
  ✅ Hook verificado: 0xdFb118e0a9B4a4c523A2297F73a87b58E9795E6E
  ✅ Gas Oracle configurado no IGP para Terra Classic (Domain 1325)
```

### ⚠️ Observação sobre StorageGasOracle

O StorageGasOracle padrão (`0x124EBCBC018A5D4Efe639f02ED86f95cdC3f6498`) não é seu (owner: `0xfaD1C94469700833717Fa8a3017278BC1cA8031C`).

Para configurar `token_exchange_rate` e `gas_price`, você precisa:

1. **Ser o owner do StorageGasOracle**, ou
2. **Criar seu próprio Gas Oracle contract**, ou
3. **Usar o Hyperlane CLI para configurar**

## 🔍 Verificações

### Verificar IGP Criado

```bash
# Verificar owner
cast call 0xdfb118e0a9b4a4c523a2297f73a87b58e9795e6e "owner()(address)" \
  --rpc-url https://bsc-testnet.publicnode.com

# Verificar implementation (via proxy)
cast call 0xdfb118e0a9b4a4c523a2297f73a87b58e9795e6e "implementation()(address)" \
  --rpc-url https://bsc-testnet.publicnode.com
```

### Verificar Hook no Warp Route

```bash
# Verificar hook configurado
cast call 0x2144Be4477202ba2d50c9A8be3181241878cf7D8 "hook()(address)" \
  --rpc-url https://bsc-testnet.publicnode.com
```

### Verificar Gas Oracle Configurado

```bash
# Verificar destino gas config no IGP
cast call 0xdfb118e0a9b4a4c523a2297f73a87b58e9795e6e \
  "destinationGasConfigs(uint32)(address,uint96)" 1325 \
  --rpc-url https://bsc-testnet.publicnode.com
```

## 🆚 Comparação: Solana vs BSC

| Ação | Solana | BSC (EVM) |
|------|--------|-----------|
| **Criar IGP** | `cargo run igp init-igp-account` | Deploy proxy via `cast send --create` |
| **Configurar Gas Oracle** | `cargo run igp gas-oracle-config set` | `setDestinationGasConfigs` + `setRemoteGasData` |
| **Associar ao Warp Route** | `cargo run token igp set ... igp ...` | `setHook(address)` |
| **Lógica** | ✅ Mesma lógica | ✅ Mesma lógica |

## 🔧 Comandos Manuais

Se precisar executar manualmente:

### Criar Proxy IGP

```bash
# 1. Obter bytecode
PROXY_BYTECODE=$(jq -r '.bytecode.object' \
  ~/hyperlane-monorepo/solidity/out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json)

# 2. Preparar initialize calldata
INIT_CALLDATA=$(cast calldata "initialize(address,address)" \
  "$OWNER_ADDRESS" "$OWNER_ADDRESS")

# 3. Deployar proxy
cast send --rpc-url "$BSC_RPC" --private-key "$BSC_PRIVATE_KEY" \
  --create "${PROXY_BYTECODE}${INIT_CALLDATA#0x}"
```

### Configurar Gas Oracle

```bash
# 1. Configurar destino gas config
cast send "$NEW_IGP" \
  "setDestinationGasConfigs((uint32,(address,uint96))[])" \
  "[(1325,(0x124EBCBC018A5D4Efe639f02ED86f95cdC3f6498,0))]" \
  --rpc-url "$BSC_RPC" --private-key "$BSC_PRIVATE_KEY"

# 2. Configurar token_exchange_rate e gas_price (se for owner)
cast send "$STORAGE_GAS_ORACLE" \
  "setRemoteGasData((uint32,uint128,uint128))" \
  "(1325,40000000000000000,1)" \
  --rpc-url "$BSC_RPC" --private-key "$BSC_PRIVATE_KEY"
```

### Associar ao Warp Route

```bash
# Associar IGP como hook
cast send "$WARP_ROUTE_BSC" \
  "setHook(address)" "$NEW_IGP" \
  --rpc-url "$BSC_RPC" --private-key "$BSC_PRIVATE_KEY"
```

## 📊 Parâmetros do Gas Oracle

### Terra Classic

- **Token Exchange Rate**: `40000000000000000` (0.04 BNB por LUNC)
- **Gas Price**: `1`
- **Token Decimals**: `6`
- **Cálculo**: Para 200k gas = 800 LUNC

### Como Calcular

```
token_exchange_rate = (exchange_rate * 10^18) / 10^token_decimals
token_exchange_rate = (40000000000000 * 10^18) / 10^6
token_exchange_rate = 40000000000000000
```

## ⚠️ Troubleshooting

### Erro: Bytecode não encontrado

```bash
# Compilar TransparentUpgradeableProxy
cd ~/hyperlane-monorepo/solidity
forge build dependencies/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol --skip test
```

### Erro: Owner não corresponde

- Verifique se a chave privada está correta
- Verifique se você é o owner do Warp Route

### Erro: StorageGasOracle não é seu

- Use o StorageGasOracle padrão (já configurado)
- Ou crie seu próprio Gas Oracle contract
- Ou use o Hyperlane CLI para configurar

## 📚 Referências

- **Hyperlane Docs**: https://docs.hyperlane.xyz
- **OpenZeppelin Proxy Pattern**: https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies
- **BSC Testnet Explorer**: https://testnet.bscscan.com

## 🎉 Conclusão

O processo de criar e configurar um IGP no BSC segue a mesma lógica do Solana:
- ✅ Criar instância do IGP (proxy em BSC, account em Solana)
- ✅ Configurar Gas Oracle
- ✅ Associar ao Warp Route (hook em ambos)

A principal diferença é que em BSC usamos `setHook(address)` diretamente, enquanto em Solana usamos o comando `cargo run token igp set`.

---

**Última atualização**: 2025-01-21
**Script**: `criar-igp-bsc-e-associar-warp-completo.sh`
**Autor**: Hyperlane Validator Setup
