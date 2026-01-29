# 🔍 DIAGNÓSTICO: Solana → Terra Classic NÃO Funciona

**Data**: 2026-01-29  
**Problema**: Mensagens de Solana → Terra Classic não estão sendo processadas  
**Status**: ❌ Problema identificado

---

## 📊 STATUS DO SISTEMA

### ✅ O que ESTÁ funcionando:

1. **Containers**:
   ```
   ✅ hpl-relayer-testnet: Up
   ✅ hpl-validator-terraclassic-testnet: Up (despausado)
   ```

2. **Configuração**:
   ```
   ✅ Chains configuradas: bsctestnet, sepolia, solanatestnet, terraclassictestnet
   ✅ Whitelist: Todas as 6 rotas configuradas
   ✅ Rota Solana → Terra Classic: EXISTE (Domain 1399811150 → 1325)
   ```

3. **Sincronização**:
   ```
   ✅ Terra Classic: synced
   ✅ BSC: synced
   ✅ Sepolia: synced
   ✅ Rate limits: 0 (sem problemas)
   ```

4. **Rotas que funcionam**:
   ```
   ✅ Terra Classic → Solana
   ✅ Terra Classic → BSC
   ✅ BSC → Terra Classic
   ✅ Terra Classic → Sepolia
   ✅ Sepolia → Terra Classic
   ```

---

## ❌ PROBLEMA IDENTIFICADO

### ISM do Solana está NULL

```bash
$ cat hyperlane/agent-config.docker-testnet.json | jq '.chains.solanatestnet.interchainSecurityModule'
null
```

**O que isso significa:**
- O relayer NÃO sabe qual validador usar para verificar mensagens de Solana
- Sem ISM, o relayer não consegue buscar checkpoints (provas) do validador
- Mensagens de Solana → Terra Classic ficam BLOQUEADAS

---

## 🔍 ANÁLISE DA WHITELIST

A whitelist está **CORRETA** e usa Domain IDs numéricos:

```json
{
  "whitelist": [
    {
      "originDomain": [1325],      // Terra Classic
      "destinationDomain": [97]     // BSC
    },
    {
      "originDomain": [97],         // BSC
      "destinationDomain": [1325]   // Terra Classic
    },
    {
      "originDomain": [1325],       // Terra Classic
      "destinationDomain": [1399811150] // Solana
    },
    {
      "originDomain": [1399811150], // Solana ← ESTA ROTA EXISTE!
      "destinationDomain": [1325]   // Terra Classic
    },
    {
      "originDomain": [1325],       // Terra Classic
      "destinationDomain": [11155111] // Sepolia
    },
    {
      "originDomain": [11155111],   // Sepolia
      "destinationDomain": [1325]   // Terra Classic
    }
  ]
}
```

**✅ A rota Solana → Terra Classic (1399811150 → 1325) ESTÁ configurada na whitelist!**

**❌ MAS o ISM está NULL, então o relayer não processa a mensagem.**

---

## 🎯 CAUSA RAIZ

### Histórico do Problema:

Este é o **MESMO PROBLEMA** que já identificamos antes:

1. **O warp de Solana foi configurado com ISM errado**:
   - ISM atual no warp: `0xd4ce8fa138d4e083fc0e480cca0dbfa4f5f30bd5`
   - Este é um **validador público do Hyperlane**
   - Este validador está **INATIVO** no testnet

2. **O validador correto é**:
   - Validador do usuário: `0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`
   - Este validador **ESTÁ ATIVO** e gerando checkpoints

3. **Por que não está no agent-config?**:
   - O ISM não foi adicionado ao `agent-config.docker-testnet.json`
   - O relayer depende desta configuração para saber qual validador usar

---

## 📋 COMPARAÇÃO COM OUTRAS CHAINS

### BSC Testnet (FUNCIONA):

```json
{
  "bsctestnet": {
    "interchainSecurityModule": "0x2b31a08d397b7e508cbE0F5830E8a9182C88b6cA",
    "mailbox": "0x...",
    ...
  }
}
```

✅ ISM configurado → Relayer sabe qual validador usar → BSC → Terra funciona

### Solana Testnet (NÃO FUNCIONA):

```json
{
  "solanatestnet": {
    "interchainSecurityModule": null, ← ❌ PROBLEMA!
    "mailbox": "75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR",
    ...
  }
}
```

❌ ISM NULL → Relayer não sabe qual validador usar → Solana → Terra não funciona

---

## 🔧 SOLUÇÕES POSSÍVEIS

### Opção 1: Reconfigurar o Warp de Solana (RECOMENDADO)

**Passos:**

1. Acessar o warp de Solana no contrato:
   - Mailbox: `75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR`
   - Programa: `HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw`

2. Atualizar o ISM para o validador ativo:
   ```
   Validador: 0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0
   ```

3. Não precisa alterar o `agent-config.docker-testnet.json`
   - O relayer deve ler o ISM do contrato automaticamente

**Vantagens:**
- ✅ Solução definitiva e correta
- ✅ Outros relayers também vão funcionar
- ✅ Alinhado com a arquitetura Hyperlane

**Desvantagens:**
- ⚠️ Requer transação on-chain no Solana
- ⚠️ Precisa de SOL para gas

---

### Opção 2: Adicionar ISM no agent-config (TEMPORÁRIO)

**Passos:**

