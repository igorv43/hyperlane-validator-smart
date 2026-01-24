# 🎯 Problema Identificado: Buckets S3 dos Validators

## ✅ Descoberta Importante

### Validator Anunciado no Terra Classic

- **Validator:** `0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`
- **✅ Storage Location:** `s3://hyperlane-validator-signatures-igorverasvalidador-terraclassic/us-east-1`

### Validators do ISM

Os 3 validators configurados no ISM do Terra Classic para domain 97 (BSC):

1. `0x242d8a855a8c932dec51f7999ae7d1e48b10c95e`
   - **Storage locations:** `[]` (VAZIO) ❌

2. `0xf620f5e3d25a3ae848fec74bccae5de3edcd8796`
   - **Storage locations:** `[]` (VAZIO) ❌

3. `0x1f030345963c54ff8229720dd3a711c15c554aeb`
   - **Storage locations:** `[]` (VAZIO) ❌

## 🔍 Problema Identificado

**Os 3 validators do ISM NÃO estão anunciados no ValidatorAnnounce do Terra Classic!**

- ✅ Eles estão anunciados no ValidatorAnnounce do BSC
- ❌ Mas NÃO estão anunciados no ValidatorAnnounce do Terra Classic
- ❌ Não têm buckets S3 anunciados no Terra Classic

## 🎯 Por Que Isso É Um Problema

Para mensagens BSC -> Terra Classic:

1. **Validators do BSC** precisam gerar checkpoints
2. **Checkpoints** precisam estar em buckets S3 acessíveis
3. **Buckets S3** precisam estar anunciados no **ValidatorAnnounce do Terra Classic** (não do BSC!)
4. **Relayer** consulta o ValidatorAnnounce do Terra Classic para descobrir buckets S3
5. **Relayer** lê checkpoints do S3 e valida mensagens

**Como os validators do ISM não têm buckets S3 anunciados no Terra Classic, o relayer não consegue descobrir onde estão os checkpoints!**

## ✅ Solução

Os validators do ISM precisam anunciar seus buckets S3 no ValidatorAnnounce do Terra Classic.

### Contrato ValidatorAnnounce Terra Classic

- **Endereço:** `terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5`
- **Chain ID:** `rebel-2`
- **RPC:** `https://rpc.luncblaze.com:443`

### Como Anunciar

Cada validator precisa chamar a função `announce` no ValidatorAnnounce do Terra Classic:

```bash
# Exemplo (ajustar para cada validator)
terrad tx wasm execute terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5 \
  '{"announce": {"storage_location": "s3://bucket-name/prefix", "signature": "0x..."}}' \
  --chain-id rebel-2 \
  --node https://rpc.luncblaze.com:443 \
  --from validator-key \
  --gas auto \
  --gas-adjustment 1.5
```

## 📊 Resumo

- ✅ **1 validator** está anunciado no Terra Classic com bucket S3
- ❌ **3 validators do ISM** NÃO estão anunciados no Terra Classic
- ❌ **Nenhum dos validators do ISM** tem bucket S3 anunciado no Terra Classic

**Isso explica por que o relayer não está processando mensagens BSC -> Terra Classic!**

## 🔗 Referências

- Script: `consultar-buckets-s3-completo.sh`
- ValidatorAnnounce Terra Classic: `terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5`
