# 🔍 Problema: Relayer não enviando checkpoint_864656

## ✅ O que está funcionando:

1. **Relayer encontrou o checkpoint no S3** ✅
   - Conseguiu ler `checkpoint_864656_with_id.json` do bucket `hyperlane-validator-signatures-igorveras-sepolia`
   - Message ID: `0x93cb428f4bfd3fa2ccd552412b4e963f1dd7a9ac1bc702ce98c3c68dda9af860`

2. **Relayer construiu o metadata** ✅
   - Conseguiu verificar a assinatura do checkpoint
   - Construiu o metadata necessário para enviar a transação
   - Metadata: `0x0000000000000000000000004917a9746a7b6e0a57159ccb7f5a6744247f2d0dbfd3be54586c5c64edd0671bf1f58a98817305540cf954b657d140d1f4d24b3f000d319051844a23096bdd0efc715fcfcab32d506c9725241c9fab53fa88bac74b7c321158f2d54d86ceb0b8f96609570b6a6ae83851dd023c54786bebebaf64fa006ab41c`

3. **Relayer está tentando enviar para Terra Classic** ✅
   - Está chamando `process_estimate_costs` para Terra Classic
   - Está preparando a transação

## ❌ Problema identificado:

**Erro ao estimar custos:**
```
ABCI query failed: path=/cosmos.auth.v1beta1.Query/Account, 
code=22, log=rpc error: code = NotFound desc = 
account terra12awgqgwm2evj05ndtgs0xa35uunlpc76d85pze not found: key not found
```

### Causa:

A conta do relayer no Terra Classic (`terra12awgqgwm2evj05ndtgs0xa35uunlpc76d85pze`) **não existe** ou **não está acessível**.

## 🔧 Soluções:

### 1. Verificar se a chave privada está configurada:

```bash
# Verificar se a variável de ambiente está definida
docker exec hpl-relayer-testnet env | grep TERRACLASSIC.*SIGNER

# Verificar a configuração do relayer
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.chains.terraclassictestnet.signer'
```

### 2. Criar/fundar a conta no Terra Classic:

A conta precisa:
- Ser criada no Terra Classic testnet
- Ter fundos (uluna) para pagar gas
- A chave privada deve corresponder à conta

### 3. Verificar se a chave privada está correta:

A chave privada configurada em `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY` deve:
- Ser uma chave privada válida do Terra Classic
- Gerar o endereço `terra12awgqgwm2evj05ndtgs0xa35uunlpc76d85pze`
- OU você precisa usar a chave que corresponde a uma conta existente e fundada

## 📊 Status Atual:

- ✅ Checkpoint encontrado e lido do S3
- ✅ Metadata construído com sucesso
- ✅ Quorum atingido (threshold = 1, 1 assinatura encontrada)
- ❌ **Falha ao estimar custos** - conta não encontrada no Terra Classic

## 💡 Próximos Passos:

1. Verificar se `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY` está configurada
2. Verificar se a conta existe no Terra Classic testnet
3. Fundar a conta com uluna se necessário
4. Verificar se a chave privada corresponde à conta
