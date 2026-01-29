# 🔧 Como Resetar o Relayer Manualmente

## ❌ Problema

O database do relayer foi criado como root, então não consigo removê-lo sem sudo. Além disso, o database antigo ainda está com `index.from: 375964820`, o que faz o relayer NÃO sincronizar desde o início.

## ✅ SOLUÇÃO - Execute Manualmente

### Passo 1: Parar o relayer

```bash
cd /home/lunc/hyperlane-validator-smart
docker-compose -f docker-compose-testnet.yml stop relayer
```

### Passo 2: Remover o database antigo (precisa sudo)

```bash
# Com sudo (vai pedir sua senha)
sudo rm -rf ./relayer-testnet/db/*

# OU, se quiser fazer backup antes:
sudo mv ./relayer-testnet/db ./relayer-testnet/db-backup-$(date +%Y%m%d)
sudo mkdir -p ./relayer-testnet/db
```

### Passo 3: Verificar que mudamos o index.from

O arquivo `hyperlane/agent-config.docker-testnet.json` já foi alterado:
- ✅ `index.from: 375964820` → `index.from: 1`

Verifique se a alteração está lá:
```bash
grep -A 3 "index" hyperlane/agent-config.docker-testnet.json | grep -A 2 "solanatestnet" -B 5
```

Deve mostrar:
```json
      "index": {
        "from": 1,
        "chunk": 10
      }
```

### Passo 4: Reiniciar o relayer

```bash
cd /home/lunc/hyperlane-validator-smart
docker-compose -f docker-compose-testnet.yml start relayer
```

### Passo 5: Monitorar logs

```bash
# Ver se está começando do bloco/sequence 1
docker logs hpl-relayer-testnet 2>&1 | grep "lowest_block_height_or_sequence" | head -10

# Deve mostrar algo como:
# lowest_block_height_or_sequence: 1
# (E NÃO 375964820 como antes)
```

```bash
# Monitorar em tempo real
docker logs hpl-relayer-testnet -f | grep -iE "(sequence|solana|message)"
```

```bash
# Procurar sua mensagem específica
docker logs hpl-relayer-testnet 2>&1 | grep -i "7a21bc73"
```

## 📊 O Que Esperar

### 1. Após reiniciar com database limpo:

O relayer vai começar a sincronizar desde o **slot/sequence 1** de Solana.

Você vai ver logs como:
```
lowest_block_height_or_sequence: 1, current_sequence_count: 674
```

### 2. Tempo de sincronização:

- **Pode demorar horas** para sincronizar desde o slot 1 até o atual
- Solana testnet tem milhares (ou milhões) de slots
- O relayer processa em chunks de 10 blocos de cada vez

### 3. Quando sua mensagem for detectada:

Procure nos logs por:
```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "7a21bc73"
```

Se aparecer, significa que o relayer detectou sua mensagem!

## ⚠️ Próximo Problema Possível

Mesmo que o relayer detecte a mensagem, ela pode não ser entregue se:

### 1. ISM não tem validadores ativos

O ISM que você configurou no warp route de Solana precisa ter:
- Validadores rodando
- Validadores gerando checkpoints no S3
- Checkpoints disponíveis para ESSA mensagem específica

### 2. Checkpoints não estão disponíveis

Se os validadores do ISM:
- Começaram a rodar DEPOIS da sua mensagem
- Não estão rodando mais
- Não geraram checkpoints para essa mensagem

Então o relayer vai detectar a mensagem mas NÃO conseguir entregar.

### 3. Threshold não é atingido

Se o ISM requer 2 assinaturas mas só 1 validator está ativo, a mensagem não será entregue.

## 🔍 Como Verificar se Funcionou

### 1. Verificar que o relayer está sincronizando desde o início:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep "lowest_block_height_or_sequence.*1"
```

Deve retornar linhas com `lowest_block_height_or_sequence: 1`

### 2. Procurar sua mensagem:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "7a21bc73"
```

Se não retornar nada, significa que o relayer ainda não chegou no bloco da sua mensagem.

### 3. Ver progresso:

```bash
docker logs hpl-relayer-testnet 2>&1 | grep -i "sequence" | tail -20
```

Veja qual sequence o relayer está atualmente. Quando chegar perto da sua, a mensagem será detectada.

## 📋 Checklist Completo

Execute na ordem:

- [ ] Parar relayer
- [ ] Remover database com sudo: `sudo rm -rf ./relayer-testnet/db/*`
- [ ] Criar diretório limpo: `sudo mkdir -p ./relayer-testnet/db`
- [ ] Verificar index.from: deve estar em 1 (não 375964820)
- [ ] Iniciar relayer
- [ ] Aguardar 1-2 minutos
- [ ] Verificar logs: `docker logs hpl-relayer-testnet 2>&1 | grep "lowest.*1"`
- [ ] Monitorar progresso: `docker logs hpl-relayer-testnet -f`
- [ ] Aguardar sincronização (pode demorar horas!)
- [ ] Procurar mensagem: `docker logs hpl-relayer-testnet 2>&1 | grep -i "7a21bc73"`

## 🆘 Se Ainda Não Funcionar

Se mesmo após tudo isso a mensagem não for entregue, o problema é um dos seguintes:

1. **Faltam validadores públicos ativos para Solana testnet**
   - Precisa verificar se há validadores do Hyperlane rodando para Solana testnet
   - Precisa verificar se esses validadores estão gerando checkpoints

2. **ISM configurado no warp route não tem validadores suficientes**
   - Ver qual ISM está configurado no warp route
   - Verificar quantos validadores o ISM tem
   - Verificar se esses validadores estão ativos

3. **Mensagem foi enviada antes dos validadores começarem**
   - Se os validadores começaram a rodar DEPOIS da sua mensagem
   - Eles não têm checkpoints para ela
   - Solução: Enviar nova mensagem agora que o relayer está pronto

---

**Última atualização:** 2026-01-29  
**Message ID:** `0x7a21bc732cadf3a39f4bdd33f0d33b49801e56f876d8998056d86b1e7f482f66`  
**Próximo passo:** Executar os passos acima manualmente com sudo
