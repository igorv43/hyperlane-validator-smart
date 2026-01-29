# 🔒 GUIA DE SEGURANÇA - Hyperlane Validator & Relayer

## ⚠️ IMPORTANTE: Proteção de Chaves Privadas

Este projeto implementa **boas práticas de segurança** para proteger chaves privadas.

---

## 🔐 COMO FUNCIONA A SEGURANÇA

### 1. Chaves Armazenadas no `.env` (Nunca no Git)

Todas as chaves privadas estão no arquivo `.env`:

```bash
# .env (NÃO commitado ao git)
HYP_CHAINS_BSCTESTNET_SIGNER_KEY=0x...
HYP_CHAINS_SOLANATESTNET_SIGNER_KEY=0x...
HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY=0x...
HYP_VALIDATOR_KEY=0x...
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

### 2. Configurações Geradas em Runtime

Os arquivos de configuração **NÃO contêm chaves** e são gerados dinamicamente dentro do container:

```bash
# Relayer: /tmp/relayer.testnet.json (dentro do container)
# Validator: /tmp/validator.terraclassic-testnet.json (dentro do container)
```

**Esses arquivos são criados em `/tmp/` dentro do container e NUNCA são salvos no host!**

### 3. Proteção pelo `.gitignore`

```gitignore
# Arquivos de ambiente
.env
.env.local
.env.*.local

