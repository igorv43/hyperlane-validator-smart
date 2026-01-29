# 🚀 CONFIGURAÇÃO INICIAL DO HYPERLANE RELAYER

**Guia rápido para novos agentes/desenvolvedores**

---

## 📋 PRÉ-REQUISITOS

### Ferramentas Necessárias:

```bash
# Docker e Docker Compose
sudo apt update
sudo apt install -y docker.io docker-compose

# jq (processador JSON)
sudo apt install -y jq

# Foundry (opcional, para comandos cast)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Verificar Instalação:

```bash
docker --version          # Docker version 20.10+
docker-compose --version  # docker-compose version 1.29+
jq --version             # jq-1.6+
cast --version           # foundry 0.2.0+ (opcional)
```

---

## 🎯 PASSO A PASSO

### 1️⃣ Clonar o Repositório

```bash
cd ~
git clone <seu-repositorio>
cd hyperlane-validator-smart
```

### 2️⃣ Atualizar Blocos Iniciais (IMPORTANTE!)

**Por que fazer isso?**
- ✅ Sincronização 100x mais rápida
- ✅ Evita rate limits de RPCs públicos
- ✅ Relayer fica operacional em minutos

**Como fazer:**

```bash
# Tornar script executável (já deve estar, mas por precaução)
chmod +x atualizar-blocos-chains.sh

# Executar o script automatizado
./atualizar-blocos-chains.sh
```

O script vai:
1. Consultar blocos atuais de todas as chains
2. Criar backup do config
3. Atualizar automaticamente
4. Oferecer reiniciar o relayer

**Responda "s" quando perguntar se deseja reiniciar.**

### 3️⃣ Configurar Chaves Privadas

**⚠️ IMPORTANTE**: Nunca commite chaves privadas!

Editar o arquivo `.env`:

```bash
nano .env
```

Configurar as seguintes variáveis:

```bash
# Terra Classic Validator
HYP_VALIDATOR_TERRACLASSIC_TESTNET_KEY=sua_chave_privada_aqui

# Relayer - Chains
HYP_CHAINS_BSCTESTNET_SIGNER_KEY=sua_chave_bsc_aqui
HYP_CHAINS_SOLANATESTNET_SIGNER_KEY=sua_chave_solana_aqui
HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY=sua_chave_terra_aqui
HYP_CHAINS_SEPOLIA_SIGNER_KEY=sua_chave_sepolia_aqui

# AWS S3 (para checkpoints do validator)
HYP_VALIDATOR_VALIDATOR_KEY=mesma_chave_do_validator_terra
AWS_ACCESS_KEY_ID=sua_aws_access_key
AWS_SECRET_ACCESS_KEY=sua_aws_secret_key
```

**Como gerar chaves privadas:**

```bash
# Para chains EVM (BSC, Sepolia, Terra Classic)
cast wallet new

# Para Solana
solana-keygen new --outfile keypair.json
cat keypair.json
```

### 4️⃣ Adicionar Fundos nas Carteiras (Testnet)

O relayer precisa de gas para enviar transações:

#### Terra Classic Testnet (LUNC):
- Faucet: https://faucet.terra.money/
- Valor recomendado: 10-20 LUNC

#### BSC Testnet (BNB):
- Faucet: https://testnet.bnbchain.org/faucet-smart
- Valor recomendado: 0.5-1 BNB

#### Solana Testnet (SOL):
```bash
solana airdrop 2 <SUA_CARTEIRA> --url testnet
```

#### Sepolia (ETH):
- Faucets múltiplos (ver `SEPOLIA-FAUCETS-2026.md`)
- **Recomendado (PoW)**: https://sepolia-faucet.pk910.de/
- Valor recomendado: 0.5-1 ETH

### 5️⃣ Iniciar os Containers

```bash
# Iniciar relayer e validator
docker-compose -f docker-compose-testnet.yml up -d

# Ver logs em tempo real
docker logs -f hpl-relayer-testnet
```

**Logs esperados (sucesso):**

```
✅ estimated_time_to_sync: "synced"
✅ pool_size: 0 (sem mensagens pendentes)
✅ Sem erros de "rate limit"
```

### 6️⃣ Verificar Status

```bash
# Ver containers rodando
docker ps --filter "name=hpl-"

# Verificar sincronização de todas as chains
docker logs hpl-relayer-testnet 2>&1 | grep "synced"

# Verificar rate limits (deve ser 0 ou próximo)
docker logs hpl-relayer-testnet --since 5m 2>&1 | grep -i "rate limit" | wc -l

