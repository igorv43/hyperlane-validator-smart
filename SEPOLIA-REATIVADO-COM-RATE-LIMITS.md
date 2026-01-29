# ⚠️ SEPOLIA REATIVADO - RATE LIMITS CONFIRMADOS

Data: 2026-01-29

---

## ✅ SEPOLIA REATIVADO

### Saldo ETH:
```
Carteira: 0x133fD7F7094DBd17b576907d052a5aCBd48dB526
Saldo: 1.03 ETH ✅
```

### Configuração:
```
✅ relayChains: terraclassictestnet,bsctestnet,solanatestnet,sepolia
✅ chains: 4 (Terra, BSC, Solana, Sepolia)
✅ whitelist: 6 rotas
✅ Chave Sepolia injetada
```

---

## ⚠️ RATE LIMITS CONFIRMADOS

### Status:
```
❌ Rate limits VOLTARAM
📊 1505+ linhas de rate limit detectadas
⚠️  Afetando múltiplos RPCs públicos
```

### RPCs Afetados:
1. **ethereum-sepolia.publicnode.com**
   - Limite: 600 requests/60s
   - Status: Rate limit excedido constantemente

2. **gateway.tenderly.co**
   - Status: Rate limit excedido repetidamente
   - Múltiplas ocorrências

3. **sepolia.drpc.org**
   - Status: Também com rate limits

---

## 🔍 ANÁLISE

### O Problema Persiste:

**RPCs públicos NÃO são suficientes para Sepolia no relayer.**

Mesmo com ETH na carteira, os RPCs públicos têm limites muito baixos para a carga do relayer Hyperlane.

### Por que acontece:

1. **Relayer faz muitos requests**:
   - Sincronização constante de blocos
   - Verificação de eventos
   - Leitura de checkpoints
   - Submissão de transações

2. **RPCs públicos têm limites baixos**:
   - 600 requests/60s = 10 requests/segundo
   - Relayer precisa de mais para 4 chains

3. **Sepolia adiciona carga extra**:
   - Mais uma chain = mais requests
   - Afeta o desempenho de TODAS as chains

---

## 💡 SOLUÇÕES

### Opção 1: RPCs Privados (RECOMENDADO)

Obter API keys de serviços com limites maiores:

#### Alchemy (Recomendado):
- **Grátis**: 300M compute units/mês
- **Link**: https://www.alchemy.com/
- **Como configurar**:

```json
// agent-config.docker-testnet.json
"sepolia": {
  "rpcUrls": [
    {"http": "https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"}
  ]
}
```

#### Infura:
- **Grátis**: 100k requests/dia
- **Link**: https://infura.io/
- **Como configurar**:

```json
"sepolia": {
  "rpcUrls": [
    {"http": "https://sepolia.infura.io/v3/YOUR_API_KEY"}
  ]
}
```

### Opção 2: Remover Sepolia (TEMPORÁRIO)

Se não for usar Sepolia imediatamente:

```bash
# Remover Sepolia do relayer.testnet.json
# Reduz carga e elimina rate limits
```

### Opção 3: Usar Menos Chains

Para testnet, talvez não precise de 4 chains ao mesmo tempo:
- Manter: Terra, BSC, Solana (3 chains funcionando bem)
- Adicionar Sepolia: Só quando realmente necessário

---

## 📊 IMPACTO ATUAL

### Com Sepolia (Agora):
```
✅ 4 Chains ativas
❌ 1505+ rate limits
⚠️  Desempenho degradado em TODAS as chains
⚠️  Solana → Terra pode parar novamente
```

### Sem Sepolia (Antes):
```
✅ 3 Chains ativas
✅ 0 rate limits
✅ Desempenho normal
✅ Todas as rotas funcionando
```

---

## 🎯 RECOMENDAÇÃO

### Para Testnet Agora:

**Opção A - Continuar com Sepolia + Rate Limits:**
- ⚠️  Aceitar que terá rate limits
- ⚠️  Desempenho pode ser afetado
- ⚠️  Monitorar se Solana → Terra continua funcionando

**Opção B - Remover Sepolia até ter RPCs privados:**
- ✅ Sistema estável sem rate limits
- ✅ Todas as outras rotas funcionando perfeitamente
- ✅ Adicionar Sepolia depois com Alchemy/Infura

### Para Produção (Futuro):

**OBRIGATÓRIO:**
- ✅ Usar APENAS RPCs privados/pagos
- ✅ Múltiplos RPCs por chain (fallback)
- ✅ Monitoramento e alertas
- ✅ Orçamento para APIs

---

## 📝 PRÓXIMOS PASSOS

### Se Quiser Manter Sepolia:

1. **Obter API Key Alchemy** (5 minutos):
   ```
   1. Criar conta: https://www.alchemy.com/
   2. Criar app Sepolia
   3. Copiar API key
   4. Configurar em agent-config
   5. Reiniciar relayer
   ```

2. **Monitorar Rate Limits**:
   ```bash
   docker logs hpl-relayer-testnet -f | grep -i "rate limit"
   ```

3. **Verificar se Solana → Terra continua funcionando**:
   ```bash
   # Enviar transação teste
   # Monitorar logs
   ```

### Se Quiser Remover Sepolia:

1. **Remover do relayer.testnet.json**
2. **Reiniciar relayer**
3. **Verificar que rate limits sumiram**

---

## ⚠️ AVISO IMPORTANTE

**Com os rate limits atuais, é PROVÁVEL que:**
- Solana → Terra pare de funcionar novamente
- Outras rotas tenham atrasos
- Mensagens demorem mais para serem processadas

**Sugestão**: Testar por alguns minutos e ver se Solana → Terra continua funcionando. Se parar, considerar remover Sepolia até ter RPCs privados.

---

## 🔍 MONITORAMENTO

### Comandos úteis:

```bash
# Ver rate limits em tempo real
docker logs hpl-relayer-testnet -f | grep -i "rate limit"

# Contar rate limits por minuto
docker logs hpl-relayer-testnet --since 1m 2>&1 | grep -i "rate limit" | wc -l

# Ver se Solana está processando
docker logs hpl-relayer-testnet --since 1m 2>&1 | grep -i solana

# Ver status geral
docker logs hpl-relayer-testnet --since 1m 2>&1 | grep -i "pool_size"
```

---

**Status**: ⚠️  SEPOLIA ATIVO COM RATE LIMITS  
**Saldo ETH**: ✅ 1.03 ETH  
**RPCs**: ❌ Públicos com rate limits  
**Recomendação**: Obter API keys Alchemy/Infura ou remover Sepolia
