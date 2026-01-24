# 🔍 ANÁLISE COMPLETA DO RELAYER - TERRA CLASSIC -> SOLANA

## 📊 Status do Relayer

### Container
- **Nome:** `hpl-relayer-testnet-local`
- **Status:** Verificar com `docker ps | grep relayer`

## 🔍 Verificações Realizadas

### 1. Status do Relayer
- ✅/❌ Relayer está rodando?
- ✅/❌ Container está saudável?

### 2. Configuração
- ✅ Chains configuradas no `agent-config.docker-testnet.json`
- ✅ Chains configuradas no `relayer.testnet.json`
- ✅ Solana está nas chains configuradas?

### 3. Logs do Relayer
- ✅ Mensagens sobre Terra Classic
- ✅ Mensagens sobre Solana
- ✅ Checkpoints e validators
- ✅ Pool de mensagens
- ✅ Erros e warnings

### 4. Checkpoints no S3
- ✅ Validator está gerando checkpoints
- ✅ Sequence mais recente: 35
- ✅ Bucket acessível: `hyperlane-validator-signatures-igorverasvalidador-terraclassic`

### 5. ISM do Solana
- ⚠️ Verificação do ISM requer ferramentas específicas do Solana
- ⚠️ Verificar se há validators do Terra Classic configurados

## 🎯 Possíveis Problemas Identificados

### Problema 1: Relayer Não Está Processando Mensagens Terra->Solana
**Sintomas:**
- Logs não mostram atividade Terra->Solana
- Pool size = 0 para mensagens Terra->Solana

**Verificação:**
```bash
docker logs hpl-relayer-testnet-local | grep -i "terra.*solana\|solana.*terra"
```

### Problema 2: Relayer Não Está Lendo Checkpoints
**Sintomas:**
- Logs não mostram leitura de checkpoints do S3
- Erros sobre acesso ao S3

**Verificação:**
```bash
docker logs hpl-relayer-testnet-local | grep -i "checkpoint\|s3\|bucket"
```

### Problema 3: ISM do Solana Não Tem Validators
**Sintomas:**
- Mensagens não são validadas
- Quorum não é atingido

**Verificação:**
- Consultar ISM do Solana para domain 1325
- Verificar se o validator está configurado

### Problema 4: Sequence da Mensagem Muito Nova
**Sintomas:**
- Mensagem tem sequence > 35 (último checkpoint)
- Checkpoint ainda não foi gerado

**Verificação:**
- Identificar sequence da mensagem
- Verificar se há checkpoint para essa sequence

## 📋 Próximos Passos

1. **Executar análise completa:**
   ```bash
   cd teste-relayer
   ./diagnosticar-relayer-completo.sh
   ```

2. **Verificar logs em tempo real:**
   ```bash
   docker logs -f hpl-relayer-testnet-local
   ```

3. **Verificar configuração:**
   ```bash
   cat hyperlane/relayer.testnet.json | jq '.'
   cat hyperlane/agent-config.docker-testnet.json | jq '.chains | keys'
   ```

4. **Verificar checkpoints:**
   ```bash
   curl -s "https://hyperlane-validator-signatures-igorverasvalidador-terraclassic.s3.us-east-1.amazonaws.com/checkpoint_latest_index.json"
   ```

5. **Verificar ISM do Solana:**
   - Usar ferramentas do Solana para consultar o programa
   - Verificar ISM configurado para domain 1325

## 📄 Arquivos Relacionados

- `diagnosticar-relayer-completo.sh` - Script de diagnóstico completo
- `analisar-relayer-detalhado.sh` - Análise detalhada dos logs
- `verificar-ism-solana.sh` - Verificação do ISM do Solana
