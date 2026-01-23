# ✅ Erro Identificado e Corrigido

## 🚨 Problema Encontrado

O arquivo `relayer.testnet.json` dentro do container ainda continha placeholders `"0xYOUR_PRIVATE_KEY_HERE"` em vez das chaves privadas reais.

**Evidência:**
```bash
docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | grep terraclassictestnet'
```

**Resultado:**
```json
"terraclassictestnet": {
  "signer": {
    "type": "cosmosKey",
    "key": "0xYOUR_PRIVATE_KEY_HERE",  // ❌ Placeholder não substituído!
    "prefix": "terra"
  }
}
```

## 🔍 Causa Raiz

O arquivo `docker-compose-relayer-only.yml` **não tinha os comandos `sed`** para substituir os placeholders pelas chaves privadas reais das variáveis de ambiente.

**Comparação:**

- ✅ `docker-compose-testnet.yml` - **TEM** os comandos `sed` (linhas 28-39)
- ❌ `docker-compose-relayer-only.yml` - **NÃO TINHA** os comandos `sed`

## ✅ Correção Aplicada

Adicionados os comandos `sed` no `docker-compose-relayer-only.yml` para substituir automaticamente os placeholders:

```yaml
if [ -n "${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" ]; then
  sed -i "s|\"0xYOUR_PRIVATE_KEY_HERE\"|\"${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json";
  sed -i "s|\"0xYOUR_PRIVATE_KEY_BSC\"|\"${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json";
fi

if [ -n "${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}" ]; then
  sed -i "s|\"0xYOUR_PRIVATE_KEY_HERE\"|\"${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json";
  sed -i "s|\"0xYOUR_PRIVATE_KEY_SOLANA\"|\"${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json";
fi

if [ -n "${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}" ]; then
  sed -i "s|\"0xYOUR_PRIVATE_KEY_HERE\"|\"${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json";
  sed -i "s|\"0xYOUR_PRIVATE_KEY_TERRA\"|\"${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}\"|g" "/etc/hyperlane/relayer.testnet.json";
fi
```

## 🔄 Próximos Passos

1. **Reiniciar o relayer:**
   ```bash
   cd teste-relayer
   docker compose -f docker-compose-relayer-only.yml down
   docker compose -f docker-compose-relayer-only.yml up -d
   ```

2. **Verificar se as chaves foram substituídas:**
   ```bash
   docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | grep -A 3 "terraclassictestnet"'
   ```
   Deve mostrar a chave real (não mais `0xYOUR_PRIVATE_KEY_HERE`).

3. **Monitorar logs para verificar se o relayer descobriu validators:**
   ```bash
   docker logs -f hpl-relayer-testnet-local | grep -i "discovering\|validator.*announce\|checkpoint"
   ```

4. **Verificar se mensagens estão sendo processadas:**
   ```bash
   docker logs -f hpl-relayer-testnet-local | grep -i "pool_size\|processing.*message"
   ```

## 📋 O que Esperar Após a Correção

Após reiniciar o relayer com as chaves corretas:

1. ✅ O relayer deve inicializar o Terra Classic corretamente
2. ✅ O relayer deve descobrir validators através do ValidatorAnnounce
3. ✅ O relayer deve ler checkpoints do S3
4. ✅ O relayer deve processar mensagens (pool_size deve aumentar)
5. ✅ Mensagens devem ser retransmitidas do Terra Classic para o BSC

## 🎯 Resumo

**Erro:** Chaves privadas não estavam sendo substituídas no `relayer.testnet.json`

**Correção:** Adicionados comandos `sed` para substituir placeholders pelas chaves reais

**Arquivo modificado:** `teste-relayer/docker-compose-relayer-only.yml`

**Ação necessária:** Reiniciar o relayer para aplicar as correções

---

**Data:** 2026-01-23
**Status:** ✅ Erro corrigido, aguardando reinicialização do relayer
