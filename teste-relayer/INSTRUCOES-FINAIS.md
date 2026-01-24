# 📋 INSTRUÇÕES FINAIS: Corrigir Problema Terra Classic -> Solana

## ✅ Status Atual

**Problema identificado:** `InsufficientFundsForRent` no Solana

**Endereço do relayer:** `C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY`

**Mensagem afetada:**
- Message ID: `0x9910dbb32d10edeb1c2e2482966444795e7aaa03c4c33a7cf1d267ccab0f8ac1`
- Sequence: 35
- Origin: Terra Classic (1325)
- Destination: Solana (1399811150)

## 🔧 Passos para Corrigir

### Passo 1: Verificar Saldo Atual

```bash
solana balance C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY \
  --url https://api.testnet.solana.com
```

### Passo 2: Adicionar SOL (se necessário)

**Opção A: Faucet do Solana (Recomendado)**
1. Acesse: https://faucet.solana.com/
2. Cole o endereço: `C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY`
3. Clique em "Airdrop 1 SOL" ou "Airdrop 2 SOL"
4. Aguarde confirmação (alguns segundos)

**Opção B: Transferir de outra conta**
```bash
solana transfer C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY 0.1 \
  --url https://api.testnet.solana.com \
  --allow-unfunded-recipient
```

### Passo 3: Verificar Saldo Novamente

```bash
solana balance C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY \
  --url https://api.testnet.solana.com
```

**Deve mostrar pelo menos 0.1 SOL**

### Passo 4: Reiniciar Relayer

```bash
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml restart relayer
```

### Passo 5: Monitorar Logs

```bash
# Ver logs em tempo real
docker logs -f hpl-relayer-testnet-local | grep -iE "solana|insufficient|rent|message.*35"

# Ou verificar logs recentes
docker logs hpl-relayer-testnet-local --tail 100 | grep -iE "solana|insufficient|rent|error"
```

### Passo 6: Verificar Processamento da Mensagem

```bash
# Verificar se a mensagem sequence 35 foi processada
docker logs hpl-relayer-testnet-local | grep -iE "message.*35|sequence.*35|delivered|relayed"
```

## ✅ Indicadores de Sucesso

1. **Saldo >= 0.1 SOL** ✅
2. **Nenhum erro `InsufficientFundsForRent` nos logs** ✅
3. **Mensagem sequence 35 sendo processada** ✅
4. **Logs mostrando processamento bem-sucedido no Solana** ✅

## 📊 Verificação no Solana

Verifique se a mensagem foi entregue no Solana:

**Explorer:** https://explorer.solana.com/address/C4jCuG3DjRdAnDJkJLXn711ShWDiat5nSTAZKYzPPCnY?cluster=testnet

Procure por transações recentes relacionadas ao Mailbox do Hyperlane.

## 🔍 Troubleshooting

### Se o problema persistir após adicionar SOL:

1. **Verificar se o relayer está usando a chave correta:**
   ```bash
   docker exec hpl-relayer-testnet-local cat /etc/hyperlane/relayer.testnet.json | jq '.chains.solanatestnet'
   ```

2. **Verificar logs completos:**
   ```bash
   docker logs hpl-relayer-testnet-local --tail 200 | grep -i error
   ```

3. **Verificar se há outros erros:**
   ```bash
   docker logs hpl-relayer-testnet-local --tail 200 | grep -iE "error|fail|warn"
   ```

## 📄 Scripts Disponíveis

- **`solucao-final-solana.sh`** - Verifica saldo e fornece instruções
- **`monitorar-relayer-solana.sh`** - Monitora status após correção

Execute para verificar status:
```bash
./solucao-final-solana.sh
./monitorar-relayer-solana.sh
```

## 📝 Notas

- O relayer precisa de SOL para criar contas de token associadas (ATA) no Solana
- Cada criação de conta custa ~0.002 SOL (rent exemption)
- Recomendado manter pelo menos 0.1 SOL para operação contínua
- O problema foi identificado e a solução está documentada
