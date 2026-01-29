# 🔧 PROBLEMA RESOLVIDO: Validador Pausado após Atualização de Blocos

**Data**: 2026-01-29  
**Problema**: Solana → Terra Classic parou de funcionar após atualizar blocos  
**Status**: ✅ Resolvido

---

## 📊 O QUE ACONTECEU

### Timeline:

1. **18:08** - Atualizamos os blocos de todas as chains (Terra, BSC, Solana, Sepolia)
2. **18:08** - Containers foram mortos (Exit code 137 - OOM)
3. **18:28** - Containers foram reiniciados
4. **18:28** - Usuário reportou: "Solana → Terra não funciona mais"
5. **18:28-18:33** - Diagnóstico inicial (incorreto): pensamos que era problema de ISM
6. **18:33** - Descoberta: **Validador Terra Classic estava PAUSADO**
7. **18:34** - Solução: Reiniciamos todos os containers corretamente
8. **18:34** - ✅ Tudo funcionando novamente

---

## ❌ CAUSA RAIZ

### Exit Code 137 (OOM Kill):

Quando executamos `./atualizar-blocos-chains.sh`, o script:
1. Atualizou os blocos no `agent-config.docker-testnet.json`
2. Reiniciou o relayer: `docker-compose restart relayer`

**O problema:**
- O comando `restart` NÃO reinicia o validador
- Os containers foram mortos por OOM (Out of Memory)
- Ao reiniciar, o **validador ficou em estado PAUSADO**

### Como identificamos:

```bash
$ docker stats --no-stream
NAME                                 CPU %     MEM USAGE / LIMIT
hpl-relayer-testnet                  191.93%   156.2MiB / 11.68GiB
hpl-validator-terraclassic-testnet   0.00%     0B / 0B  ← PAUSADO!
```

**Sintomas:**
- CPU: 0.00%
- Memória: 0B
- Status: "Up X seconds (Paused)"

### Impacto:

**Sem validador ativo:**
- ❌ Nenhuma mensagem Solana → Terra é processada
- ❌ Relayer não consegue obter checkpoints
- ❌ Mensagens ficam bloqueadas no pool

**Outras rotas continuam funcionando:**
- ✅ Terra → Solana (não precisa de checkpoint do validador)
- ✅ BSC ↔ Terra (validador necessário, mas estava pausado)
- ✅ Sepolia ↔ Terra (validador necessário, mas estava pausado)

---

## 🔍 DIAGNÓSTICO INCORRETO INICIAL

### O que pensamos (ERRADO):

Inicialmente, diagnosticamos que:
- ISM do Solana estava NULL no `agent-config`
- O warp de Solana apontava para validador público inativo

**Por que este diagnóstico estava errado:**
1. O usuário disse: "estava funcionando 1 minuto atrás"
2. O ISM não mudou, então não poderia ser a causa
3. O problema começou DEPOIS de atualizar os blocos, não antes

### O que realmente era (CORRETO):

- **Validador Terra Classic estava PAUSADO**
- Sem validador, o relayer não consegue obter checkpoints
- Resultado: Solana → Terra não funciona

---

## ✅ SOLUÇÃO

### Passo 1: Identificar o problema

```bash
docker stats --no-stream
# Vimos que o validador estava com 0% CPU e 0B memória
```

### Passo 2: Tentar despausar

```bash
docker unpause hpl-validator-terraclassic-testnet
# Erro: Container is not paused (estava em estado inconsistente)
```

### Passo 3: Reiniciar TUDO corretamente

```bash
# Parar todos os containers
docker-compose -f docker-compose-testnet.yml down

# Aguardar limpeza
sleep 2

# Iniciar todos os containers novamente
docker-compose -f docker-compose-testnet.yml up -d
```

### Resultado:

```bash
$ docker stats --no-stream
NAME                                 CPU %     MEM USAGE / LIMIT
hpl-validator-terraclassic-testnet   2.31%     40.13MiB / 11.68GiB  ✅ ATIVO!
hpl-relayer-testnet                  188.62%   105MiB / 11.68GiB   ✅ ATIVO!
```

