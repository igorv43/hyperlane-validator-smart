# 📝 Guia: Consultar ISM por Domínio

## 🎯 Funções Disponíveis nos Contratos

Baseado na análise dos contratos em `/home/lunc/hyperlane-monorepo/solidity/contracts/isms`, existem diferentes formas de consultar ISMs relacionados a um endereço:

## 1. DomainRoutingIsm

### Funções Disponíveis:

#### `domains()` - Listar todos os domínios configurados
```solidity
function domains() external view returns (uint256[] memory);
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "domains()" --rpc-url $RPC
```

**Retorna:** Array de domínios (uint256[])

#### `module(uint32 origin)` - Obter ISM para um domínio específico
```solidity
function module(uint32 origin) 
    public view virtual returns (IInterchainSecurityModule);
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "module(uint32)" 1325 --rpc-url $RPC
```

**Parâmetros:**
- `origin`: O domínio de origem (ex: 1325 para Terra Classic)

**Retorna:** Endereço do ISM para aquele domínio

### Exemplo Completo:

```bash
# 1. Listar domínios
DOMAINS=$(cast call 0xISM_ADDRESS "domains()" --rpc-url $RPC)

# 2. Para cada domínio, consultar o ISM
for domain in 1325 97 1399811150; do
    ISM=$(cast call 0xISM_ADDRESS "module(uint32)" "$domain" --rpc-url $RPC)
    echo "Domain $domain: $ISM"
done
```

## 2. StorageAggregationIsm

### Funções Disponíveis:

#### `modules()` - Listar todos os módulos ISM
```solidity
address[] public modules;
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "modules()" --rpc-url $RPC
```

**Retorna:** Array de endereços ISM

#### `threshold()` - Obter threshold
```solidity
uint8 public threshold;
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "threshold()" --rpc-url $RPC
```

#### `modulesAndThreshold(bytes)` - Obter módulos e threshold
```solidity
function modulesAndThreshold(bytes calldata _message) 
    public view override returns (address[] memory, uint8);
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "modulesAndThreshold(bytes)" "0x" --rpc-url $RPC
```

## 3. AbstractRoutingIsm

### Funções Disponíveis:

#### `route(bytes)` - Obter ISM para uma mensagem específica
```solidity
function route(bytes calldata _message) 
    public view virtual returns (IInterchainSecurityModule);
```

**Nota:** Esta função requer uma mensagem formatada do Hyperlane, não apenas um domínio.

## 4. AmountRoutingIsm (Warp Route)

### Funções Disponíveis:

#### `lower()` - ISM para valores abaixo do threshold
```solidity
address public immutable lower;
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "lower()" --rpc-url $RPC
```

#### `upper()` - ISM para valores acima do threshold
```solidity
address public immutable upper;
```

**Uso com cast:**
```bash
cast call 0xISM_ADDRESS "upper()" --rpc-url $RPC
```

#### `threshold()` - Threshold de valor
```solidity
uint256 public immutable threshold;
```

## 📋 Domínios Conhecidos

| Domínio | Nome | Descrição |
|---------|------|-----------|
| 1325 | Terra Classic | Terra Classic Testnet |
| 97 | BSC | Binance Smart Chain Testnet |
| 1399811150 | Solana | Solana Testnet |

## 🔧 Script de Consulta

O script `listar-isms-relacionados.sh` implementa todas essas consultas:

```bash
./listar-isms-relacionados.sh 0xISM_ADDRESS
```

### O que o script faz:

1. **Identifica o tipo do ISM** usando `moduleType()`
2. **Para Routing ISM (Type 1)**:
   - Tenta `domains()` para listar domínios
   - Para cada domínio, consulta `module(uint32)`
   - Tenta `module(uint32)` diretamente para domínios conhecidos
3. **Para Aggregation ISM (Type 2)**:
   - Consulta `modulesAndThreshold(bytes)`
   - Consulta `modules()` (se StorageAggregationIsm)
4. **Para outros tipos**:
   - Tenta `lowerIsm()` e `upperIsm()` (AmountRoutingIsm)
   - Tenta `validators()` (Multisig ISM)

## ⚠️ Limitações

### Para o ISM 0x2b31a08d397b7e508cbe0f5830e8a9182c88b6ca:

- **Tipo**: TREASURY (Type 5)
- **Funções testadas que não funcionaram**:
  - `domains()` - execution reverted
  - `module(uint32)` - execution reverted
  - `modules()` - execution reverted
  - `modulesAndThreshold(bytes)` - execution reverted
  - `lowerIsm()` / `upperIsm()` - execution reverted

### Possíveis Razões:

1. **TREASURY é um tipo terminal**: Não contém outros ISMs
2. **Tipo customizado**: Implementação específica que não segue padrões
3. **Estrutura interna**: ISM pode ter estrutura interna que não expõe funções públicas

## 🚀 Comandos Úteis

### Consultar ISM por domínio (DomainRoutingIsm):
```bash
ISM="0x2b31a08d397b7e508cbe0f5830e8a9182c88b6ca"
RPC="https://bsc-testnet.publicnode.com"

# Listar domínios
cast call "$ISM" "domains()" --rpc-url "$RPC"

# Consultar ISM para Terra Classic (1325)
cast call "$ISM" "module(uint32)" 1325 --rpc-url "$RPC"

# Consultar ISM para BSC (97)
cast call "$ISM" "module(uint32)" 97 --rpc-url "$RPC"

# Consultar ISM para Solana (1399811150)
cast call "$ISM" "module(uint32)" 1399811150 --rpc-url "$RPC"
```

### Consultar módulos (StorageAggregationIsm):
```bash
# Listar todos os módulos
cast call "$ISM" "modules()" --rpc-url "$RPC"

# Obter threshold
cast call "$ISM" "threshold()" --rpc-url "$RPC"

# Obter módulos e threshold
cast call "$ISM" "modulesAndThreshold(bytes)" "0x" --rpc-url "$RPC"
```

## 📚 Referências

- **DomainRoutingIsm**: `/home/lunc/hyperlane-monorepo/solidity/contracts/isms/routing/DomainRoutingIsm.sol`
- **StorageAggregationIsm**: `/home/lunc/hyperlane-monorepo/solidity/contracts/isms/aggregation/StorageAggregationIsm.sol`
- **AbstractRoutingIsm**: `/home/lunc/hyperlane-monorepo/solidity/contracts/isms/routing/AbstractRoutingIsm.sol`
- **AmountRoutingIsm**: `/home/lunc/hyperlane-monorepo/solidity/contracts/isms/warp-route/AmountRoutingIsm.sol`