1. Editar `hyperlane/agent-config.docker-testnet.json`:
   ```json
   {
     "solanatestnet": {
       "interchainSecurityModule": "ENDERECO_DO_ISM_AQUI",
       ...
     }
   }
   ```

2. Reiniciar o relayer:
   ```bash
   docker-compose -f docker-compose-testnet.yml restart relayer
   ```

**Problema:**
- ⚠️ Se o ISM on-chain (no warp) ainda aponta para validador inativo, NÃO VAI FUNCIONAR!
- ⚠️ O relayer vai buscar checkpoints do validador errado (que não está assinando)

**Quando funciona:**
- ✅ Se o warp on-chain JÁ está configurado com o validador correto
- ✅ Apenas adiciona a informação ao config para o relayer não precisar ler do contrato

---

### Opção 3: Verificar ISM On-Chain Primeiro

**Antes de qualquer coisa, verificar qual ISM está no warp de Solana:**

```bash
# Consultar o programa Solana
solana program show HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw --url testnet

# Ou usar Solana Explorer:
https://explorer.solana.com/address/HNxN3ZSBtD5J2nNF4AATMhuvTWVeHQf18nTtzKtsnkyw?cluster=testnet
```

**O que verificar:**
- Qual validador está configurado no ISM?
- É o validador ativo (`0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`)?
- Ou é o validador público inativo (`0xd4ce8fa138d4e083fc0e480cca0dbfa4f5f30bd5`)?

---

## 📊 LOGS DO RELAYER

### Whitelist Carregada Corretamente:

```
INFO relayer::relayer: Whitelist configuration, message_whitelist: [
  {messageId: *, originDomain: 1325, destinationDomain: 97, ...},
  {messageId: *, originDomain: 97, destinationDomain: 1325, ...},
  {messageId: *, originDomain: 1325, destinationDomain: 1399811150, ...},
  {messageId: *, originDomain: 1399811150, destinationDomain: 1325, ...}, ← EXISTE!
  {messageId: *, originDomain: 1325, destinationDomain: 11155111, ...},
  {messageId: *, originDomain: 11155111, destinationDomain: 1325, ...},
]
```

✅ A rota está carregada!

### Database de Solana:

```
INFO lander::dispatcher::db::loader: DbIterator {
  low_index_iter: DirectionalNonceIterator { index: 8, direction: Low, metadata: "Payload" },
  high_index_iter: Some(DirectionalNonceIterator { index: 9, direction: High, metadata: "Payload" }),
  domain: "solanatestnet"
}
```

✅ O relayer está monitorando Solana!

### Pool de Mensagens:

```
INFO lander::dispatcher::stages::finality_stage: Processing transactions in finality pool, pool_size: 0
```

❌ Pool vazio = Nenhuma mensagem sendo processada

---

## 🎯 PRÓXIMOS PASSOS

### 1. Verificar ISM On-Chain:

```bash
# Consultar o warp de Solana
# Verificar qual validador está configurado no ISM
```

### 2. Se ISM on-chain está errado:

**RECONFIGURAR o warp:**
- Atualizar ISM para: `0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`

### 3. Se ISM on-chain está correto:

**Adicionar ao agent-config:**
```bash
# Editar hyperlane/agent-config.docker-testnet.json
# Adicionar interchainSecurityModule para solanatestnet
# Reiniciar relayer
```

### 4. Testar:

```bash
# Enviar mensagem de Solana → Terra Classic
# Verificar logs:
docker logs -f hpl-relayer-testnet

# Buscar por:
# - Mensagem detectada (MerkleTreeInsertion)
# - Checkpoint obtido
# - Transação enviada para Terra
```

---

## 🔍 COMANDOS DE DIAGNÓSTICO

### Ver ISM no config:

```bash
cat hyperlane/agent-config.docker-testnet.json | jq '.chains.solanatestnet.interchainSecurityModule'
```

### Ver whitelist do relayer:

```bash
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.whitelist'
```

### Ver logs de Solana:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i solana | tail -50
```

### Ver pool de mensagens:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep pool_size | tail -10
```

---

## 📝 RESUMO EXECUTIVO

| Item | Status | Observação |
|------|--------|------------|
| **Containers** | ✅ OK | Rodando corretamente |
| **Whitelist** | ✅ OK | Rota Solana → Terra existe |
| **Sincronização** | ✅ OK | Todas as chains "synced" |
| **Rate Limits** | ✅ OK | Sem problemas |
| **ISM Solana** | ❌ NULL | **ESTE É O PROBLEMA** |
| **Validador Terra** | ✅ OK | Ativo e assinando |
| **Outras Rotas** | ✅ OK | Terra → Solana funciona |

---

## 🎯 CONCLUSÃO

**O problema é simples e já conhecido:**

1. ❌ ISM do Solana está NULL no `agent-config.docker-testnet.json`
2. ❌ Relayer não sabe qual validador usar para Solana → Terra
3. ❌ Mensagens ficam bloqueadas

**A solução:**

1. ✅ Verificar ISM on-chain no warp de Solana
2. ✅ Se necessário, reconfigurar para usar validador ativo: `0x8804770d6a346210c0fd011258fdf3ab0a5bb0d0`
3. ✅ Ou adicionar ISM ao agent-config (se já estiver correto on-chain)

**Este é exatamente o mesmo problema que tivemos antes, mas agora está no Solana ao invés do BSC.**

---

**Atualizado**: 2026-01-29  
**Próxima Ação**: Usuário deve verificar ISM on-chain no warp de Solana
