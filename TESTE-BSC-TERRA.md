# 🧪 Teste: BSC Testnet → Terra Classic

## 📋 Informações Necessárias

- **Endereço Terra Classic destino:** `terra18lr7ujd9nsgyr49930ppaajhadzrezam70j39k`
- **Domínio BSC Testnet:** 97
- **Domínio Terra Classic Testnet:** 1325
- **Relayer sincronizando desde bloco:** 86149783

## ✅ Whitelist Configurada

A whitelist já está configurada para BSC ↔ Terra Classic:

```json
{
  "originDomain": [97],
  "destinationDomain": [1325]
}
```

✅ Rota permitida: BSC → Terra Classic

## 🚀 Como Testar

### Passo 1: Enviar mensagem/token de BSC para Terra Classic

Use seu contrato/interface para enviar uma transação de BSC testnet para Terra Classic.

**Parâmetros:**
- **Origem:** BSC Testnet (chainId 97)
- **Destino:** Terra Classic Testnet (domain 1325)
- **Endereço destino:** `terra18lr7ujd9nsgyr49930ppaajhadzrezam70j39k`

### Passo 2: Anotar transaction hash e message ID

Após enviar a transação:
1. Pegue o **transaction hash** do BscScan testnet
2. Encontre o **message ID** (event `Dispatch` ou similar)

### Passo 3: Monitorar no relayer

Use o script criado:

```bash
cd /home/lunc/hyperlane-validator-smart
./monitorar-bsc-mensagem.sh <MESSAGE_ID>
```

Ou:

```bash
# Substitua abc123 pelos primeiros bytes do seu message ID
./monitorar-bsc-mensagem.sh abc123
```

### Passo 4: Ver logs em tempo real

```bash
docker logs hpl-relayer-testnet -f | grep -iE "(bsc|message)"
```

## 🔍 O Que Verificar

### 1. Bloco da transação

⚠️ **IMPORTANTE:** A transação precisa estar no bloco **>= 86149783**

Se sua transação estiver em um bloco anterior a 86149783, o relayer não vai detectar.

**Como verificar:**
1. Vá para BscScan testnet: https://testnet.bscscan.com
2. Procure seu transaction hash
3. Veja o número do bloco
4. Compare com 86149783

### 2. Mensagem nos logs

Procure o message ID nos logs:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "<primeiros_bytes_do_message_id>"
```

### 3. Checkpoints

Se a mensagem foi detectada, verifique se o relayer está buscando checkpoints:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "checkpoint" | grep -i "bsc\|97" | tail -20
```

### 4. Submissão para Terra Classic

Se encontrou checkpoints, verifique se submeteu para Terra Classic:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(submit|deliver|process)" | grep -i "terra\|1325" | tail -20
```

## ⚠️ Problemas Possíveis

### 1. Transação em bloco antigo

**Sintoma:** Message ID não aparece nos logs

**Causa:** Transação foi enviada em bloco < 86149783

**Solução:** 
- Enviar nova transação AGORA (vai estar em bloco > 86149783)
- OU: Alterar `index.from` para um valor menor e resetar database

### 2. Faltam validadores do BSC

**Sintoma:** Mensagem detectada, mas não tem checkpoints

**Causa:** Validadores do BSC não estão gerando checkpoints, ou ISM não está configurado

**Solução:**
- Verificar ISM configurado no warp route do BSC
- Verificar se há validadores ativos
- Verificar se checkpoints estão no S3

### 3. Whitelist incorreta

**Sintoma:** Mensagem detectada, mas filtrada

**Causa:** Sender ou recipient não permitidos na whitelist

**Solução:**
- Verificar configuração da whitelist em `relayer.testnet.json`
- Atualmente permite qualquer sender/recipient entre domínios 97 e 1325

## 📊 Status Esperado

### ✅ Sucesso

Você deve ver nos logs:

1. **Detecção:**
   ```
   Detected message from bsctestnet
   message_id: 0x...
   ```

2. **Checkpoints:**
   ```
   Fetching checkpoint for message 0x...
   Found checkpoint from validator
   ```

3. **Submissão:**
   ```
   Submitting message to terraclassictestnet
   Transaction hash: ...
   ```

4. **Confirmação:**
   ```
   Message delivered successfully
   ```

### ❌ Falha

Se algo falhar, você verá:

1. **Não detectado:**
   ```
   (nenhum log com o message ID)
   ```
   → Transação em bloco < 86149783

2. **Sem checkpoints:**
   ```
   No checkpoint found for message 0x...
   ```
   → Validadores não estão gerando checkpoints

3. **Erro de submissão:**
   ```
   Failed to submit message: ...
   ```
   → Problema com o relayer ou Terra Classic

## 🎯 Comandos Úteis

### Ver sincronização do BSC:
```bash
docker logs hpl-relayer-testnet 2>&1 | grep "bsctestnet" | grep -iE "(sequence|block)" | tail -20
```

### Ver mensagens do BSC:
```bash
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(dispatch.*bsc|message.*97)" | tail -20
```

### Ver erros do BSC:
```bash
docker logs hpl-relayer-testnet 2>&1 | grep -iE "(error|fail)" | grep -i "bsc" | tail -20
```

### Monitorar em tempo real:
```bash
docker logs hpl-relayer-testnet -f
```

---

**Data:** 2026-01-29  
**Status:** Pronto para teste  
**Próximo passo:** Envie uma transação de BSC para Terra Classic e monitore os logs
