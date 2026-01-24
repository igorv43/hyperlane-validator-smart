# 🔧 Como Corrigir os Erros

## ❌ Erro 1: Variáveis de Ambiente Não Carregadas

### Problema:
```
WARN[0000] The "HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY" variable is not set. Defaulting to a blank string.
```

### ✅ Solução:

O problema é que o `docker compose` precisa ser executado do diretório correto para encontrar o arquivo `.env`.

**Opção 1: Executar do diretório correto (Recomendado)**

```bash
cd /home/lunc/hyperlane-validator-smart/teste-relayer
docker compose -f docker-compose-relayer-only.yml up -d relayer
```

**Opção 2: Usar caminho absoluto no docker-compose.yml**

O arquivo já está configurado com `../.env`, que funciona quando executado do diretório `teste-relayer/`.

**Opção 3: Exportar variáveis manualmente**

```bash
# Carregar variáveis do .env
cd /home/lunc/hyperlane-validator-smart
export $(grep -v '^#' .env | xargs)

# Depois executar docker compose
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml up -d relayer
```

---

## ❌ Erro 2: Docker Daemon Não Está Rodando

### Problema:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

### ✅ Solução:

**1. Iniciar Docker Desktop no Windows:**
   - Abra o Docker Desktop
   - Aguarde até que o Docker esteja completamente iniciado
   - Verifique se aparece "Docker Desktop is running" na barra de tarefas

**2. Verificar WSL 2 Integration:**
   - Abra Docker Desktop
   - Vá em Settings → Resources → WSL Integration
   - Certifique-se de que sua distribuição WSL está marcada como "Enabled"
   - Clique em "Apply & Restart"

**3. Verificar se Docker está rodando:**
   ```bash
   docker ps
   ```
   
   Se funcionar, o Docker está rodando. Se der erro, o Docker ainda não está pronto.

**4. Se ainda não funcionar, reinicie o WSL:**
   ```bash
   # No PowerShell do Windows (como administrador)
   wsl --shutdown
   ```
   
   Depois, abra o WSL novamente e tente:
   ```bash
   docker ps
   ```

---

## ✅ Verificação Completa

Execute estes comandos para verificar se tudo está correto:

```bash
# 1. Verificar se Docker está rodando
docker ps

# 2. Verificar se .env existe e tem as variáveis
cd /home/lunc/hyperlane-validator-smart
grep HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY .env

# 3. Executar relayer
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml up -d relayer

# 4. Verificar se container está rodando
docker compose -f docker-compose-relayer-only.yml ps

# 5. Ver logs
docker compose -f docker-compose-relayer-only.yml logs -f relayer
```

---

## 📋 Checklist

- [ ] Docker Desktop está rodando
- [ ] WSL 2 Integration está ativado
- [ ] Arquivo `.env` existe em `/home/lunc/hyperlane-validator-smart/.env`
- [ ] Variáveis `HYP_CHAINS_*_SIGNER_KEY` estão no `.env`
- [ ] Executando `docker compose` do diretório `teste-relayer/`

---

## 🔗 Referências

- [Docker Desktop WSL 2 Integration](https://docs.docker.com/desktop/wsl/)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
