# 🎯 DESCOBERTA: Função Correta do Relayer

## ✅ FUNÇÃO CORRETA ENCONTRADA

Após analisar o código-fonte do relayer em `/home/lunc/hyperlane-monorepo/rust/main/agents/relayer`, descobri como o relayer realmente consulta as storage locations:

### 📋 Função Usada pelo Relayer

**Arquivo:** `rust/main/chains/hyperlane-ethereum/src/contracts/validator_announce.rs`

```rust
async fn get_announced_storage_locations(
    &self,
    validators: &[H256],
) -> ChainResult<Vec<Vec<String>>> {
    let storage_locations = self
        .contract
        .get_announced_storage_locations(
            validators.iter().map(|v| H160::from(*v).into()).collect(),
        )
        .call()
        .await?;
    Ok(storage_locations)
}
```

### 🔍 Interface do Contrato (Solidity)

**Arquivo:** `solidity/contracts/interfaces/IValidatorAnnounce.sol`

```solidity
function getAnnouncedStorageLocations(
    address[] calldata _validators
) external view returns (string[][] memory);
```

### ✅ Diferença Importante

- **Função correta:** `getAnnouncedStorageLocations(address[] calldata _validators)`
  - Aceita um **array de validators**
  - Retorna `string[][]` (array de arrays de strings)
  - Cada posição do array corresponde ao validator na mesma posição do input

- **Função que estávamos usando antes:** `getAnnouncedStorageLocations(address)`
  - Aceita um **único validator**
  - Esta função pode não existir ou ter comportamento diferente

## 🧪 Teste Realizado

```bash
# Consultar com array de validators (como relayer faz)
cast call "0xf09701B0a93210113D175461b6135a96773B5465" \
    "getAnnouncedStorageLocations(address[])" \
    "[0x242d8a855a8c932dec51f7999ae7d1e48b10c95e,0xf620f5e3d25a3ae848fec74bccae5de3edcd8796,0x1f030345963c54ff8229720dd3a711c15c554aeb]" \
    --rpc-url "https://bsc-testnet.publicnode.com"
```

### ✅ Resultado

Conseguimos decodificar e obter storage locations! A função funciona quando chamada com um array de validators.

## 📊 Próximos Passos

1. ✅ Verificar se os validators do ISM têm storage locations anunciadas
2. ✅ Verificar se há checkpoints nos buckets S3 encontrados
3. ✅ Confirmar se o relayer consegue ler esses checkpoints

## 📄 Arquivos Relacionados

- `consultar-storage-bsc-como-relayer.sh` - Script que usa a função correta
- `verificar-ism-validators-storage.sh` - Verifica validators do ISM
- `resultado-ism-validators-storage.json` - Resultado da verificação