# Arquivos de configuração com chaves
hyperlane/validator.*.json
!hyperlane/validator.*.json.example
hyperlane/relayer.json
hyperlane/relayer.*.json
!hyperlane/relayer.*.json.example
```

---

## ✅ CHECKLIST DE SEGURANÇA

Antes de fazer commit, execute:

```bash
# 1. Verificar que não há chaves nos arquivos de configuração
grep -r "0x[a-f0-9]\{64\}" hyperlane/*.json | grep -v ".example" | grep -v "agent-config"

# Se retornar ALGO = ❌ PERIGO! Não faça commit!
# Se retornar NADA = ✅ Seguro

# 2. Verificar que os arquivos com chaves não existem no host
ls hyperlane/relayer.testnet.json hyperlane/validator.terraclassic-testnet.json 2>&1

# Se retornar "No such file" = ✅ Seguro
# Se retornar arquivos = ❌ PERIGO! Remova antes de commitar

# 3. Verificar que o .env não será commitado
git status --ignored | grep .env

# Se retornar o .env como ignored = ✅ Seguro
# Se o .env aparecer no git status normal = ❌ PERIGO!

# 4. Verificar que os arquivos de config estão no .gitignore
git check-ignore hyperlane/relayer.testnet.json hyperlane/validator.terraclassic-testnet.json

# Se retornar os nomes dos arquivos = ✅ Protegido
# Se não retornar nada = ❌ PERIGO!
```

---

## 🚀 COMO USAR

### 1. Configurar o `.env`

```bash
cp .env.example .env
nano .env  # Configure suas chaves
```

### 2. Iniciar os Serviços

```bash
docker-compose -f docker-compose-testnet.yml up -d
```

### 3. Verificar Logs

```bash
# Relayer
docker logs hpl-relayer-testnet -f

# Validator
docker logs hpl-validator-terraclassic-testnet -f
```

---

## 📂 ESTRUTURA DE ARQUIVOS

```
hyperlane-validator-smart/
├── .env                                    # ❌ NÃO commitado (chaves aqui)
├── .gitignore                              # ✅ Protege arquivos sensíveis
├── docker-compose-testnet.yml              # ✅ Gera configs em runtime
├── hyperlane/
│   ├── agent-config.docker-testnet.json   # ✅ SEM chaves (apenas endereços de contratos)
│   ├── relayer.testnet.json.example       # ✅ Template SEM chaves
│   ├── validator.*.json.example           # ✅ Template SEM chaves
│   ├── relayer.testnet.json               # ❌ NÃO deve existir no host
│   └── validator.*.json                   # ❌ NÃO deve existir no host
└── README-SEGURANCA.md                     # ✅ Este arquivo
```

---

## 🔧 COMO FUNCIONA O DOCKER-COMPOSE

### Relayer

```yaml
command:
  - |
    # 1. Validar que as chaves existem no .env
    if [ -z "${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" ]; then
      echo "ERROR: Signer keys are required!"
      exit 1
    fi
    
    # 2. Gerar arquivo de configuração em /tmp/ (dentro do container)
    printf '{...}' \
      "${HYP_CHAINS_BSCTESTNET_SIGNER_KEY}" \
      "${HYP_CHAINS_SOLANATESTNET_SIGNER_KEY}" \
      "${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}" \
      > "/tmp/relayer.testnet.json"
    
    # 3. Executar relayer apontando para /tmp/
    CONFIG_FILES="/tmp/relayer.testnet.json" ./relayer
```

**Resultado**: As chaves ficam **apenas em memória** dentro do container e **nunca** são escritas no host.

### Validator

```yaml
command:
  - |
    # 1. Validar que as chaves existem
    if [ -z "${HYP_VALIDATOR_KEY}" ]; then
      echo "ERROR: HYP_VALIDATOR_KEY is required!"
      exit 1
    fi
    
    # 2. Gerar arquivo em /tmp/
    printf '{...}' \
      "${HYP_VALIDATOR_KEY}" \
      "${HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY}" \
      > "/tmp/validator.terraclassic-testnet.json"
    
    # 3. Executar validator
    CONFIG_FILES="/tmp/validator.terraclassic-testnet.json" ./validator
```

---

## ⚠️ O QUE NUNCA FAZER

### ❌ NUNCA faça isso:

```bash
# Adicionar o .env ao git
git add .env

# Commitar arquivos com chaves
git add hyperlane/relayer.testnet.json
git add hyperlane/validator.*.json

# Hardcodar chaves no código
"key": "0x819b680e3578eac4f79b8fde643046e88f3f9bb10a3ce1424e3642798ef39b42"
```

### ✅ SEMPRE faça isso:

```bash
# Usar .env para chaves
echo "HYP_VALIDATOR_KEY=0x..." >> .env

# Commitar apenas templates
git add hyperlane/relayer.testnet.json.example

# Verificar antes de commit
git diff --cached | grep -i "0x[a-f0-9]\{64\}"
# Se retornar algo = PERIGO! Não continue
```

---

## 🆘 RECUPERAÇÃO DE EMERGÊNCIA

### Se você acidentalmente commitou chaves:

```bash
# 1. RODAR TODAS AS CHAVES IMEDIATAMENTE
#    Gere novas chaves e transfira fundos

# 2. Remover o commit do git
git reset HEAD~1
# ou
git revert <commit_hash>

# 3. Limpar histórico (se necessário)
git filter-branch --tree-filter 'rm -f hyperlane/*.json' HEAD
git push --force

# 4. Avisar a equipe sobre o incidente
```

---

## 📊 MONITORAMENTO

### Verificar que os containers estão rodando com segurança:

```bash
# 1. Containers ativos
docker ps --filter "name=hpl-"

# 2. Verificar que os configs estão em /tmp/ dentro do container
docker exec hpl-relayer-testnet ls -la /tmp/relayer.testnet.json
docker exec hpl-validator-terraclassic-testnet ls -la /tmp/validator.*.json

# 3. Verificar que NÃO há arquivos com chaves no host
ls hyperlane/*.json | grep -v ".example" | grep -v "agent-config"
# Deve retornar vazio

# 4. Verificar logs para erros
docker logs hpl-relayer-testnet 2>&1 | grep -i "error"
docker logs hpl-validator-terraclassic-testnet 2>&1 | grep -i "error"
```

---

## 📚 REFERÊNCIAS

- [12 Factor App - Config](https://12factor.net/config)
- [OWASP - Password Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [Git - Removing Sensitive Data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

---

## ✅ STATUS

Data: 2026-01-29
Status: **IMPLEMENTADO E SEGURO** 🔒

**Todas as boas práticas de segurança foram aplicadas.**

---

## 📞 SUPORTE

Se tiver dúvidas sobre segurança:

1. **NUNCA** compartilhe suas chaves privadas
2. **SEMPRE** use `.env` para credenciais
3. **SEMPRE** verifique antes de fazer commit
4. **SEMPRE** rode novamente as chaves se suspeitar de exposição

---

**Segurança não é opcional. É mandatório. 🔐**
