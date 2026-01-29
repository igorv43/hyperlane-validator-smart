# ⚠️ PROBLEMA: SEPOLIA CAUSANDO RATE LIMITS

Data: 2026-01-29

---

## 🔍 PROBLEMA IDENTIFICADO

### Sintoma:
Após adicionar Sepolia, Solana → Terra Classic parou de funcionar.

### Causa Raiz:
❌ **Sepolia causando rate limits nos RPCs públicos**

```
Rate limit: 600 requests/60s excedido
RPC público Sepolia: ethereum-sepolia.publicnode.com
```

O Sepolia estava consumindo muitos requests nos RPCs públicos, causando rate limits que afetaram o desempenho de **TODAS as chains** (não apenas Sepolia).

---

## 📊 IMPACTO

### Chains Afetadas:
- ❌ **Solana → Terra Classic**: Parou de funcionar
- ⚠️  **BSC**: Erros temporários nos RPCs
- ⚠️  **Sepolia**: Rate limit constante

### Chains Não Afetadas:
- ✅ **Terra → Solana**: Funcionando
- ✅ **Terra → BSC**: Funcionando

**Por quê?** Terra → outras chains funcionava porque a sincronização de Terra não dependia tanto dos RPCs sobrecarregados. Mas Solana → Terra precisava que o relayer processasse eventos de Solana, e os rate limits do Sepolia atrasavam todo o sistema.

---

## 🔧 SOLUÇÃO APLICADA

### 1. Remover Sepolia Temporariamente

**Arquivo**: `hyperlane/relayer.testnet.json`

```diff
- "relayChains": "terraclassictestnet,bsctestnet,solanatestnet,sepolia",
+ "relayChains": "terraclassictestnet,bsctestnet,solanatestnet",
```

Removido:
- Sepolia das `relayChains`
- Configuração de signer do Sepolia
- Whitelist Terra ↔ Sepolia

### 2. Reiniciar Relayer

```bash
docker-compose -f docker-compose-testnet.yml restart relayer
```

---

## ✅ RESULTADO

### Após Remover Sepolia:

```
✅ Sem rate limits
✅ Sistema rodando normalmente
✅ Solana → Terra Classic funcionando
✅ Todas as rotas operacionais
```

### Chains Ativas (3):
- ✅ Terra Classic (1325)
- ✅ BSC Testnet (97)
- ✅ Solana Testnet (1399811150)

### Rotas Funcionando (4):
- ✅ Terra ↔ BSC
- ✅ Terra ↔ Solana

---

## 📝 LIÇÕES APRENDIDAS

### 1. **RPCs Públicos Têm Limites**

RPCs públicos são ótimos para começar, mas têm rate limits:
```
Sepolia público: 600 requests/60s
BSC público: Varia por provider
```

### 2. **Adicionar Chains Aumenta Carga**

Cada chain adicional:
- Aumenta requests aos RPCs
- Aumenta uso de CPU/memória
- Pode afetar outras chains se houver rate limits

### 3. **Monitorar Rate Limits**

Sempre monitorar logs para:
```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "rate limit"
docker logs hpl-relayer-testnet 2>&1 | grep -i "limit exceeded"
```

---

## 🔄 COMO ADICIONAR SEPOLIA NOVAMENTE (NO FUTURO)

### Opção 1: Usar RPCs Privados/Pagos

**RPCs com mais limite**:
- Alchemy (grátis até certo ponto)
- Infura (grátis até certo ponto)
- QuickNode (pago)

**Configurar em** `agent-config.docker-testnet.json`:
```json
"sepolia": {
  "rpcUrls": [
    {"http": "https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"},
    {"http": "https://sepolia.infura.io/v3/YOUR_API_KEY"}
  ]
}
```

### Opção 2: Rate Limit no Relayer

Configurar o relayer para fazer menos requests por segundo (se disponível na versão).

### Opção 3: Usar Apenas Quando Necessário

Só adicionar Sepolia quando:
- Tiver ETH suficiente para testar
- Tiver RPCs configurados
- Precisar realmente testar a rota

---

## 🎯 RECOMENDAÇÕES

### Para Testnet:

1. **Começar com 2-3 chains** (Terra, BSC, Solana)
2. **Adicionar chains gradualmente**
3. **Monitorar rate limits**
4. **Usar RPCs privados para produção**

### Para Mainnet:

1. **Sempre usar RPCs privados/pagos**
2. **Configurar múltiplos RPCs por chain (fallback)**
3. **Monitorar métricas e alertas**
4. **Ter plano de contingência para rate limits**

---

## 📊 COMPARAÇÃO

### Antes (Com Sepolia):
```
Chains: 4
Rate Limits: Constantes
Solana → Terra: ❌ Não funcionando
Desempenho: Degradado
```

### Depois (Sem Sepolia):
```
Chains: 3
Rate Limits: Nenhum
Solana → Terra: ✅ Funcionando
Desempenho: Normal
```

---

## 🔍 DIAGNÓSTICO FUTURO

Se o problema voltar, verificar:

```bash
# 1. Rate limits
docker logs hpl-relayer-testnet 2>&1 | grep -i "rate limit"

# 2. Uso de recursos
docker stats hpl-relayer-testnet

# 3. RPCs respondendo
docker logs hpl-relayer-testnet 2>&1 | grep -i "rpc"

# 4. Chains sincronizando
docker logs hpl-relayer-testnet 2>&1 | grep -i "synced"
```

---

## ✅ CONCLUSÃO

**Problema**: Sepolia causando rate limits que afetavam todas as chains.

**Solução**: Remover Sepolia temporariamente.

**Resultado**: Sistema voltou a funcionar normalmente, Solana → Terra Classic operacional.

**Próximo**: Quando precisar de Sepolia, usar RPCs privados com mais limite.

---

**Identificado**: 2026-01-29  
**Resolvido**: 2026-01-29  
**Causa**: Rate limits em RPCs públicos  
**Impacto**: Todas as chains afetadas  
**Solução**: Remover chain problemática
