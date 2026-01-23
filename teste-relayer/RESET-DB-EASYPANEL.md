# Guia: Resetar Database do Relayer no Easypanel

Este documento explica como resetar o database do relayer no Easypanel para aplicar correções no `index.from` e resolver problemas de sincronização.

---

## 🚨 Quando Resetar o Database

Você deve resetar o database do relayer quando:

- O `index.from` foi atualizado no `agent-config.docker-testnet.json`
- O relayer está tentando sincronizar blocos muito antigos
- Você está recebendo erros de "History has been pruned for this block"
- O relayer não está processando mensagens corretamente

---

## 📋 Passos para Resetar o Database no Easypanel

### 1️⃣ Parar o Relayer

1. Acesse o **Easypanel**
2. Navegue até o serviço `hpl-relayer-testnet`
3. Clique no botão **"Stop"** para parar o container

**⚠️ IMPORTANTE:** Sempre pare o serviço antes de manipular o database para evitar corrupção de dados.

---

### 2️⃣ Acessar o Terminal do Container

1. Com o serviço parado, clique no serviço `hpl-relayer-testnet`
2. Vá para a aba **"Terminal"** ou **"Shell"**
3. Você verá um prompt de terminal dentro do container

---

### 3️⃣ Deletar o Database

Execute o seguinte comando no terminal do container:

```bash
rm -rf /etc/data/db/*
```

**Verificação (opcional):**
Para confirmar que o diretório está vazio:

```bash
ls -la /etc/data/db/
```

A saída deve mostrar apenas `.` e `..`, indicando que o diretório está vazio.

---

### 4️⃣ Reiniciar o Relayer

1. Volte para a página principal do serviço no Easypanel
2. Clique no botão **"Start"** para reiniciar o relayer

O relayer criará um novo database e começará a sincronizar a partir do `index.from` configurado no `agent-config.docker-testnet.json`.

---

### 5️⃣ Verificar os Logs

Monitore os logs do relayer para confirmar que a sincronização está começando do bloco correto:

1. Vá para a aba **"Logs"** do serviço `hpl-relayer-testnet`
2. Procure por mensagens como:
   - `INFO hyperlane_base::contract_sync: Starting sync from block 86149783` (para BSC)
   - `INFO hyperlane_base::contract_sync: Starting sync from block 29139000` (para Terra Classic)
3. **Importante:** Você **NÃO** deve mais ver erros de "History has been pruned" para blocos antigos como `86000000`

---

## 🔍 Verificações Pós-Reset

### Verificar Sincronização do BSC

Nos logs, procure por:
```
INFO hyperlane_base::contract_sync: Found log(s) in index range, range: 86149783..=86149793
```

Se você ver ranges começando com `86149783` ou próximo, significa que o relayer está sincronizando do bloco correto.

### Verificar Sincronização do Terra Classic

Nos logs, procure por:
```
INFO hyperlane_base::contract_sync: Found log(s) in index range, range: 29139000..=29139010
```

Se você ver ranges começando com `29139000` ou próximo, significa que o relayer está sincronizando do bloco correto.

### Verificar Pool de Mensagens

Nos logs, procure por:
```
INFO lander::dispatcher::stages::finality_stage: Processing transactions in finality pool, pool_size: X
```

Se `pool_size > 0`, há mensagens aguardando para serem processadas.

---

## ⚠️ Avisos Importantes

### Perda de Dados

**ATENÇÃO:** Resetar o database **apagará todo o histórico de sincronização** do relayer. Isso significa:

- ✅ O relayer começará a sincronizar do `index.from` atualizado
- ❌ O relayer perderá o histórico de mensagens já processadas
- ❌ O relayer perderá os cursors de sincronização antigos

**Para testnet, isso geralmente não é um problema**, mas certifique-se de que você está ciente dessa perda de dados.

### Sincronização Inicial

Após resetar o database, o relayer precisará sincronizar os blocos desde o `index.from` até o bloco atual. Isso pode levar alguns minutos, dependendo de:

- A diferença entre o `index.from` e o bloco atual
- A velocidade dos RPCs
- A quantidade de logs para processar

---

## 🚨 Problemas Comuns Após Reset

### Problema 1: Relayer Ainda Mostra Erros de "History Pruned"

**Causa:** O relayer pode estar tentando buscar blocos antigos que ainda estão no cursor.

**Solução:**
1. Verifique se o `index.from` foi atualizado corretamente no `agent-config.docker-testnet.json`
2. Certifique-se de que o arquivo foi copiado para o container
3. Reinicie o relayer novamente após verificar

### Problema 2: Relayer Não Inicia

**Causa:** Pode haver um problema com as variáveis de ambiente ou configuração.

**Solução:**
1. Verifique os logs do relayer para identificar o erro específico
2. Verifique se todas as variáveis de ambiente estão configuradas no Easypanel
3. Verifique se o arquivo `relayer.testnet.json` tem os placeholders corretos

### Problema 3: Sincronização Muito Lenta

**Causa:** O `index.from` pode estar muito longe do bloco atual, ou os RPCs podem estar lentos.

**Solução:**
1. Aguarde alguns minutos para a sincronização inicial
2. Verifique se os RPCs estão respondendo corretamente
3. Considere atualizar o `index.from` para um bloco ainda mais recente (se necessário)

---

## 📝 Comandos Úteis

### Verificar o Database (dentro do container)

```bash
# Ver tamanho do database
du -sh /etc/data/db/

# Listar arquivos do database
ls -la /etc/data/db/

# Verificar se está vazio
[ -z "$(ls -A /etc/data/db/)" ] && echo "Database vazio" || echo "Database contém arquivos"
```

### Verificar Logs Específicos

```bash
# Ver logs de sincronização do BSC
docker logs hpl-relayer-testnet | grep -i "bsctestnet\|86149783"

# Ver logs de sincronização do Terra Classic
docker logs hpl-relayer-testnet | grep -i "terraclassic\|29139000"

# Ver erros
docker logs hpl-relayer-testnet | grep -i "error\|pruned\|failed"
```

---

## ✅ Checklist de Reset

Antes de resetar:

- [ ] Identifiquei o problema que requer reset do database
- [ ] Verifiquei que o `index.from` foi atualizado no `agent-config.docker-testnet.json`
- [ ] Tenho acesso ao Easypanel
- [ ] Entendo que os dados do database serão perdidos

Durante o reset:

- [ ] Parei o relayer no Easypanel
- [ ] Acessei o terminal do container
- [ ] Executei `rm -rf /etc/data/db/*`
- [ ] Verifiquei que o diretório está vazio
- [ ] Reiniciei o relayer

Após o reset:

- [ ] Verifiquei que o relayer iniciou corretamente
- [ ] Verifiquei que não há mais erros de "History pruned"
- [ ] Verifiquei que a sincronização está começando do bloco correto
- [ ] Monitorei os logs para confirmar funcionamento normal

---

**Última atualização:** 2026-01-23