# Ver configuração das chains
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.chains | keys[]'
```

---

## ✅ CHECKLIST DE CONFIGURAÇÃO

- [ ] Repositório clonado
- [ ] Script `atualizar-blocos-chains.sh` executado
- [ ] Blocos atualizados para valores recentes
- [ ] Arquivo `.env` configurado com todas as chaves
- [ ] Fundos adicionados em todas as carteiras testnet
- [ ] Containers iniciados: `docker-compose -f docker-compose-testnet.yml up -d`
- [ ] Relayer está "synced" em todas as chains
- [ ] Validator Terra Classic está rodando
- [ ] Rate limits baixos (0-5 por minuto)
- [ ] Teste de envio de mensagem realizado

---

## 🎯 ROTAS DISPONÍVEIS

Após configuração, estas rotas estarão ativas:

1. **Terra Classic → Solana** ✅
2. **Solana → Terra Classic** ✅
3. **Terra Classic → BSC** ✅
4. **BSC → Terra Classic** ✅
5. **Terra Classic → Sepolia** ✅
6. **Sepolia → Terra Classic** ✅

---

## 📊 ARQUITETURA

```
┌─────────────────────────────────────────────────────────────┐
│                    HYPERLANE RELAYER                        │
│                                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐      │
│  │  Terra  │  │   BSC   │  │ Solana  │  │ Sepolia │      │
│  │ Classic │  │ Testnet │  │ Testnet │  │         │      │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘      │
│       │            │            │            │             │
│       └────────────┴────────────┴────────────┘             │
│                        ↓                                    │
│              ┌──────────────────┐                          │
│              │  RELAYER ENGINE  │                          │
│              │  - Detecta msgs  │                          │
│              │  - Busca proofs  │                          │
│              │  - Envia txs     │                          │
│              └──────────────────┘                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                TERRA CLASSIC VALIDATOR                      │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │  1. Monitora mensagens na Terra Classic         │      │
│  │  2. Assina checkpoints (provas criptográficas)  │      │
│  │  3. Envia checkpoints para AWS S3                │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
│  Relayer lê estes checkpoints do S3 para validar msgs      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 COMANDOS ÚTEIS

### Gerenciamento de Containers:

```bash
# Iniciar tudo
docker-compose -f docker-compose-testnet.yml up -d

# Parar tudo
docker-compose -f docker-compose-testnet.yml down

# Reiniciar apenas o relayer
docker-compose -f docker-compose-testnet.yml restart relayer

# Reiniciar apenas o validator
docker-compose -f docker-compose-testnet.yml restart validator-terraclassic

# Ver logs
docker logs -f hpl-relayer-testnet
docker logs -f hpl-validator-terraclassic-testnet
```

### Atualização de Blocos:

```bash
# Atualizar blocos (recomendado semanalmente ou após paradas longas)
./atualizar-blocos-chains.sh

# Ver blocos atuais no config
cat hyperlane/agent-config.docker-testnet.json | jq '.chains | to_entries[] | {chain: .key, from: .value.index.from}'
```

### Diagnóstico:

```bash
# Ver status de sincronização
docker logs hpl-relayer-testnet 2>&1 | grep "estimated_time_to_sync"

# Ver chains configuradas
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.chains | keys[]'

# Ver rotas (whitelist)
docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.whitelist'

# Verificar saldo das carteiras
cast balance <ENDERECO> --rpc-url https://bsc-testnet.drpc.org
cast balance <ENDERECO> --rpc-url https://1rpc.io/sepolia
```

### Reset Completo (se algo der errado):

```bash
# 1. Parar containers
docker-compose -f docker-compose-testnet.yml down

# 2. Limpar database
sudo rm -rf relayer-testnet/db/*
sudo rm -rf validator-terraclassic-testnet/db/*

# 3. Atualizar blocos
./atualizar-blocos-chains.sh

# 4. Reiniciar
docker-compose -f docker-compose-testnet.yml up -d
```

---

## 🐛 TROUBLESHOOTING

### Problema: "Rate limit exceeded"

**Solução:**
```bash
# 1. Atualizar blocos para valores recentes
./atualizar-blocos-chains.sh

# 2. Verificar se Sepolia tem fundos (causa comum)
cast balance <SUA_CARTEIRA> --rpc-url https://1rpc.io/sepolia

# 3. Se persistir, verificar RPCs no config
cat hyperlane/agent-config.docker-testnet.json | jq '.chains.sepolia.rpcUrls'
```

### Problema: "Unable to reach quorum"

**Causa**: Validator não está rodando ou não está gerando checkpoints.

**Solução:**
```bash
# 1. Verificar se validator está rodando
docker ps --filter "name=validator"

# 2. Ver logs do validator
docker logs hpl-validator-terraclassic-testnet

# 3. Reiniciar validator se necessário
docker-compose -f docker-compose-testnet.yml restart validator-terraclassic

# 4. Verificar se está salvando no S3
docker logs hpl-validator-terraclassic-testnet 2>&1 | grep "Signed checkpoint"
```

### Problema: Container morre com "Exit 137"

**Causa**: Out of Memory (OOM) - falta de memória.

