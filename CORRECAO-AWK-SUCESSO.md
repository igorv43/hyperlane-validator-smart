# ✅ CORREÇÃO: AWK para Injeção de Chaves

Data: 2026-01-29

---

## 🐛 PROBLEMA IDENTIFICADO

Após implementar a injeção de chaves via `sed`, descobrimos que **todas as 3 chaves estavam com o MESMO valor** (chave do BSC):

```json
{
  "chains": {
    "bsctestnet": {
      "signer": { "key": "0x819b680e..." }       ← BSC key
    },
    "solanatestnet": {
      "signer": { "key": "0x819b680e..." }       ← MESMA! (errado)
    },
    "terraclassictestnet": {
      "signer": { "key": "0x819b680e..." }       ← MESMA! (errado)
    }
  }
}
```

**Resultado**: Solana → Terra não funcionava porque estava usando a chave errada!

---

## 🔍 CAUSA RAIZ

O `sed` com padrão `0,/"bsctestnet".*"key": ""/{...}` não funcionava porque:

1. `"bsctestnet"` e `"key": ""` estão em **linhas diferentes** no JSON
2. O `sed` substituía a **primeira ocorrência de `"key": ""`** três vezes
3. Resultado: mesma chave (BSC) nas 3 chains

---

## ✅ SOLUÇÃO: Usar AWK

AWK é **muito melhor para processar texto estruturado** linha por linha:

```bash
awk -v bsc="${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" \
    -v sol="${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}" \
    -v terra="${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}" \
    '{
      # Detectar qual seção estamos
      if ($0 ~ /"bsctestnet"/) { in_bsc=1; in_sol=0; in_terra=0 }
      else if ($0 ~ /"solanatestnet"/) { in_bsc=0; in_sol=1; in_terra=0 }
      else if ($0 ~ /"terraclassictestnet"/) { in_bsc=0; in_sol=0; in_terra=1 }
      
      # Substituir a chave na seção correta
      if ($0 ~ /"key": ""/ && in_bsc) { 
        sub(/"key": ""/, "\"key\": \"" bsc "\""); in_bsc=0 
      }
      else if ($0 ~ /"key": ""/ && in_sol) { 
        sub(/"key": ""/, "\"key\": \"" sol "\""); in_sol=0 
      }
      else if ($0 ~ /"key": "",/ && in_terra) { 
        sub(/"key": "",/, "\"key\": \"" terra "\","); in_terra=0 
      }
      
      print
    }' "/etc/hyperlane/relayer.testnet.json" > "/tmp/relayer.testnet.json"
```

### Como funciona:

1. **Detecta** quando entra em cada seção (`bsctestnet`, `solanatestnet`, `terraclassictestnet`)
2. **Rastreia** em qual seção está usando flags (`in_bsc`, `in_sol`, `in_terra`)
3. **Substitui** a chave apenas quando encontra `"key": ""` dentro da seção correta
4. **Reseta** a flag após substituir para não substituir novamente

---

## 📊 RESULTADO

### Antes (sed - errado):
```json
"bsctestnet":        "key": "0x819b680e..." ← BSC
"solanatestnet":     "key": "0x819b680e..." ← ERRADO
"terraclassictestnet": "key": "0x819b680e..." ← ERRADO
```

### Depois (awk - correto):
```json
"bsctestnet":        "key": "0x819b680e..." ← BSC ✅
"solanatestnet":     "key": "0x7c2d098a..." ← Solana ✅
"terraclassictestnet": "key": "0xa5123190..." ← Terra ✅
```

---

## ✅ VERIFICAÇÃO

```bash
# 1. Verificar chaves diferentes no container
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | grep "key"

# Saída:
#   "key": "0x819b680e..." ← BSC
#   "key": "0x7c2d098a..." ← Solana (diferente!)
#   "key": "0xa5123190..." ← Terra (diferente!)

# 2. Verificar arquivo no host ainda vazio
grep '"key":' hyperlane/relayer.testnet.json

# Saída:
#   "key": ""
#   "key": ""
#   "key": ""

# 3. Relayer funcionando
docker ps --filter "name=hpl-relayer"

# Status: Up X seconds ✅
```

---

## 🎯 VANTAGENS DO AWK

### vs sed:
- ✅ Processa linha por linha com contexto
- ✅ Pode manter estado entre linhas (flags)
- ✅ Mais legível para lógica complexa
- ✅ Nativo em containers Unix

### vs jq:
- ✅ Disponível em containers minimalistas
- ✅ Não requer instalação adicional
- ✅ Mais rápido para substituições simples
- ✅ Menor uso de memória

---

## 🔐 SEGURANÇA MANTIDA

- ✅ Arquivo no host sempre com chaves vazias
- ✅ Chaves injetadas apenas em `/tmp/` do container
- ✅ Chaves lidas do `.env` (não commitadas)
- ✅ Processo executado em runtime (nunca em build)

---

## 📝 CÓDIGO FINAL (docker-compose-testnet.yml)

```yaml
command:
  - |
    rm -rf /app/config/* && \
    cp "/etc/hyperlane/agent-config.docker-testnet.json" "/app/config/agent-config.json" && \
    
    # Validar chaves
    if [ -z "${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" ] || \
       [ -z "${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}" ] || \
       [ -z "${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}" ]; then
      echo "ERROR: Signer keys are required!"
      exit 1
    fi && \
    
    # Injetar chaves usando AWK
    awk -v bsc="${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" \
        -v sol="${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}" \
        -v terra="${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}" \
        '{
          if ($0 ~ /"bsctestnet"/) { in_bsc=1; in_sol=0; in_terra=0 }
          else if ($0 ~ /"solanatestnet"/) { in_bsc=0; in_sol=1; in_terra=0 }
          else if ($0 ~ /"terraclassictestnet"/) { in_bsc=0; in_sol=0; in_terra=1 }
          if ($0 ~ /"key": ""/ && in_bsc) { sub(/"key": ""/, "\"key\": \"" bsc "\""); in_bsc=0 }
          else if ($0 ~ /"key": ""/ && in_sol) { sub(/"key": ""/, "\"key\": \"" sol "\""); in_sol=0 }
          else if ($0 ~ /"key": "",/ && in_terra) { sub(/"key": "",/, "\"key\": \"" terra "\","); in_terra=0 }
          print
        }' "/etc/hyperlane/relayer.testnet.json" > "/tmp/relayer.testnet.json" && \
    
    echo "✅ Relayer config loaded from file and keys injected from .env" && \
    
    CONFIG_FILES="/tmp/relayer.testnet.json" \
      ./relayer --allowLocalCheckpointSyncers false --metrics 0.0.0.0:9090 --api 0.0.0.0:9090
```

---

## 🎉 RESULTADO FINAL

**Solana → Terra Classic agora funciona!** ✅

- Relayer detecta mensagens Solana
- Usa a chave correta do Solana
- Entrega mensagens no Terra Classic
- Arquivo no host permanece seguro (chaves vazias)

---

Status: **CORRIGIDO E OPERACIONAL** 🚀

Problema: Chaves duplicadas (sed)  
Solução: AWK com contexto de seção  
Resultado: 3 chaves diferentes injetadas corretamente
