# ❌ PROBLEMA: Terra Classic → BSC Não Funciona

## 📋 Informações da Mensagem

- **Message ID:** `0x5e6732d7b0824d990dde8333c5b8d63c76830ac2d51582991d980d15aae3d257`
- **Origem:** Terra Classic Testnet (domain 1325)
- **Destino:** BSC Testnet (domain 97)
- **Leaf Index:** 49
- **Sequence:** 49
- **Timestamp:** 2026-01-29 12:23:14

## 🔍 Diagnóstico

### ✅ O que está funcionando:

1. **Merkle Tree Insertion detectada:**
   ```
   MerkleTreeInsertion { leaf_index: 49, message_id: 0x5e6732d7... }
   ```

2. **Relayer está sincronizando Terra Classic:**
   - Sequence atual: 49
   - Sincronizando corretamente

3. **Whitelist está configurada:**
   - ✅ Terra (1325) → BSC (97) permitido
   - ✅ BSC (97) → Terra (1325) permitido

4. **relayChains está configurado:**
   - ✅ `terraclassictestnet` está na lista

### ❌ O que NÃO está funcionando:

1. **Mensagem NÃO foi adicionada ao pool de processamento:**
   - `pool_size: 0` sempre
   - Mensagem não aparece em nenhum "dispatch" ou "submit"

2. **Terra Classic NÃO tem ISM configurado** no agent-config:
   - BSC tem: `"interchainSecurityModule": "0xe4245cCB6427Ba0DC483461bb72318f5DC34d090"`
   - Terra Classic: **FALTA a configuração!**

3. **Evento `Dispatch` pode não ter sido detectado:**
   - Apenas `MerkleTreeInsertion` foi detectado
   - Relayer precisa de AMBOS eventos para processar

## 🎯 CAUSA RAIZ

### Problema #1: Falta ISM no agent-config de Terra Classic

O agent-config **NÃO tem** `interchainSecurityModule` ou `defaultIsm` configurado para Terra Classic:

```json
"terraclassictestnet": {
  // ... outras configs ...
  // ❌ FALTA interchainSecurityModule
  // ❌ FALTA defaultIsm
}
```

**Consequência:**
- O relayer não sabe qual ISM consultar para validar mensagens de Terra Classic
- Mensagens de Terra podem não ser enviadas para o pool de processamento

### Problema #2: Possível falta de validadores configurados

Mesmo que o ISM esteja no warp route on-chain, se não há validadores ativos gerando checkpoints para mensagens de **Terra Classic**, o relayer não consegue obter as assinaturas necessárias.

## ✅ SOLUÇÕES

### Solução 1: Adicionar ISM no agent-config (RECOMENDADO)

Edite `hyperlane/agent-config.docker-testnet.json` e adicione o ISM para Terra Classic:

```json
"terraclassictestnet": {
  // ... configs existentes ...
  "interchainSecurityModule": "ENDEREÇO_DO_ISM_AQUI",
  // OU
  "defaultIsm": "ENDEREÇO_DO_DEFAULT_ISM"
}
```

**Onde encontrar o endereço do ISM:**
- Verifique no warp route contract de Terra Classic
- Ou use o mesmo ISM que você configurou para Solana/BSC

### Solução 2: Configurar validadores para Terra Classic

Se o ISM já está configurado mas não há validadores, você precisa:

1. **Verificar se há validadores públicos** para Terra Classic testnet
2. **Configurar seu próprio validator** para Terra Classic
3. **Garantir que o validator esteja gerando checkpoints** no S3

### Solução 3: Verificar o warp route on-chain

Verifique o contrato do warp route de Terra Classic e confirme:
- ISM está setado
- ISM tem validadores configurados
- Validadores têm threshold correto

## 🔧 COMO APLICAR A SOLUÇÃO

### Passo 1: Encontrar o endereço do ISM

Verifique qual ISM você usa para Terra Classic. Pode ser o mesmo que você usa para BSC:

```bash
# ISM do BSC (exemplo):
0xe4245cCB6427Ba0DC483461bb72318f5DC34d090
```

Ou verifique on-chain no warp route contract de Terra Classic.

### Passo 2: Adicionar no agent-config

Edite `/home/lunc/hyperlane-validator-smart/hyperlane/agent-config.docker-testnet.json`:

Encontre a seção de `terraclassictestnet` e adicione:

```json
"terraclassictestnet": {
  "blockExplorers": [...],
  // ... outras configs ...
  "interchainSecurityModule": "ENDEREÇO_ISM_AQUI",  // ← ADICIONE ESTA LINHA
  "mailbox": "0x2f9DB5616fa3fAd1aB06cB2C906830BA63d135e3",
  // ... resto das configs ...
}
```

### Passo 3: Reiniciar o relayer

```bash
cd /home/lunc/hyperlane-validator-smart
docker-compose -f docker-compose-testnet.yml restart relayer
```

### Passo 4: Enviar nova mensagem

Após reiniciar, envie uma **nova** mensagem de Terra para BSC e monitore:

```bash
docker logs hpl-relayer-testnet -f | grep -iE "(terra|1325|message)"
```

## 📊 Como Verificar se Funcionou

Após aplicar a solução, procure nos logs:

### 1. Mensagem adicionada ao pool:
```
Processing transactions in finality pool, pool_size: 1
```

### 2. Buscando validadores:
```
List of validators and threshold for message
origin: terraclassictestnet
validators: [0x...]
threshold: 1
```

### 3. Buscando checkpoints:
```
Fetching checkpoint for message 0x...
```

### 4. Submetendo para BSC:
```
Submitting message to bsctestnet
```

## ⚠️ Alternativa: Validadores Podem Estar Faltando

Se mesmo após adicionar o ISM no agent-config a mensagem não for processada, o problema é que **não há validadores ativos** gerando checkpoints para Terra Classic.

Neste caso, você tem duas opções:

1. **Usar validadores públicos do Hyperlane** (se existirem para Terra Classic testnet)
2. **Configurar seu próprio validator para Terra Classic**

---

**Data:** 2026-01-29  
**Status:** Aguardando correção do ISM no agent-config  
**Próximo passo:** Adicionar `interchainSecurityModule` para Terra Classic no agent-config
