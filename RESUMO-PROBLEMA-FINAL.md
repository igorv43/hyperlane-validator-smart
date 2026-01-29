# 🎯 RESUMO DO PROBLEMA: Terra Classic → BSC Não Funciona

## ❌ Sintomas

1. **Mensagens de Terra → BSC não são entregues**
2. **MerkleTreeInsertion é detectado** (leaf 49, 50)
3. **Evento Dispatch NÃO é detectado**
4. **Pool está sempre vazio** (`pool_size: 0`)
5. **Nenhuma mensagem com destination: 97 aparece nos logs**

## ✅ O Que Está Funcionando

- ✅ Solana → Terra Classic: **FUNCIONA**
- ✅ MerkleTreeInsertion de Terra: **DETECTADO**
- ✅ Relayer está sincronizando Terra Classic
- ✅ Whitelist está configurada corretamente
- ✅ `relayChains` inclui `terraclassictestnet`
- ✅ Indexer `dispatched_messages` está rodando para Terra

## ❌ O Que NÃO Está Funcionando

- ❌ **Evento `Dispatch` de Terra Classic NÃO é detectado**
- ❌ Mensagens não entram no message pool
- ❌ Relayer não tenta buscar checkpoints
- ❌ Nenhuma tentativa de entregar para BSC

## 🔍 Investigação Realizada

### Configuração do Relayer
```json
{
  "relayChains": "terraclassictestnet,bsctestnet,solanatestnet",
  "whitelist": [
    {
      "originDomain": [1325],
      "destinationDomain": [97]
    }
  ]
}
```
✅ **Configuração correta**

### Agent Config
```json
{
  "terraclassictestnet": {
    "mailbox": "0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd",
    "merkleTreeHook": "0x3e151729e04f4795c761eb6371e669c21116d9205ca963f3077f4fb3697ff166"
  }
}
```
✅ **Mailbox e MerkleTreeHook configurados**

### Indexers Rodando
```
spawn_cursor_indexer_task domain: "terraclassictestnet", label: "dispatched_messages"
spawn_cursor_indexer_task domain: "terraclassictestnet", label: "merkle_tree_hook"
```
✅ **Ambos indexers estão rodando**

### Eventos Detectados

**MerkleTreeInsertion (leaf 49):**
```
ParsedEvent { 
  contract_address: 0x3e151729e04f4795c761eb6371e669c21116d9205ca963f3077f4fb3697ff166, 
  event: MerkleTreeInsertion { 
    leaf_index: 49, 
    message_id: 0x5e6732d7...
  }
}
```
✅ **Detectado com sucesso**

**Dispatch:**
```
(nenhum log encontrado)
```
❌ **NÃO detectado**

## 🎯 CAUSA RAIZ PROVÁVEL

### Hipótese 1: Evento Dispatch não está sendo emitido pelo contrato
O contrato mailbox de Terra Classic pode não estar emitindo o evento `Dispatch` corretamente.

**Como verificar:**
- Olhar a transação on-chain no block explorer
- Verificar se há evento `Dispatch` ou `DispatchId`
- Comparar com transação antiga que funcionava

### Hipótese 2: Parser de eventos Cosmos está quebrado
O relayer pode não estar conseguindo parsear eventos `Dispatch` do Cosmos/Terra Classic.

**Como verificar:**
- Ver se há logs de erro de parsing
- Verificar se o formato do evento mudou
- Comparar versão do agent com versão que funcionava

### Hipótese 3: Configuração do mailbox está errada
O endereço do mailbox no agent-config pode estar incorreto.

**Como verificar:**
- Confirmar endereço do mailbox: `0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd`
- Verificar se é o contrato correto no Terra Classic testnet
- Verificar se o contrato não mudou recentemente

## 🔧 PRÓXIMOS PASSOS PARA RESOLVER

### Passo 1: Verificar transação on-chain
Encontre uma transação de Terra → BSC no block explorer e verifique:
- [ ] Evento `Dispatch` foi emitido?
- [ ] Qual é o formato do evento?
- [ ] Todos os campos estão presentes (sender, recipient, destination, messageId)?

### Passo 2: Comparar com transação que funcionava
Se você tem o hash de uma transação antiga que funcionava:
- [ ] Compare os eventos emitidos
- [ ] Veja se há diferença no formato
- [ ] Verifique se o contrato é o mesmo

### Passo 3: Verificar versão do relayer
```
Agent relayer starting up with version 76a42471a6385b8f075b746323dab48804e7af2f
```
- [ ] Esta é a mesma versão que funcionava antes?
- [ ] Houve update recente do agent?
- [ ] Logs de changelog mencionam mudanças para Cosmos/Terra?

### Passo 4: Testar com logs mais verbosos
Adicione ao `docker-compose-testnet.yml`:
```yaml
environment:
  - RUST_LOG=trace,hyperlane_cosmos=trace
```

Reinicie e veja se aparecem mais detalhes sobre parsing de eventos.

### Passo 5: Verificar endereço do mailbox
No Terra Classic block explorer, verifique:
- [ ] O contrato `terra1...` (hex: 0x8564e4e5...) existe?
- [ ] É um contrato Hyperlane mailbox válido?
- [ ] Tem chamadas recentes?
- [ ] Emite eventos corretamente?

## 💡 SOLUÇÃO TEMPORÁRIA

Se você precisa que funcione AGORA:

1. **Usar bridge manual** temporariamente
2. **Investigar por que parou de funcionar** 
3. **Reverter para versão antiga do agent** que funcionava
4. **Redeployar contratos** se necessário

## 📞 PRECISA DE MAIS INFORMAÇÕES

Para eu ajudar mais, preciso de:

1. **Transaction hash de uma transação Terra → BSC que FUNCIONOU** (antes do problema)
2. **Transaction hash de uma transação Terra → BSC que NÃO FUNCIONOU** (agora)
3. **Quando exatamente parou de funcionar?** (data/hora)
4. **Houve alguma mudança** que você fez antes de parar de funcionar?
   - Update do agent?
   - Mudança de configuração?
   - Redeploy de contratos?
   - Mudança de infra?

---

**Data:** 2026-01-29  
**Status:** Investigando - evento Dispatch não é detectado  
**Próximo passo:** Verificar transação on-chain e comparar com transação antiga
