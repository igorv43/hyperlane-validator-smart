# 🔧 Troubleshooting: Relayer não está enviando mensagens

## 📋 Problema Identificado

O relayer não está enviando mensagens de Terra Classic → BSC, mesmo com o validator gerando checkpoints corretamente.

## 🔍 Análise dos Logs

### Problemas Encontrados:

1. **❌ Erros de RPC do BSC**:
   - `History has been pruned for this block` - RPCs públicos não têm histórico antigo
   - `Temporary internal error` - Erros temporários dos RPCs
   - Ranges de blocos falhando: `64000959..=64000969` e `86043380..=86043390`

2. **❌ Bloco inicial muito antigo**:
   - `index.from: 64000000` (muito antigo)
   - Bloco atual do BSC: `86134402`
   - Diferença: ~22 milhões de blocos

3. **❌ Pool vazio**:
   - `pool_size: 0` - Nenhuma mensagem sendo processada

4. **⚠️ Falta de logs do Terra Classic**:
   - Não há logs de sincronização de mensagens do Terra Classic

## ✅ Soluções Aplicadas

### 1. Atualização do `index.from` do BSC

**Arquivo**: `hyperlane/agent-config.docker-testnet.json`

**Antes**:
```json
"index": {
  "from": 64000000,
  "chunk": 10
}
```

**Depois**:
```json
"index": {
  "from": 86000000,
  "chunk": 10
}
```

**Motivo**: O bloco inicial estava muito antigo, causando erros de "History pruned" nos RPCs públicos.

### 2. Adição de RPCs Adicionais do BSC

**RPCs adicionados**:
- `https://data-seed-prebsc-1-s1.binance.org:8545`
- `https://data-seed-prebsc-2-s1.binance.org:8545`

**Motivo**: Mais opções de RPC para fallback quando os públicos falharem.

## 🔄 Próximos Passos

### 1. Reiniciar o Relayer

```bash
# No Easypanel ou via Docker Compose
docker-compose -f docker-compose-testnet.yml restart relayer
```

### 2. Monitorar Logs

```bash
# Verificar logs do relayer
docker-compose -f docker-compose-testnet.yml logs -f relayer

# Procurar por:
# - Logs relacionados ao Terra Classic (terraclassictestnet)
# - Mensagens sendo processadas
# - Checkpoints sendo lidos do S3
```

### 3. Verificar Sincronização do Terra Classic

O relayer deve mostrar logs como:
```
INFO hyperlane_base::contract_sync: Syncing messages from terraclassictestnet
INFO relayer::relayer: Processing message from domain 1325 to domain 97
```

Se não houver logs do Terra Classic, verifique:

#### a) Verificar se o validator está gerando checkpoints

```bash
# Usar o script de consulta
./query-validator-s3.sh list
```

#### b) Verificar se o relayer está lendo do S3

O relayer deve ter acesso ao bucket S3 configurado. Verifique:
- Variáveis de ambiente `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`
- Variável `HYP_CHECKPOINT_SYNCER_BUCKET` (se aplicável)

#### c) Verificar whitelist

O arquivo `hyperlane/relayer.testnet.json` deve ter:
```json
"whitelist": [
  {
    "originDomain": [1325],
    "destinationDomain": [97]
  }
]
```

### 4. Verificar Configuração do Terra Classic

No arquivo `hyperlane/agent-config.docker-testnet.json`, verifique se o Terra Classic está configurado corretamente:

```json
"terraclassictestnet": {
  "domainId": 1325,
  "mailbox": "0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd",
  // ... outras configurações
}
```

## 🚨 Se o Problema Persistir

### Opção 1: Usar RPC Dedicado

Se os RPCs públicos continuarem falhando, considere usar um RPC dedicado do BSC:

1. Obter um RPC dedicado (ex: Infura, Alchemy, QuickNode)
2. Adicionar ao `rpcUrls` no `agent-config.docker-testnet.json`

### Opção 2: Resetar o Database do Relayer

⚠️ **ATENÇÃO**: Isso apagará o histórico de sincronização!

```bash
# Parar o relayer
docker-compose -f docker-compose-testnet.yml stop relayer

# Remover o database (ajuste o caminho conforme necessário)
rm -rf ./relayer-testnet/db/*

# Reiniciar o relayer
docker-compose -f docker-compose-testnet.yml start relayer
```

### Opção 3: Verificar Checkpoints no S3

```bash
# Listar checkpoints disponíveis
./query-validator-s3.sh list

# Verificar um checkpoint específico
./query-validator-s3.sh checkpoint 22
```

## 📊 Monitoramento

### Métricas Importantes

1. **Mensagens processadas**: Verificar logs para `Processing message`
2. **Checkpoints lidos**: Verificar logs para `Reading checkpoint from S3`
3. **Erros de RPC**: Monitorar frequência de erros
4. **Pool size**: Deve ser > 0 quando há mensagens

### Comandos Úteis

```bash
# Ver logs em tempo real
docker-compose -f docker-compose-testnet.yml logs -f relayer | grep -E "(message|checkpoint|error|warn)"

# Verificar status do container
docker-compose -f docker-compose-testnet.yml ps

# Verificar uso de recursos
docker stats hpl-relayer-testnet
```

## 🔗 Referências

- **Configuração do Relayer**: `hyperlane/relayer.testnet.json`
- **Configuração das Chains**: `hyperlane/agent-config.docker-testnet.json`
- **Script de Consulta S3**: `query-validator-s3.sh`

---

**Última atualização**: 2026-01-23
