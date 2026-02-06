# 🔍 Problema: gRPC do Terra Classic não encontra conta

## ✅ O que está funcionando:

1. **Checkpoint encontrado no S3** ✅
   - Message ID: `0x93cb428f4bfd3fa2ccd552412b4e963f1dd7a9ac1bc702ce98c3c68dda9af860`
   - Checkpoint index: 864656

2. **Metadata construído com sucesso** ✅
   - Relayer conseguiu ler o checkpoint do S3
   - Conseguiu verificar a assinatura
   - Construiu o metadata necessário

3. **Conta existe e tem saldo** ✅
   - Endereço: `terra12awgqgwm2evj05ndtgs0xa35uunlpc76d85pze`
   - Confirmado via REST API (`https://lcd.luncblaze.com`)
   - Confirmado pelo usuário que tem saldo

## ❌ Problema identificado:

**Erro ao consultar conta via gRPC:**
```
ABCI query failed: path=/cosmos.auth.v1beta1.Query/Account, 
code=22, log=rpc error: code = NotFound desc = 
account terra12awgqgwm2evj05ndtgs0xa35uunlpc76d85pze not found: key not found
```

### Causa:

O relayer está usando **gRPC** (`grpc.terra-classic.hexxagon.dev`) para consultar a conta, mas o gRPC está retornando "account not found", mesmo que:
- A conta exista (confirmado via REST)
- A conta tenha saldo (confirmado pelo usuário)

### Possíveis causas:

1. **gRPC consultando bloco muito antigo**
   - O gRPC pode estar consultando em um bloco anterior à criação da conta
   - Logs anteriores mostraram erros sobre "failed to load state at height 27192586"

2. **gRPC não sincronizado**
   - O gRPC pode não estar sincronizado com a rede
   - Pode estar atrasado em relação ao estado atual

3. **Problema de compatibilidade**
   - Pode haver incompatibilidade entre o gRPC e a versão da rede
   - O gRPC pode não estar suportando consultas de contas corretamente

## 🔧 Tentativas de solução:

1. ✅ Adicionado gRPC adicional como fallback (`terra-classic-grpc.publicnode.com:443`)
2. ❌ Problema persiste mesmo com múltiplos gRPCs

## 💡 Possíveis soluções:

### 1. Verificar se há outros gRPCs disponíveis
- Adicionar mais gRPCs à lista de fallback
- Verificar se há gRPCs alternativos que funcionem corretamente

### 2. Verificar se o problema é específico do gRPC
- O relayer pode precisar usar REST em vez de gRPC para consultas de conta
- Verificar se há configuração para forçar uso de REST

### 3. Verificar sincronização do gRPC
- O gRPC pode estar consultando em um bloco muito antigo
- Verificar se há forma de especificar o bloco atual

### 4. Contatar suporte do Hyperlane
- Este pode ser um bug conhecido do relayer com Terra Classic
- Pode haver uma solução ou workaround documentado

## 📊 Status Atual:

- ✅ Checkpoint encontrado e lido do S3
- ✅ Metadata construído com sucesso
- ✅ Quorum atingido (threshold = 1, 1 assinatura encontrada)
- ✅ Conta existe e tem saldo (confirmado)
- ❌ **Falha ao consultar conta via gRPC** - "account not found"
- ❌ **Não consegue estimar custos** - bloqueia envio da transação

## 🔍 Próximos Passos:

1. Verificar se há outros gRPCs disponíveis para Terra Classic testnet
2. Verificar se há forma de forçar uso de REST para consultas de conta
3. Verificar logs do gRPC para entender por que não encontra a conta
4. Contatar suporte do Hyperlane ou comunidade para verificar se é um bug conhecido
