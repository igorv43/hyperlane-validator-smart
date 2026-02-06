# 🔍 Diagnóstico: Relayer não enviando transação para Terra Classic

## 📋 Situação

- ✅ **Checkpoint gerado**: O validador `igorveras-sepolia` gerou um checkpoint para a mensagem `0x93cb428f4bfd3fa2ccd552412b4e963f1dd7a9ac1bc702ce98c3c68dda9af860`
- ✅ **Checkpoint disponível no S3**: `https://hyperlane-validator-signatures-igorveras-sepolia.s3.us-east-1.amazonaws.com/checkpoint_864656_with_id.json`
- ❌ **Relayer não está enviando**: O relayer não está processando a mensagem e enviando a transação para Terra Classic

## 🔍 Análise do Checkpoint

```json
{
  "message_id": "0x93cb428f4bfd3fa2ccd552412b4e963f1dd7a9ac1bc702ce98c3c68dda9af860",
  "mailbox_domain": 11155111,
  "index": 864656,
  "root": "0xbfd3be54586c5c64edd0671bf1f58a98817305540cf954b657d140d1f4d24b3f"
}
```

## 🔧 Possíveis Causas

### 1. Relayer não está lendo checkpoints do S3

**Verificar:**
```bash
# Verificar configuração
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.allowLocalCheckpointSyncers'
# Deve retornar: false
```

**Problema:** Se `allowLocalCheckpointSyncers` estiver como `true`, o relayer tentará ler checkpoints locais em vez do S3.

**Solução:** No `docker-compose-testnet.yml`, o relayer já está configurado com `--allowLocalCheckpointSyncers false`, mas verifique se o arquivo `relayer.testnet.json` também está correto.

### 2. Validador não está anunciado no contrato validatorAnnounce

**Verificar:**
```bash
# Verificar se o validador está anunciado
python3 scripts/query_validator_announce.py | grep -i "igorveras"
```

**Problema:** Se o validador não estiver anunciado no contrato `validatorAnnounce`, o relayer não saberá onde buscar os checkpoints.

**Solução:** O validador precisa anunciar seu bucket S3 no contrato `validatorAnnounce` em Sepolia.

### 3. Relayer não está encontrando o checkpoint no S3

**Verificar:**
```bash
# Verificar logs do relayer
docker logs hpl-relayer-testnet --tail 1000 | grep -i "s3\|checkpoint\|storage"
```

**Problema:** O relayer pode não estar conseguindo acessar o bucket S3 ou o caminho do checkpoint pode estar incorreto.

**Solução:** Verifique:
- AWS credentials estão configuradas no relayer
- O bucket S3 é público para leitura
- O caminho do checkpoint está correto

### 4. Quorum não está sendo atingido

**Verificar:**
```bash
# Verificar erros de quorum
docker logs hpl-relayer-testnet --tail 1000 | grep -i "quorum\|unable.*reach"
```

**Problema:** Mesmo com o checkpoint disponível, o relayer pode não estar conseguindo verificar o quorum se:
- O ISM (Interchain Security Module) requer mais validadores
- As assinaturas não estão sendo validadas corretamente

**Solução:** Verifique a configuração do ISM no contrato de destino (Terra Classic).

### 5. Mensagem não está na whitelist

**Verificar:**
```bash
# Verificar whitelist
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.whitelist'
```

**Problema:** Se a mensagem não estiver na whitelist, o relayer não processará.

**Solução:** A whitelist deve incluir:
```json
{
  "originDomain": [11155111],
  "destinationDomain": [1325]
}
```

### 6. Relayer não está processando mensagens de Sepolia

**Verificar:**
```bash
# Verificar se o relayer está sincronizando Sepolia
docker logs hpl-relayer-testnet --tail 1000 | grep -i "sepolia\|11155111"
```

**Problema:** O relayer pode não estar sincronizando mensagens de Sepolia.

**Solução:** Verifique se `relayChains` inclui `sepolia` e `terraclassictestnet`.

## 🔧 Comandos de Diagnóstico

### 1. Verificar configuração do relayer
```bash
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.'
```

### 2. Verificar logs do relayer
```bash
docker logs hpl-relayer-testnet --tail 1000 | grep -i "checkpoint\|quorum\|message\|s3"
```

### 3. Verificar se o validador está anunciado
```bash
python3 scripts/query_validator_announce.py | grep -A 5 "igorveras"
```

### 4. Verificar checkpoint no S3
```bash
curl -s "https://hyperlane-validator-signatures-igorveras-sepolia.s3.us-east-1.amazonaws.com/checkpoint_864656_with_id.json" | jq '.'
```

### 5. Verificar mensagem no Mailbox
```bash
# Usar Etherscan ou web3 para verificar se a mensagem existe
```

## 📝 Próximos Passos

1. ✅ Verificar se o checkpoint está acessível no S3 (já confirmado)
2. ⏳ Verificar se o validador está anunciado no contrato validatorAnnounce
3. ⏳ Verificar configuração do relayer (`allowLocalCheckpointSyncers`)
4. ⏳ Verificar logs do relayer para erros específicos
5. ⏳ Verificar se a mensagem está na whitelist
6. ⏳ Verificar configuração do ISM no Terra Classic

## 🔗 Referências

- [Hyperlane Relayer Documentation](https://docs.hyperlane.xyz/docs/operate/relayer)
- [Validator Announce Contract](https://docs.hyperlane.xyz/docs/operators/validators/announcing-your-validator)
- [Checkpoint Syncer Configuration](https://docs.hyperlane.xyz/docs/operators/validators/validator-signatures-aws)
