# 🚨 ERRO CRÍTICO ENCONTRADO

## ❌ Problema Identificado

O relayer está falhando ao configurar o Terra Classic devido a **erros críticos na inicialização**.

### Erros Encontrados nos Logs

```
ERROR hyperlane_base::settings::signers: error: HexKey { 
  key: 0xa5123190601045e1266e57c5d5b1a77f0897b39ea63ed2c761946686939c3cb6 
} key is not supported by cosmos

ERROR relayer::relayer: Critical error when building chain as origin, 
  err: ValidatorAnnounce("terraclassictestnet", "Building validator announce"), 
  domain: "terraclassictestnet"

ERROR relayer::relayer: Critical error when building chain as origin, 
  err: MissingConfiguration("terraclassictestnet"), 
  domain: "terraclassictestnet"

ERROR relayer::relayer: Critical error when building chain as destination, 
  err: MailboxCreationFailed("terraclassictestnet", "Building mailbox"), 
  domain: "terraclassictestnet"
```

## 🔍 Análise do Problema

### 1. Chave Privada do Terra Classic em Formato Incorreto

**Erro:** `HexKey { key: 0xa512... } key is not supported by cosmos`

**Causa:** A chave privada do Terra Classic está em formato hex, mas o relayer espera uma chave no formato Cosmos (bech32 ou outro formato compatível).

**Solução:** A chave do Terra Classic precisa estar no formato correto para Cosmos chains. Verificar como a chave deve ser configurada no `relayer.testnet.json`.

### 2. Falha ao Construir ValidatorAnnounce

**Erro:** `Critical error when building chain as origin, err: ValidatorAnnounce("terraclassictestnet", "Building validator announce")`

**Causa:** O relayer não consegue construir o ValidatorAnnounce para o Terra Classic, provavelmente devido ao erro na chave privada.

### 3. Configuração Faltando

**Erro:** `MissingConfiguration("terraclassictestnet")`

**Causa:** Devido aos erros anteriores, o relayer não consegue configurar o Terra Classic corretamente.

## 🔧 Solução

### Verificar Formato da Chave no relayer.testnet.json

O relayer precisa da chave do Terra Classic no formato correto. Verifique o arquivo `hyperlane/relayer.testnet.json`:

```bash
docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | jq ".chains.terraclassictestnet"'
```

**Formato esperado para Terra Classic (Cosmos):**

```json
{
  "chains": {
    "terraclassictestnet": {
      "signer": {
        "type": "cosmosKey",
        "key": "0x...",  // Pode precisar estar sem 0x ou em outro formato
        "prefix": "terra"
      }
    }
  }
}
```

### Possíveis Soluções

1. **Verificar se a chave está no formato correto:**
   - Para Cosmos chains, a chave pode precisar estar em formato diferente
   - Verificar documentação do Hyperlane para formato de chaves Cosmos

2. **Verificar se a chave está sendo passada corretamente:**
   - A variável `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY` pode precisar estar em formato diferente
   - Verificar se precisa remover o `0x` ou converter para outro formato

3. **Verificar configuração do relayer:**
   - O `relayer.testnet.json` pode precisar ter a chave configurada diretamente ao invés de usar variável de ambiente
   - Verificar se o formato da chave no JSON está correto

## 📋 Próximos Passos

1. **Verificar formato da chave no relayer.testnet.json:**
   ```bash
   docker exec hpl-relayer-testnet-local sh -c 'cat /etc/hyperlane/relayer.testnet.json | jq ".chains"'
   ```

2. **Verificar se a chave precisa ser convertida:**
   - A chave hex pode precisar ser convertida para formato Cosmos
   - Verificar documentação do Hyperlane para Terra Classic

3. **Testar com chave em formato diferente:**
   - Tentar sem o prefixo `0x`
   - Tentar em formato bech32 (se aplicável)

## 🎯 Resumo

**Problema Principal:** A chave privada do Terra Classic está em formato hex, mas o relayer espera um formato compatível com Cosmos.

**Erro específico:** `HexKey { key: 0xa512... } key is not supported by cosmos`

**Impacto:** O relayer não consegue configurar o Terra Classic, resultando em:
- Não sincroniza mensagens do Terra Classic
- Não descobre validators
- Não lê checkpoints
- Não processa mensagens

**Ação necessária:** Corrigir o formato da chave privada do Terra Classic no relayer.

---

**Data**: 2026-01-23
