# 🔍 Como Descobrir Buckets S3 dos Validators

## 📊 Problema

Precisamos descobrir:
1. **Se os validators estão criando checkpoints**
2. **Onde os checkpoints estão sendo armazenados (buckets S3)**
3. **Se os checkpoints estão acessíveis para o relayer**

## ✅ Solução: Consultar ValidatorAnnounce

Os buckets S3 dos validators estão armazenados no contrato **ValidatorAnnounce do BSC** através de eventos.

### Contrato ValidatorAnnounce

- **Endereço BSC Testnet:** `0xf09701B0a93210113D175461b6135a96773B5465`
- **Função:** `getAnnouncedValidators()` - Retorna lista de validators anunciados
- **Função:** `getAnnouncedStorageLocations(address)` - Retorna storage location de um validator
- **Evento:** `ValidatorAnnounce(address indexed validator, string storageLocation, string signature)`

## 🔧 Métodos para Obter Buckets S3

### Método 1: Via Função do Contrato (Recomendado)

```bash
# Para cada validator do ISM
cast call 0xf09701B0a93210113D175461b6135a96773B5465 \
  "getAnnouncedStorageLocations(address)" \
  0x242d8a855a8c932dec51f7999ae7d1e48b10c95e \
  --rpc-url https://bsc-testnet.publicnode.com
```

**Nota:** Esta função pode não estar funcionando corretamente em alguns casos.

### Método 2: Via Eventos do Contrato

```bash
# Consultar eventos do ValidatorAnnounce
cast logs \
  --from-block 86176000 \
  --to-block latest \
  --address 0xf09701B0a93210113D175461b6135a96773B5465 \
  --rpc-url https://bsc-testnet.publicnode.com | \
  grep -i "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"
```

Os eventos contêm a storage location (bucket S3) de cada validator.

### Método 3: Via Script Automatizado

```bash
# Script que consulta eventos e extrai buckets S3
./obter-buckets-s3-de-eventos.sh
```

## 📋 Validators do ISM

Os 3 validators configurados no ISM do Terra Classic para domain 97 (BSC):

1. `0x242d8a855a8c932dec51f7999ae7d1e48b10c95e`
2. `0xf620f5e3d25a3ae848fec74bccae5de3edcd8796`
3. `0x1f030345963c54ff8229720dd3a711c15c554aeb`

## 🔍 Verificar se Validators Estão Gerando Checkpoints

### 1. Verificar se Validators Estão Anunciados

```bash
./verificar-validators-anunciados-bsc.sh
```

### 2. Obter Buckets S3

```bash
./obter-buckets-s3-de-eventos.sh
```

### 3. Verificar Checkpoints no S3

Se você tiver AWS CLI configurado:

```bash
# Para cada bucket encontrado
aws s3 ls s3://BUCKET_NAME/ --recursive | grep "12768"
```

## 🎯 Formato dos Checkpoints

Os checkpoints geralmente seguem este formato:

```
s3://bucket-name/
  ├── checkpoint_12768_0xVALIDATOR_ADDRESS.json
  ├── checkpoint_12768_0xVALIDATOR_ADDRESS.json
  └── ...
```

Ou podem estar organizados por domain:

```
s3://bucket-name/
  ├── checkpoints/
  │   ├── 97/  (BSC Testnet)
  │   │   ├── checkpoint_12768.json
  │   │   └── ...
```

## 📊 Scripts Disponíveis

1. **`obter-buckets-s3-validators.sh`**
   - Consulta ValidatorAnnounce via função
   - Tenta obter storage locations
   - Verifica checkpoints no S3

2. **`obter-buckets-s3-de-eventos.sh`**
   - Consulta eventos do ValidatorAnnounce
   - Extrai storage locations dos eventos
   - Verifica checkpoints no S3

3. **`verificar-validators-anunciados-bsc.sh`**
   - Verifica se validators estão anunciados
   - Lista todos os validators anunciados

## ⚠️ Limitações

- RPC público pode ter limites de range de blocos
- Função `getAnnouncedStorageLocations` pode não funcionar
- Eventos podem estar em blocos antigos

## ✅ Próximos Passos

1. **Executar script para obter buckets:**
   ```bash
   ./obter-buckets-s3-de-eventos.sh
   ```

2. **Se não funcionar, consultar manualmente:**
   ```bash
   # Obter bloco atual
   cast block-number --rpc-url https://bsc-testnet.publicnode.com
   
   # Consultar eventos (ajustar range)
   cast logs --from-block 86180000 --to-block 86186634 \
     --address 0xf09701B0a93210113D175461b6135a96773B5465 \
     --rpc-url https://bsc-testnet.publicnode.com
   ```

3. **Verificar se validators estão gerando checkpoints:**
   - Verificar logs dos validators
   - Verificar se há arquivos no S3

4. **Verificar se relayer consegue ler checkpoints:**
   - Verificar credenciais AWS
   - Verificar permissões de leitura

## 🔗 Referências

- [ValidatorAnnounce Contract](https://github.com/hyperlane-xyz/hyperlane-monorepo)
- [Hyperlane Documentation](https://docs.hyperlane.xyz/)
