# 🧪 TESTE: Enviar Nova Mensagem Terra → BSC

## ⚙️ CONFIGURAÇÃO ATUAL

✅ **Relayer:**
- Chaves privadas configuradas (via .env)
- `allowLocalCheckpointSyncers: true` (pode ler S3)
- Whitelist: Terra (1325) → BSC (97)

✅ **Validador Terra Classic:**
- Rodando e assinando checkpoints
- Último checkpoint: index 50
- S3: `s3://hyperlane-validator-signatures-igorverasvalidador-terraclassic/us-east-1`

## 📋 STATUS DAS MENSAGENS ANTIGAS

As mensagens antigas (`0x5e6732d7` e `0xf8bde49e`) provavelmente foram **arquivadas** após muitas tentativas falhadas de buscar checkpoints.

**Por quê?**
- Quando o relayer não consegue buscar checkpoints por muito tempo, ele eventualmente desiste dessas mensagens
- Elas ficam no database mas não são mais processadas ativamente

## 🎯 PRÓXIMO PASSO: TESTAR COM NOVA MENSAGEM

Para verificar se o sistema está funcionando agora, você precisa **enviar uma NOVA mensagem** de Terra → BSC.

### Como Testar:

1. **Envie uma nova transação** de Terra Classic para BSC usando sua aplicação/contrato

2. **Pegue o Message ID** da nova transação

3. **Monitore os logs:**

```bash
# Terminal 1 - Monitorar relayer
docker logs hpl-relayer-testnet -f | grep -iE "(origin: 1325|destination.*97)"

# Terminal 2 - Monitorar validador
docker logs hpl-validator-terraclassic-testnet -f | grep -i "checkpoint"
```

4. **O que você deve ver:**

```
# No RELAYER:
✅ "MerkleTreeInsertion" - mensagem detectada
✅ "HyperlaneMessage { id: 0x..., origin: 1325, destination: bsctestnet }"
✅ "List of validators and threshold for message"
✅ "Fetched metadata" - checkpoint encontrado!
✅ "Submitting message" - enviando para BSC
✅ "Transaction confirmed" - sucesso!

# No VALIDADOR:
✅ "Latest checkpoint, index: XX" - assinou o checkpoint
✅ "Checkpoint submitter reached correctness checkpoint"
```

## ⏱️ TEMPO ESPERADO

- **Validador assinar:** ~30 segundos após a transação Terra
- **Relayer detectar:** Imediatamente
- **Relayer buscar checkpoint:** ~1 minuto (aguarda o validador assinar)
- **Relayer enviar para BSC:** ~30 segundos
- **Total:** ~2-3 minutos da transação Terra até chegada no BSC

## 🔍 SE NÃO FUNCIONAR

Se a nova mensagem também não chegar, verifique:

1. **Validador está assinando?**
   ```bash
   docker logs hpl-validator-terraclassic-testnet | grep "Latest checkpoint"
   ```

2. **Relayer detectou a mensagem?**
   ```bash
   docker logs hpl-relayer-testnet | grep "origin: 1325"
   ```

3. **Relayer conseguiu buscar checkpoint?**
   ```bash
   docker logs hpl-relayer-testnet | grep "metadata"
   ```

4. **Há erros?**
   ```bash
   docker logs hpl-relayer-testnet | grep -i error
   ```

## 📝 INFORMAÇÃO ADICIONAL

**Endereço Terra para receber:**
`terra18lr7ujd9nsgyr49930ppaajhadzrezam70j39k`

**Whitelist configurada:**
- Terra (1325) → BSC (97) ✅
- BSC (97) → Terra (1325) ✅
- Terra (1325) → Solana (1399811150) ✅
- Solana (1399811150) → Terra (1325) ✅

---

**Por favor, envie uma nova mensagem e me informe o Message ID para monitorarmos juntos!**