**Solução:**
```bash
# 1. Verificar recursos disponíveis
free -h
docker stats

# 2. Limpar containers parados e imagens antigas
docker system prune -a

# 3. Se em produção, aumentar memória do servidor
```

### Problema: Mensagem não chega ao destino

**Diagnóstico:**
```bash
# 1. Ver se mensagem foi detectada
docker logs hpl-relayer-testnet 2>&1 | grep "<MESSAGE_ID>"

# 2. Ver pool_size (mensagens pendentes)
docker logs hpl-relayer-testnet 2>&1 | grep "pool_size"

# 3. Verificar se há erros
docker logs hpl-relayer-testnet 2>&1 | grep -E "(ERROR|WARN)"
```

**Soluções comuns:**
- Verificar se validator está ativo
- Verificar se relayer tem fundos para gas
- Verificar se ISM está configurado corretamente

---

## 📚 DOCUMENTAÇÃO ADICIONAL

### Guias Específicos:

- **`GUIA-CONFIGURACAO-BLOCOS.md`**: Guia completo sobre configuração de blocos
- **`GUIDE-AWS-S3-AND-KEYS.md`**: Como configurar AWS S3 para validator
- **`README-SEGURANCA.md`**: Boas práticas de segurança
- **`SEPOLIA-FAUCETS-2026.md`**: Lista de faucets para Sepolia
- **`ARCHITECTURE-S3.md`**: Arquitetura detalhada do sistema

### Scripts Úteis:

- **`atualizar-blocos-chains.sh`**: Atualiza blocos automaticamente ⭐
- **`consultar-warp-bsc.sh`**: Consulta config de warp BSC
- **`verificar-validadores-publicos.sh`**: Verifica validators públicos

---

## 🎓 PRÓXIMOS PASSOS

Após configurar tudo:

1. **Testar cada rota**:
   - Enviar mensagem Terra Classic → Solana
   - Enviar mensagem Solana → Terra Classic
   - Enviar mensagem Terra Classic → BSC
   - Enviar mensagem BSC → Terra Classic
   - Enviar mensagem Terra Classic → Sepolia
   - Enviar mensagem Sepolia → Terra Classic

2. **Monitorar por 24h**:
   - Verificar logs periodicamente
   - Confirmar rate limits estão baixos
   - Verificar saldo das carteiras

3. **Configurar alertas** (opcional):
   - Monitoramento de uptime
   - Alertas de saldo baixo
   - Logs de erros

4. **Documentar sua configuração**:
   - Anotar endereços das carteiras
   - Anotar blocos iniciais
   - Anotar datas de deploy

---

## 🆘 SUPORTE

### Em caso de dúvidas:

1. Consultar documentação oficial: https://docs.hyperlane.xyz/
2. Ver logs detalhados: `docker logs hpl-relayer-testnet > logs.txt`
3. Verificar issues no GitHub do Hyperlane
4. Consultar guias específicos neste repositório

### Informações úteis para debug:

```bash
# Coletar informações do sistema
cat > system-info.txt << EOF
=== SYSTEM INFO ===
Date: $(date)
Docker Version: $(docker --version)
Compose Version: $(docker-compose --version)

=== CONTAINERS ===
$(docker ps -a --filter "name=hpl-")

=== CONFIG BLOCKS ===
$(cat hyperlane/agent-config.docker-testnet.json | jq '.chains | to_entries[] | {chain: .key, from: .value.index.from}')

=== RECENT LOGS ===
$(docker logs hpl-relayer-testnet --tail 50)
EOF

cat system-info.txt
```

---

## ✅ STATUS ESPERADO

### Após configuração bem-sucedida:

```bash
$ docker ps --filter "name=hpl-"
CONTAINER ID   IMAGE              STATUS         NAMES
abc123def456   hyperlane-agent    Up 5 minutes   hpl-relayer-testnet
def456ghi789   hyperlane-agent    Up 5 minutes   hpl-validator-terraclassic-testnet

$ docker logs hpl-relayer-testnet 2>&1 | grep "synced" | tail -4
estimated_time_to_sync: "synced" (terraclassictestnet)
estimated_time_to_sync: "synced" (bsctestnet)
estimated_time_to_sync: "synced" (solanatestnet)
estimated_time_to_sync: "synced" (sepolia)

$ docker logs hpl-relayer-testnet --since 5m 2>&1 | grep -i "rate limit" | wc -l
0

$ docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.chains | keys[]'
"bsctestnet"
"sepolia"
"solanatestnet"
"terraclassictestnet"
```

**🎉 Se você vê isso, está tudo funcionando perfeitamente!**

---

**Criado**: 2026-01-29  
**Versão**: 1.0  
**Hyperlane Version**: Latest (Testnet)  
**Testado em**: Ubuntu 20.04+

---

**⭐ Dica Final**: Execute `./atualizar-blocos-chains.sh` toda vez que o relayer ficar offline por mais de 1 dia. Isso garantirá sincronização rápida ao religá-lo.