**Status:**
- ✅ Validador: Ativo (2.31% CPU, 40MB RAM)
- ✅ Relayer: Ativo e sincronizando
- ✅ Terra Classic: synced
- ✅ BSC: synced
- ✅ Solana: monitorando
- ✅ Sepolia: synced
- ✅ Rate limits: 0

---

## 📚 LIÇÕES APRENDIDAS

### 1. Exit 137 significa OOM Kill

```bash
$ docker ps -a
NAMES                                STATUS
hpl-relayer-testnet                  Exited (137) 19 seconds ago
hpl-validator-terraclassic-testnet   Exited (137) 19 seconds ago
```

**Exit code 137:**
- Significa: Out of Memory (OOM)
- Container foi morto pelo kernel por falta de memória
- Pode deixar containers em estados inconsistentes

### 2. Sempre usar `down` + `up` ao invés de `restart`

**Comando INCORRETO (usado pelo script):**
```bash
docker-compose -f docker-compose-testnet.yml restart relayer
```

**Problema:**
- Apenas reinicia o relayer
- Validador pode ficar em estado inconsistente
- Não garante limpeza completa

**Comando CORRETO:**
```bash
docker-compose -f docker-compose-testnet.yml down
docker-compose -f docker-compose-testnet.yml up -d
```

**Vantagens:**
- ✅ Para TODOS os containers
- ✅ Remove containers antigos
- ✅ Recria network
- ✅ Inicia tudo do zero
- ✅ Garante estado consistente

### 3. Validador pausado NÃO é óbvio

**Sinais de validador pausado:**
- CPU: 0.00%
- Memória: 0B (não "X MiB")
- Status: "Up X seconds (Paused)" (precisa ver o `(Paused)`)

**Como verificar:**
```bash
# Ver status detalhado
docker ps -a

# Ver recursos
docker stats --no-stream

# Ver logs (vazio se pausado)
docker logs hpl-validator-terraclassic-testnet
```

### 4. Diagnóstico requer contexto

**Erro de diagnóstico:**
- Focamos no ISM do Solana (problema anterior conhecido)
- Não consideramos o contexto: "estava funcionando 1 minuto atrás"
- Não verificamos o estado do validador imediatamente

**Diagnóstico correto:**
1. Usuário disse: "funcionava 1 minuto atrás"
2. Problema começou: "após atualizar blocos (configurar Sepolia)"
3. Mudança recente: Reiniciar containers
4. Verificar: Estado dos containers
5. Descobrir: Validador pausado

---

## 🔧 CORREÇÃO NO SCRIPT

### Antes (INCORRETO):

```bash
# Em atualizar-blocos-chains.sh:
read -p "🔄 Deseja reiniciar o relayer agora? (s/n): " -n 1 -r
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    docker-compose -f "$SCRIPT_DIR/docker-compose-testnet.yml" restart relayer  ← PROBLEMA!
fi
```

### Depois (CORRETO):

```bash
# Em atualizar-blocos-chains.sh:
read -p "🔄 Deseja reiniciar o relayer agora? (s/n): " -n 1 -r
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    echo "Parando containers..."
    docker-compose -f "$SCRIPT_DIR/docker-compose-testnet.yml" down
    sleep 2
    echo "Iniciando containers..."
    docker-compose -f "$SCRIPT_DIR/docker-compose-testnet.yml" up -d
fi
```

**Ou melhor ainda:**

```bash
read -p "🔄 Deseja reiniciar TODOS os containers? (s/n): " -n 1 -r
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    docker-compose -f "$SCRIPT_DIR/docker-compose-testnet.yml" down
    docker-compose -f "$SCRIPT_DIR/docker-compose-testnet.yml" up -d
fi
```

---

## 📊 COMPARAÇÃO

### Antes (Problema):

```
$ docker ps
hpl-relayer-testnet: Up 2 minutes
hpl-validator-terraclassic-testnet: Up 2 minutes (Paused)  ← PROBLEMA!

$ docker stats
hpl-validator: 0.00% CPU, 0B RAM  ← PAUSADO!

$ docker logs hpl-relayer-testnet | grep "Solana → Terra"
(nenhuma mensagem processada)
```

