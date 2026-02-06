# 🔍 Análise do Código-Fonte: Problema com Sepolia

## 📋 Resumo do Problema

O relayer **não está conseguindo encontrar checkpoints de Sepolia** no S3, mesmo que:
- ✅ O checkpoint existe no S3 (`checkpoint_864656_with_id.json`)
- ✅ O checkpoint contém o message_id correto
- ✅ O validador está anunciado
- ✅ Solana funciona perfeitamente (prova que o relayer está OK)

## 🔍 Análise do Código-Fonte

### 1. Como o Relayer Busca Checkpoints

**Arquivo**: `/home/lunc/hyperlane-monorepo/rust/main/agents/relayer/src/msg/metadata/multisig/message_id_multisig.rs`

```rust
// Linha 40-50: Obtém o leaf_index a partir do message_id
let leaf_index = unwrap_or_none_result!(
    self.base_builder()
        .get_merkle_leaf_id_by_message_id(message_id)
        .await
        .map_err(|err| MetadataBuildError::FailedToBuild(err.to_string()))?,
    // ...
);

// Linha 61-67: Busca o checkpoint usando o leaf_index
let quorum_checkpoint = unwrap_or_none_result!(
    checkpoint_syncer
        .fetch_checkpoint(validators, threshold as usize, leaf_index)
        .await
        .map_err(|err| MetadataBuildError::FailedToBuild(err.to_string()))?,
    // ...
);
```

**Problema identificado**: O relayer busca checkpoints usando o `leaf_index` obtido do Merkle Tree, **não diretamente pelo message_id**.

### 2. Como o S3Storage Busca Checkpoints

**Arquivo**: `/home/lunc/hyperlane-monorepo/rust/main/hyperlane-base/src/types/s3_storage.rs`

```rust
// Linha 189-190: Formato do arquivo no S3
fn checkpoint_key(index: u32) -> String {
    format!("checkpoint_{index}_with_id.json")
}

// Linha 240-246: Busca checkpoint por índice
async fn fetch_checkpoint(&self, index: u32) -> Result<Option<SignedCheckpointWithMessageId>> {
    self.anonymously_read_from_bucket(S3Storage::checkpoint_key(index))
        .await?
        .map(|data| serde_json::from_slice(&data))
        .transpose()
        .map_err(Into::into)
}
```

**Problema identificado**: O S3Storage busca checkpoints pelo **índice** (formato `checkpoint_{index}_with_id.json`), não pelo message_id.

### 3. Como o MultisigCheckpointSyncer Funciona

**Arquivo**: `/home/lunc/hyperlane-monorepo/rust/main/hyperlane-base/src/types/multisig.rs`

```rust
// Linha 166-271: fetch_checkpoint busca por índice
pub async fn fetch_checkpoint(
    &self,
    validators: &[H256],
    threshold: usize,
    index: u32,  // ← Usa o índice, não o message_id
) -> Result<Option<MultisigSignedCheckpoint>> {
    // ...
    for validators in validators.chunks(batch_size) {
        let futures = validators
            .iter()
            .filter_map(|address| {
                if let Some(syncer) = self.checkpoint_syncers.get(&H160::from(*address)) {
                    Some((address, syncer))
                } else {
                    debug!(validator=%address, "Checkpoint syncer not found");
                    None
                }
            })
            .map(|(address, syncer)| {
                let checkpoint_syncer = syncer.clone();
                async move { 
                    (address, checkpoint_syncer.fetch_checkpoint(index).await)  // ← Busca pelo índice
                }
            })
            .collect::<Vec<_>>();
        // ...
    }
}
```

**Problema identificado**: O `MultisigCheckpointSyncer` busca checkpoints pelo **índice** fornecido, que deve corresponder ao `leaf_index` do Merkle Tree.

## 🎯 Problema Raiz Identificado

### O Problema

O relayer busca checkpoints usando o **`leaf_index`** obtido do Merkle Tree através de `get_merkle_leaf_id_by_message_id(message_id)`. 

**Fluxo esperado:**
1. Relayer obtém `message_id` da mensagem
2. Relayer chama `get_merkle_leaf_id_by_message_id(message_id)` para obter o `leaf_index`
3. Relayer busca checkpoint no S3 usando `checkpoint_{leaf_index}_with_id.json`
4. Relayer verifica se o checkpoint contém o `message_id` correto

**Problema real:**
- O checkpoint no S3 está salvo como `checkpoint_864656_with_id.json` (índice 864656)
- Mas o `leaf_index` obtido do Merkle Tree pode ser **diferente** de 864656
- Isso faz com que o relayer busque por um índice que não existe no S3

### Por que Solana Funciona?

Solana provavelmente tem uma correspondência correta entre:
- O `leaf_index` do Merkle Tree
- O índice do checkpoint no S3

Ou o validador de Solana está gerando checkpoints com índices que correspondem aos `leaf_index` do Merkle Tree.

### Por que Sepolia Não Funciona?

Sepolia pode ter uma **incompatibilidade** entre:
- O `leaf_index` calculado pelo relayer
- O índice do checkpoint gerado pelo validador

