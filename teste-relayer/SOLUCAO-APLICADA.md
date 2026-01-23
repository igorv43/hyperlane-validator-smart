# ✅ Solução Aplicada

## 🔍 Problema Identificado

O relayer estava falhando com os seguintes erros:

```
ERROR hyperlane_base::settings::signers: error: HexKey { 
  key: 0xa512... 
} key is not supported by cosmos

ERROR relayer::relayer: Critical error when building chain as origin, 
  err: ValidatorAnnounce("terraclassictestnet", "Building validator announce")

ERROR relayer::relayer: Critical error when building chain as origin, 
  err: MissingConfiguration("terraclassictestnet")
```

## 🔧 Correções Aplicadas

### 1. Adicionada Seção `chains` no `relayer.testnet.json`

O arquivo `relayer.testnet.json` não tinha a seção `chains` com as configurações dos signers. Foi adicionada:

```json
{
  "chains": {
    "bsctestnet": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE"
      }
    },
    "solanatestnet": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE"
      }
    },
    "terraclassictestnet": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE",
        "prefix": "terra"
      }
    }
  }
}
```

### 2. Atualizado `docker-compose-testnet.yml` para Substituir Chaves

Adicionado script para substituir os placeholders `0xYOUR_PRIVATE_KEY_HERE` pelas variáveis de ambiente:

```bash
if [ -n "${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" ]; then
  sed -i "s|\"0xYOUR_PRIVATE_KEY_HERE\"|\"${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json"
  sed -i "s|\"0xYOUR_PRIVATE_KEY_BSC\"|\"${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json"
fi
# ... similar para Solana e Terra Classic
```

## 📋 Arquivos Modificados

1. **`hyperlane/relayer.testnet.json`**
   - Adicionada seção `chains` com configuração dos signers
   - Placeholders `0xYOUR_PRIVATE_KEY_HERE` para substituição

2. **`docker-compose-testnet.yml`**
   - Adicionado script para substituir placeholders pelas variáveis de ambiente
   - Substituição para BSC, Solana e Terra Classic

## 🚀 Como Funciona Agora

1. O `relayer.testnet.json` tem a estrutura `chains` com placeholders
2. O docker-compose substitui os placeholders pelas variáveis de ambiente do `.env`
3. O relayer lê o JSON com as chaves já substituídas
4. O relayer consegue configurar o Terra Classic corretamente

## ⚠️ Nota sobre o Erro "key is not supported by cosmos"

O erro `HexKey { key: 0xa512... } key is not supported by cosmos` pode indicar que:

1. A chave precisa estar em formato diferente para Cosmos
2. O Hyperlane pode processar a chave hex automaticamente quando `type: "cosmosKey"` está configurado
3. Com a seção `chains` configurada corretamente, o relayer deve conseguir processar a chave

## 🔍 Próximos Passos

1. **Reiniciar o relayer** para aplicar as mudanças
2. **Verificar logs** para confirmar que o erro desapareceu
3. **Verificar se o Terra Classic está sendo sincronizado**
4. **Verificar se validators são descobertos**

## 📊 Verificação

Após reiniciar, verifique:

```bash
# Verificar se o container está rodando (não em Restarting)
docker ps | grep relayer

# Verificar logs por erros
docker logs hpl-relayer-testnet-local | grep -i "error\|critical"

# Verificar se Terra Classic aparece nos logs
docker logs hpl-relayer-testnet-local | grep -i "terraclassic\|1325"

# Verificar configuração dentro do container
docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | jq ".chains.terraclassictestnet"'
```

---

**Data**: 2026-01-23
**Status**: ✅ Correções aplicadas, aguardando teste
