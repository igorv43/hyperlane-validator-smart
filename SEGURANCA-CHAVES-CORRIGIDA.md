# 🔒 SEGURANÇA: Correção de Chaves Privadas

## 🚨 PROBLEMA IDENTIFICADO

**Chaves privadas estavam EXPOSTAS nos arquivos de configuração!**

### Arquivos Afetados:
- ❌ `hyperlane/relayer.testnet.json` - Chaves hardcoded
- ❌ `hyperlane/validator.terraclassic-testnet.json` - Chaves hardcoded
- ⚠️ `.gitignore` - Linhas comentadas não protegiam os arquivos

### Risco:
Se esses arquivos fossem commitados ao git, as chaves privadas ficariam **expostas publicamente**!

---

## ✅ CORREÇÕES APLICADAS

### 1. Limpeza das Chaves nos Arquivos

**Antes:**
```json
{
  "signer": {
    "type": "hexKey",
    "key": "0x819b680e3578eac4f79b8fde643046e88f3f9bb10a3ce1424e3642798ef39b42"
  }
}
```

**Depois:**
```json
{
  "signer": {
    "type": "hexKey",
    "key": ""
  }
}
```

### 2. Atualização do `.gitignore`

**Antes (linhas comentadas):**
```
# hyperlane/validator.*.json
# hyperlane/relayer*.json
```

**Depois (proteção ativa):**
```
# Arquivos de configuração com chaves privadas (CRÍTICO)
hyperlane/validator.*.json
!hyperlane/validator.*.json.example
hyperlane/relayer.json
hyperlane/relayer.*.json
!hyperlane/relayer.*.json.example
```

### 3. Correção do docker-compose-testnet.yml

**Antes (substituição incorreta):**
```bash
sed -i "s|0xYOUR_PRIVATE_KEY_HERE|${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}|g"
```

**Depois (substituição precisa por chain):**
```bash
sed -i '/"bsctestnet"/,/"key"/ s|"key": ""|"key": "'"${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}"'"|'
sed -i '/"solanatestnet"/,/"key"/ s|"key": ""|"key": "'"${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}"'"|'
sed -i '/"terraclassictestnet"/,/"key"/ s|"key": ""|"key": "'"${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}"'"|'
```

### 4. Criação de Arquivos `.example`

Criados templates seguros:
- ✅ `hyperlane/relayer.testnet.json.example`
- ✅ `hyperlane/validator.terraclassic-testnet.json.example`

Esses arquivos `.example` podem ser commitados ao git com segurança.

---

## 🔐 BOAS PRÁTICAS IMPLEMENTADAS

### 1. Separação de Configuração e Credenciais

```
┌─────────────────────────────────────┐
│ .env (NÃO commitado)                │
│ ├─ HYP_CHAINS_BSCTESTNET_SIGNER_KEY │
│ ├─ HYP_CHAINS_SOLANATESTNET_SIGNER  │
│ └─ HYP_CHAINS_TERRACLASSIC_SIGNER   │
└─────────────────────────────────────┘
            ↓ (injeção no runtime)
┌─────────────────────────────────────┐
│ Docker Container                    │
│ ├─ Lê .env                          │
│ ├─ Substitui chaves vazias          │
│ └─ Executa agente com chaves reais  │
└─────────────────────────────────────┘
```

### 2. Proteção em Múltiplas Camadas

1. **`.gitignore`**: Impede commit acidental
2. **Arquivos vazios**: Templates sem chaves
3. **`.example`**: Documentação segura
4. **Runtime injection**: Chaves apenas no container

### 3. Validação de Chaves

O validator já valida se as chaves estão vazias:

```bash
if [ -z "${HYP_VALIDATOR_KEY}" ] || [ "${HYP_VALIDATOR_KEY}" = "" ]; then
  echo "ERROR: HYP_VALIDATOR_KEY is required and cannot be empty!"
  exit 1
fi
```

---

## 📋 VERIFICAÇÃO

### Arquivos que DEVEM estar vazios:
```bash
# Verificar se as chaves estão vazias
grep -E '"key": ".+"' hyperlane/relayer.testnet.json
grep -E '"key": ".+"' hyperlane/validator.terraclassic-testnet.json

# Se não retornar nada = ✅ Seguro
# Se retornar chaves = ❌ Inseguro
```

### Arquivos protegidos pelo `.gitignore`:
```bash
# Testar se o git está ignorando
git check-ignore hyperlane/relayer.testnet.json
git check-ignore hyperlane/validator.terraclassic-testnet.json

# Se retornar o nome do arquivo = ✅ Protegido
# Se não retornar nada = ❌ Desprotegido
```

---

## ⚠️ IMPORTANTE: Rotação de Chaves

**As chaves que estavam expostas devem ser consideradas comprometidas!**

### Recomendações:

1. **Gerar novas chaves**:
```bash
# BSC
cast wallet new

# Solana
solana-keygen new

# Terra Classic
terrad keys add new-key
```

2. **Transferir fundos** das contas antigas para as novas

3. **Atualizar `.env`** com as novas chaves

4. **Reiniciar os serviços**:
```bash
docker-compose -f docker-compose-testnet.yml down
docker-compose -f docker-compose-testnet.yml up -d
```

---

## 🎯 RESULTADO

### ✅ Antes de commit ao git:
```bash
# Verificar que nenhuma chave está presente
grep -rn "0x[a-f0-9]\{64\}" hyperlane/*.json

# Verificar status do git
git status --ignored

# Commit seguro
git add .
git commit -m "docs: documentação e correções de segurança"
git push
```

### ✅ Agentes funcionando com segurança:
- Relayer lê chaves do `.env` no runtime ✅
- Validator lê chaves do `.env` no runtime ✅
- Arquivos de config não contêm chaves ✅
- `.gitignore` protege arquivos sensíveis ✅

---

## 📚 REFERÊNCIAS

- [12 Factor App: Config](https://12factor.net/config)
- [OWASP: Secrets Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)

---

Data: 2026-01-29
Status: ✅ CORRIGIDO E SEGURO
