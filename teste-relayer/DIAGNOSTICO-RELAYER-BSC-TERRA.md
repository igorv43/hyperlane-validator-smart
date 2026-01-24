# 🔍 Diagnóstico: Relayer BSC -> Terra Classic

## ✅ Status do Container

- **Container:** `hpl-relayer-testnet-local`
- **Status:** ✅ Rodando (Up 46 minutos)
- **Porta:** 19010 mapeada

## 📊 Resultados do Diagnóstico

### 1. Sincronização das Chains

- ✅ **BSC:** Sincronizando (bloco atual: ~86192094)
- ✅ **Terra Classic:** Sincronizando (bloco atual: ~29143548)
- ✅ **Solana:** Sincronizando

### 2. Detecção de Mensagens

- ⚠️ **Mensagem sequence 12768:** Não encontrada nos logs recentes
- ⚠️ **Última mensagem detectada:** Sequence 12751 (bloco 86149783)
- ⚠️ **Problema:** Mensagem 12768 pode estar em bloco posterior ao `index.from` configurado

### 3. Pool de Mensagens

- ❌ **Pool size:** 0 (nenhuma mensagem sendo processada)
- ⚠️ **Problema:** Mensagens detectadas não estão entrando no pool

### 4. Checkpoints e Validators

- ❌ **Nenhuma tentativa de ler checkpoints encontrada nos logs**
- ⚠️ **Problema:** Relayer não está tentando ler checkpoints do S3

### 5. Configuração

- ✅ Credenciais AWS configuradas
- ✅ Chaves de signer configuradas
- ✅ Arquivos de configuração existem

## 🎯 Problemas Identificados

### Problema 1: Mensagem Não Detectada

A mensagem sequence 12768 pode estar em um bloco que o relayer ainda não indexou, ou pode estar antes do `index.from` configurado.

**Verificar:**
- Bloco onde a mensagem 12768 foi enviada
- Se o `index.from` do BSC está antes desse bloco

### Problema 2: Pool Size = 0

O pool está vazio, o que significa que:
- Mensagens não estão sendo detectadas, OU
- Mensagens estão sendo detectadas mas não estão entrando no pool (falta de checkpoints/quorum)

### Problema 3: Nenhuma Tentativa de Ler Checkpoints

O relayer não está tentando ler checkpoints do S3. Isso pode significar:
- Relayer não está descobrindo validators
- Validators não têm storage locations anunciadas
- Relayer não está tentando validar mensagens

## 📋 Próximos Passos

1. **Verificar bloco da mensagem 12768:**
   ```bash
   # Consultar no BSC qual bloco contém a mensagem 12768
   ```

2. **Verificar se relayer está descobrindo validators:**
   ```bash
   docker logs hpl-relayer-testnet-local --tail 2000 | grep -i "validator.*announce\|discover.*validator"
   ```

3. **Verificar se há mensagens sendo detectadas mas não processadas:**
   ```bash
   docker logs hpl-relayer-testnet-local --tail 2000 | grep -iE "message.*detected|found.*message|sequence"
   ```

4. **Verificar logs completos para erros:**
   ```bash
   docker logs hpl-relayer-testnet-local --tail 5000 > relayer-logs-completo.txt
   ```

## 🔧 Soluções Recomendadas

1. **Verificar se validators anunciaram buckets S3 no Terra Classic**
   - Já confirmado: Validators NÃO têm storage locations anunciadas

2. **Verificar se validators estão gerando checkpoints**
   - Verificar logs dos validators
   - Verificar se há arquivos no S3

3. **Ajustar `index.from` se necessário**
   - Se a mensagem 12768 está antes do `index.from`, ajustar

4. **Verificar se há quorum suficiente**
   - ISM requer 2 de 3 validators
   - Verificar se pelo menos 2 validators estão gerando checkpoints
