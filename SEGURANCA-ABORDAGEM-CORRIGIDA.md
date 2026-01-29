# 🔧 SEGURANÇA: Abordagem Corrigida

Data: 2026-01-29

---

## ✅ CORREÇÃO APLICADA

O usuário corretamente apontou que o arquivo `relayer.testnet.json` contém **configurações importantes além das chaves**:

- `relayChains` - Chains que o relayer monitora
- `whitelist` - Rotas permitidas para mensagens
- `allowLocalCheckpointSyncers` - Configuração de sincronização
- `gasPaymentEnforcement` - Políticas de pagamento de gas

**Essas configurações devem estar no Git para versionamento!**

---

## 🎯 NOVA ABORDAGEM

### Antes (Incorreto):
```
❌ Arquivo removido do git tracking
❌ Configurações hardcoded no docker-compose
❌ Mudanças de config requerem edição do docker-compose
```

### Agora (Correto):
```
✅ Arquivo MANTIDO no git
✅ Configurações versionadas
✅ Chaves sempre vazias no arquivo
✅ Docker-compose injeta chaves em runtime
✅ Mudanças de config = apenas editar o arquivo
```

---

## 🔐 COMO FUNCIONA

### 1. Arquivo no Git (`relayer.testnet.json`):

```json
{
  "relayChains": "terraclassictestnet,bsctestnet,solanatestnet",
  "allowLocalCheckpointSyncers": "true",
  "whitelist": [
    {
      "originDomain": [1325],
      "destinationDomain": [97]
    }
  ],
  "chains": {
    "bsctestnet": {
      "signer": {
        "type": "hexKey",
        "key": ""           ← SEMPRE VAZIO no git
      }
    }
  }
}
```

### 2. Docker-compose injeta as chaves:

```bash
# 1. Copia o arquivo para /tmp/
cp "/etc/hyperlane/relayer.testnet.json" "/tmp/relayer.testnet.json"

# 2. Injeta chaves do .env via sed
sed -i '0,/"bsctestnet".*"key": ""/{s/"key": ""/"key": "'"${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}"'"/}' \
  "/tmp/relayer.testnet.json"

# 3. Executa o relayer apontando para /tmp/
CONFIG_FILES="/tmp/relayer.testnet.json" ./relayer
```

### 3. Resultado:

```
📄 /etc/hyperlane/relayer.testnet.json (host)
   ├─ Tem todas as configurações ✅
   ├─ Chaves vazias ✅
   └─ Versionado no git ✅

📄 /tmp/relayer.testnet.json (container)
   ├─ Cópia do arquivo acima ✅
   ├─ Chaves injetadas do .env ✅
   └─ Usado pelo relayer ✅
```

---

## 🛡️ PROTEÇÃO DE SEGURANÇA

### Checklist antes de commit:

```bash
# 1. Verificar que as chaves estão vazias
grep -E '"key": ".+"' hyperlane/relayer.testnet.json
# Deve retornar NADA (ou apenas "key": "")

# 2. Verificar configurações
cat hyperlane/relayer.testnet.json | jq '.whitelist'
# Deve mostrar a whitelist corretamente

# 3. Status do git
git diff hyperlane/relayer.testnet.json
# Verificar que não há chaves sendo adicionadas
```

### Git hook (opcional):

Você pode criar um hook para prevenir commits com chaves:

```bash
# .git/hooks/pre-commit
#!/bin/bash
if grep -q '"key": "0x[a-f0-9]\{64\}"' hyperlane/relayer.testnet.json; then
  echo "❌ ERROR: Private keys detected in relayer.testnet.json!"
  echo "         Please remove all keys before committing."
  exit 1
fi
```

---

## 📝 VANTAGENS DESTA ABORDAGEM

### ✅ Versionamento de Configuração:
- Mudanças na whitelist são rastreadas
- Histórico de configurações preservado
- Fácil rollback se necessário

### ✅ Segurança:
- Chaves nunca commitadas
- Arquivo no host sempre vazio
- Chaves apenas em /tmp/ do container

### ✅ Facilidade de Uso:
- Editar configurações = editar arquivo JSON
- Não precisa mexer no docker-compose
- Reiniciar container para aplicar mudanças

---

## 🔄 FLUXO DE TRABALHO

### Mudando configurações:

```bash
# 1. Editar o arquivo
nano hyperlane/relayer.testnet.json

# 2. Verificar que chaves estão vazias
grep '"key"' hyperlane/relayer.testnet.json

# 3. Testar localmente
docker-compose -f docker-compose-testnet.yml restart relayer

# 4. Commit se tudo OK
git add hyperlane/relayer.testnet.json
git commit -m "config: update whitelist for new route"
git push
```

### Adicionando nova route:

```json
{
  "whitelist": [
    {
      "originDomain": [1325],
      "destinationDomain": [97]
    },
    {
      "originDomain": [97],      ← Nova route
      "destinationDomain": [1399811150]
    }
  ]
}
```

---

## ⚠️ IMPORTANTE

### O que DEVE estar no arquivo:
- ✅ `relayChains`
- ✅ `whitelist`
- ✅ `allowLocalCheckpointSyncers`
- ✅ `gasPaymentEnforcement`
- ✅ Estrutura de `chains` com chaves **VAZIAS**

### O que NÃO DEVE estar no arquivo:
- ❌ Chaves privadas (sempre `"key": ""`)
- ❌ Tokens de API
- ❌ Senhas
- ❌ Qualquer credencial

---

## 📊 COMPARAÇÃO

### Abordagem Anterior (Descartada):
```
Arquivo: Removido do git
Configs: Hardcoded no docker-compose
Mudanças: Editar docker-compose
Segurança: ✅ Máxima
Manutenção: ❌ Difícil
Versionamento: ❌ Perdido
```

### Abordagem Atual (Implementada):
```
Arquivo: No git (chaves vazias)
Configs: No arquivo JSON
Mudanças: Editar JSON e reiniciar
Segurança: ✅ Máxima
Manutenção: ✅ Fácil
Versionamento: ✅ Completo
```

---

## 🎯 RESULTADO

**Melhor dos dois mundos:**

1. ✅ Segurança mantida (chaves nunca no git)
2. ✅ Configurações versionadas (whitelist, etc)
3. ✅ Fácil manutenção (editar JSON)
4. ✅ Flexibilidade (mudanças sem tocar docker-compose)

---

**Status**: 🔒 **SEGURO E FLEXÍVEL**

Esta abordagem combina segurança máxima com facilidade de manutenção e versionamento adequado.