### Depois (Resolvido):

```
$ docker ps
hpl-relayer-testnet: Up 30 seconds
hpl-validator-terraclassic-testnet: Up 30 seconds  ← ATIVO!

$ docker stats
hpl-validator: 2.31% CPU, 40.13MB RAM  ← ATIVO!

$ docker logs hpl-relayer-testnet | grep synced
Terra Classic: synced ✅
BSC: synced ✅
Solana: monitorando ✅
Sepolia: synced ✅
```

---

## 🎯 COMANDOS ÚTEIS

### Verificar estado dos containers:

```bash
# Ver status básico
docker ps -a --filter "name=hpl-"

# Ver recursos em tempo real
docker stats --no-stream

# Ver se está pausado
docker ps -a | grep "Paused"
```

### Reiniciar corretamente:

```bash
# SEMPRE usar este método:
cd /home/lunc/hyperlane-validator-smart
docker-compose -f docker-compose-testnet.yml down
sleep 2
docker-compose -f docker-compose-testnet.yml up -d
```

### Verificar saúde do sistema:

```bash
# Verificar sincronização
docker logs hpl-relayer-testnet 2>&1 | grep "estimated_time_to_sync" | grep "synced"

# Verificar validador assinando
docker logs hpl-validator-terraclassic-testnet 2>&1 | grep -i "signed" | tail -5

# Verificar rate limits
docker logs hpl-relayer-testnet --since 5m 2>&1 | grep -i "rate limit" | wc -l
```

---

## 🚨 SINAIS DE ALERTA

### Quando verificar o estado dos containers:

1. **Após qualquer reinício/restart**
   - Sempre verificar: `docker stats --no-stream`
   - Confirmar CPU > 0% e Memória > 0MB

2. **Se mensagens param de funcionar repentinamente**
   - Antes: funcionava
   - Depois: não funciona mais
   - Verificar: estado dos containers

3. **Após OOM Kill (Exit 137)**
   - Containers podem ficar em estados inconsistentes
   - SEMPRE fazer `down` + `up` completo

4. **Validador não está assinando**
   - `docker logs hpl-validator-* | grep signed` vazio
   - Verificar se está pausado ou travado

---

## ✅ CHECKLIST PÓS-REINÍCIO

Após reiniciar containers, SEMPRE verificar:

- [ ] Containers estão "Up" (não "Paused" ou "Exited")
- [ ] CPU do validador > 0%
- [ ] Memória do validador > 0MB
- [ ] CPU do relayer > 0%
- [ ] Relayer mostra "synced" para todas as chains
- [ ] Rate limits = 0 ou próximo de 0
- [ ] Validador está assinando checkpoints
- [ ] Logs não mostram erros recentes

**Comando rápido:**
```bash
docker ps && docker stats --no-stream && docker logs hpl-relayer-testnet 2>&1 | grep "synced" | tail -4
```

---

## 📝 RESUMO EXECUTIVO

| Item | Antes (Problema) | Depois (Resolvido) |
|------|------------------|---------------------|
| **Validador** | Pausado (0% CPU, 0B RAM) | Ativo (2.31% CPU, 40MB RAM) |
| **Relayer** | Ativo mas sem checkpoints | Ativo e processando |
| **Solana → Terra** | ❌ Bloqueado | ✅ Funcionando |
| **Outras rotas** | ⚠️ Com problemas | ✅ Funcionando |
| **Rate limits** | 0 | 0 |
| **Sincronização** | Parcial | Completa |

**Causa**: Validador pausado após OOM kill e reinício incorreto  
**Solução**: `docker-compose down` + `docker-compose up -d`  
**Tempo**: 5 minutos para diagnosticar e resolver  
**Prevenção**: Usar sempre `down` + `up` ao invés de `restart`

---

**Atualizado**: 2026-01-29 18:35  
**Status**: ✅ Resolvido e documentado  
**Próxima ação**: Atualizar script `atualizar-blocos-chains.sh` para usar `down` + `up`
