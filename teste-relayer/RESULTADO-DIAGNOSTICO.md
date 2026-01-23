# 🔍 Resultado do Diagnóstico do Relayer

## ⚠️ Problema Identificado

O relayer não está iniciando porque **as variáveis de ambiente não estão configuradas**.

### Erro Encontrado

```
Error: ParsingError
config_path: `chains.bsctestnet.signer.key`
env_path: `HYP_CHAINS_BSCTESTNET_SIGNER_KEY`
error: Expected a valid private key in hex, base58 or bech32

config_path: `chains.terraclassictestnet.signer.key`
env_path: `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY`
error: Expected a valid private key in hex, base58 or bech32
```

### Status do Container

- ✅ Container criado com sucesso
- ❌ Container está em loop de reinicialização (Restarting)
- ❌ Relayer não consegue iniciar sem as chaves privadas

---

## 🔧 Solução

### 1. Configurar Variáveis de Ambiente

Antes de iniciar o relayer, configure as variáveis de ambiente:

```bash
export AWS_ACCESS_KEY_ID="sua_access_key_aqui"
export AWS_SECRET_ACCESS_KEY="sua_secret_key_aqui"
export AWS_REGION="us-east-1"
export HYP_CHAINS_BSCTESTNET_SIGNER_KEY="0x..."
export HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY="0x..."
export HYP_CHAINS_SOLANATESTNET_SIGNER_KEY="0x..."  # Opcional
```

### 2. Criar Arquivo .env (Alternativa)

Crie um arquivo `.env` na raiz do projeto com:

```bash
AWS_ACCESS_KEY_ID=sua_access_key_aqui
AWS_SECRET_ACCESS_KEY=sua_secret_key_aqui
AWS_REGION=us-east-1
HYP_CHAINS_BSCTESTNET_SIGNER_KEY=0x...
HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY=0x...
HYP_CHAINS_SOLANATESTNET_SIGNER_KEY=0x...
```

E modifique o `docker-compose-relayer-only.yml` para usar:

```yaml
env_file:
  - ../.env
```

### 3. Reiniciar o Relayer

Após configurar as variáveis:

```bash
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml down
docker compose -f docker-compose-relayer-only.yml up -d
```

---

## 📋 Checklist de Verificação

Após configurar as variáveis e reiniciar, verifique:

- [ ] Container está rodando (não em Restarting)
- [ ] Logs não mostram erros de parsing
- [ ] API do relayer responde em `http://localhost:19010/health`
- [ ] Validators são descobertos
- [ ] Checkpoints são lidos do S3
- [ ] Status de sincronização mostra Terra Classic

---

## 🚀 Próximos Passos

1. **Configurar variáveis de ambiente** (veja acima)
2. **Reiniciar o relayer**
3. **Executar diagnóstico novamente:**
   ```bash
   cd teste-relayer
   ./diagnostico.sh
   ```
4. **Verificar logs:**
   ```bash
   docker logs -f hpl-relayer-testnet-local
   ```

---

## 📊 Comandos Úteis

### Ver Status do Container

```bash
docker ps -a | grep relayer
```

### Ver Logs

```bash
docker logs hpl-relayer-testnet-local
docker logs -f hpl-relayer-testnet-local  # Seguir logs
```

### Parar o Relayer

```bash
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml down
```

### Limpar e Reiniciar

```bash
cd teste-relayer
docker compose -f docker-compose-relayer-only.yml down -v
docker compose -f docker-compose-relayer-only.yml up -d
```

---

## ⚠️ Nota Importante

**As chaves privadas são sensíveis!** 

- Nunca commite arquivos `.env` no git
- Use variáveis de ambiente ou arquivos `.env` locais
- Mantenha as chaves privadas seguras

---

**Data do diagnóstico**: 2026-01-23
**Status**: ⚠️ Aguardando configuração de variáveis de ambiente
