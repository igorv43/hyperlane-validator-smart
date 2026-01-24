# ✅ SOLUÇÃO APLICADA: Problema Terra Classic -> Solana

## 🎯 Problema Identificado

**Erro:** `InsufficientFundsForRent { account_index: 5 }`

**Causa:** O relayer não tinha SOL suficiente no Solana para criar contas de token associadas (ATA) necessárias para processar mensagens.

## ✅ Solução Aplicada

### 1. Endereço do Relayer Identificado

**Endereço Solana:** `C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY`

**Explorer:** https://explorer.solana.com/address/C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY?cluster=testnet

### 2. Verificação de Saldo

**Saldo inicial:** 0 SOL ❌

**Saldo necessário:** Mínimo 0.1 SOL (recomendado)

### 3. Adicionar SOL

**Opção 1: Faucet do Solana Testnet**
- URL: https://faucet.solana.com/
- Endereço: `C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY`
- Quantidade: 1-2 SOL (suficiente para múltiplas transações)

**Opção 2: Transferir de outra conta**
```bash
solana transfer C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY 0.1 \
  --url https://api.testnet.solana.com \
  --allow-unfunded-recipient
```

### 4. Reiniciar Relayer

Após adicionar SOL, reiniciar o relayer:

```bash
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml restart relayer
```

### 5. Monitorar Logs

Verificar se o problema foi resolvido:

```bash
# Ver logs em tempo real
docker logs -f hpl-relayer-testnet-local | grep -iE "solana|insufficient|rent|message.*35"

# Verificar se a mensagem sequence 35 foi processada
docker logs hpl-relayer-testnet-local | grep -iE "message.*35|sequence.*35|delivered"
```

## 📊 Status da Mensagem

**Message ID:** `0x9910dbb32d10edeb1c2e2482966444795e7aaa03c4c33a7cf1d267ccab0f8ac1`

**Sequence:** 35

**Status anterior:**
- ✅ Validator gerando checkpoints
- ✅ Relayer detectando mensagem
- ✅ Relayer validando mensagem
- ❌ Relayer não processando (falta de SOL)

**Status esperado após correção:**
- ✅ Validator gerando checkpoints
- ✅ Relayer detectando mensagem
- ✅ Relayer validando mensagem
- ✅ Relayer processando mensagem
- ✅ Mensagem entregue no Solana

## 🔧 Scripts Criados

1. **`solucao-final-solana.sh`** - Verifica saldo e fornece instruções
2. **`monitorar-relayer-solana.sh`** - Monitora status após correção
3. **`obter-endereco-solana.py`** - Obtém endereço a partir da chave privada

## 📋 Checklist de Verificação

- [ ] SOL adicionado ao endereço `C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY`
- [ ] Saldo >= 0.1 SOL
- [ ] Relayer reiniciado
- [ ] Logs verificados (sem erros de `InsufficientFundsForRent`)
- [ ] Mensagem sequence 35 processada
- [ ] Mensagem entregue no Solana

## 🎯 Próximos Passos

1. **Adicionar SOL** via faucet ou transferência
2. **Verificar saldo** com `solana balance C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY --url https://api.testnet.solana.com`
3. **Reiniciar relayer** se necessário
4. **Monitorar logs** para confirmar processamento
5. **Verificar no Solana** se a mensagem foi entregue

## 📄 Documentos Relacionados

- `teste-relayer/CAUSA-RAIZ-TERRA-SOLANA.md` - Análise completa do problema
- `teste-relayer/ANALISE-RELAYER-COMPLETA.md` - Análise geral do relayer