**Possíveis causas:**
1. O validador de Sepolia está gerando checkpoints com índices que não correspondem aos `leaf_index` do Merkle Tree
2. O relayer está calculando o `leaf_index` incorretamente para Sepolia
3. Há uma diferença na forma como o Merkle Tree é construído para Sepolia vs Solana

## 🔧 Soluções Possíveis

### Solução 1: Verificar o leaf_index Calculado

Verificar se o `leaf_index` calculado pelo relayer corresponde ao índice do checkpoint no S3:

```bash
# Verificar qual leaf_index o relayer está buscando
docker logs hpl-relayer-testnet --tail 10000 | grep -i "leaf_index\|get_merkle_leaf_id"
```

### Solução 2: Verificar se o Checkpoint no S3 tem o Índice Correto

O checkpoint `checkpoint_864656_with_id.json` deve ter:
- `index: 864656` no JSON
- `message_id` correto

Verificar:
```bash
curl -s "https://hyperlane-validator-signatures-igorveras-sepolia.s3.us-east-1.amazonaws.com/checkpoint_864656_with_id.json" | jq '.value.checkpoint.index'
```

### Solução 3: Verificar se há Diferença entre EVM e Solana

Pode haver uma diferença na forma como o Merkle Tree é construído para EVM (Sepolia) vs Solana. Verificar:
- Como o `leaf_index` é calculado para Sepolia
- Como o validador gera o índice do checkpoint para Sepolia

### Solução 4: Modificar o Código para Buscar por Message ID

Se o problema persistir, pode ser necessário modificar o código para buscar checkpoints diretamente pelo `message_id`, em vez de usar o `leaf_index`. Isso exigiria:
1. Listar todos os checkpoints no S3
2. Filtrar pelo `message_id` dentro de cada checkpoint
3. Usar o checkpoint encontrado

**Arquivo a modificar**: `/home/lunc/hyperlane-monorepo/rust/main/hyperlane-base/src/types/multisig.rs`

## 📊 Próximos Passos

1. ✅ **Verificar o leaf_index calculado pelo relayer**
   ```bash
   docker logs hpl-relayer-testnet --tail 50000 | grep -B 5 -A 5 "0x93cb428f4bfd3fa2ccd552412b4e963f1dd7a9ac1bc702ce98c3c68dda9af860" | grep -i "leaf"
   ```

2. ✅ **Verificar o índice do checkpoint no S3**
   ```bash
   curl -s "https://hyperlane-validator-signatures-igorveras-sepolia.s3.us-east-1.amazonaws.com/checkpoint_864656_with_id.json" | jq '{index: .value.checkpoint.index, message_id: .value.message_id}'
   ```

3. ✅ **Comparar com Solana**
   - Verificar como Solana calcula o `leaf_index`
   - Verificar se há diferenças na implementação

4. ✅ **Verificar logs do relayer para entender o que está acontecendo**
   ```bash
   docker logs hpl-relayer-testnet --tail 50000 | grep -i -E "(leaf_index|get_merkle_leaf_id|fetch_checkpoint|864656)" | head -30
   ```

## 🔍 Código Relevante

### Arquivos Principais

1. **`message_id_multisig.rs`** (linha 33-88)
   - Busca metadata usando `leaf_index`
   - Verifica se o checkpoint tem o `message_id` correto

2. **`multisig.rs`** (linha 166-271)
   - `fetch_checkpoint`: Busca checkpoint por índice
   - Itera através dos validadores
   - Verifica assinaturas e atinge quorum

3. **`s3_storage.rs`** (linha 189-246)
   - `checkpoint_key`: Formato `checkpoint_{index}_with_id.json`
   - `fetch_checkpoint`: Busca checkpoint por índice no S3

### Pontos Críticos

1. **Linha 63** de `message_id_multisig.rs`: 
   ```rust
   checkpoint_syncer.fetch_checkpoint(validators, threshold as usize, leaf_index)
   ```
   - Usa `leaf_index` para buscar checkpoint

2. **Linha 69-80** de `message_id_multisig.rs`:
   ```rust
   if quorum_checkpoint.checkpoint.message_id != message_id {
       warn!("Quorum checkpoint message id {} does not match message id {}", ...);
       return Ok(None);
   }
   ```
   - Verifica se o checkpoint tem o `message_id` correto
   - Se não corresponder, retorna `None`

3. **Linha 200** de `multisig.rs`:
   ```rust
   async move { (address, checkpoint_syncer.fetch_checkpoint(index).await) }
   ```
   - Busca checkpoint pelo índice fornecido

## ✅ Conclusão

O problema está na **correspondência entre o `leaf_index` calculado pelo relayer e o índice do checkpoint no S3**. 

O relayer busca checkpoints usando o `leaf_index` do Merkle Tree, mas o checkpoint no S3 pode ter um índice diferente. Isso faz com que o relayer não encontre o checkpoint, mesmo que ele exista no S3.

**Próximo passo**: Verificar se o `leaf_index` calculado pelo relayer corresponde ao índice 864656 do checkpoint no S3.
