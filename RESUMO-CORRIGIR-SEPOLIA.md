# 🔧 CORRIGIR ISM DO WARP ROUTE SEPOLIA

## 📋 O QUE PRECISA SER FEITO

O Warp Route do Sepolia está usando **MESSAGE_ID_MULTISIG** (tipo 5) ao invés de **DomainRoutingISM** (tipo 1), como no Solana.

### Situação Atual:
- ❌ ISM = MESSAGE_ID_MULTISIG (tipo 5)
- ✅ Validador = 0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0 (correto)

### Situação Desejada (como no Solana):
- ✅ ISM = DomainRoutingISM (tipo 1)
- ✅ DomainRoutingISM.module(1325) = ISM do Terra Classic

---

## 📝 INFORMAÇÕES NECESSÁRIAS

Antes de executar o script, você precisa ter:

1. **ISM do Terra Classic**
   - É o endereço do contrato ISM no Terra Classic
   - Contém os validadores: 0x8804770d6a346210c0Fd011258FDf3Ab0a5bb0d0
   - Pode ser obtido via Terra Finder ou API

2. **Private Key do Owner do Warp Route**
   - Owner atual: 0x133fD7F7094DBd17b576907d052a5aCBd48dB526
   - Precisa ter ETH no Sepolia para pagar gas

---

## 🚀 COMO EXECUTAR

### Opção 1: Script Interativo (Recomendado)

```bash
./corrigir-ism-sepolia.sh
```

O script irá:
1. Tentar obter o ISM do Terra Classic automaticamente
2. Se não conseguir, pedirá para você informar
3. Pedirá sua private key
4. Criar DomainRoutingISM se necessário
5. Configurar para Terra Classic
6. Atualizar o Warp Route

### Opção 2: Com Variáveis de Ambiente

```bash
# Configurar variáveis
export TERRA_ISM="<endereco_ism_terra_classic>"
export PRIVATE_KEY="<sua_private_key>"

# Executar
./corrigir-ism-sepolia.sh
```

---

## 🔍 COMO OBTER O ISM DO TERRA CLASSIC

### Método 1: Via Terra Finder
1. Acesse: https://finder.terraclassic.community/testnet
2. Procure pelo contrato Mailbox: `0x8564e4e5ebc744b0a6185d1c293d598189227b3efded874e8d0bea467c8750dd`
3. Execute a query: `{"interchain_security_module":{}}`
4. O resultado é o endereço do ISM

### Método 2: Via Script
```bash
./obter-ism-terraclassic.sh
```

### Método 3: Verificar nos Logs do Relayer
O ISM do Terra Classic pode aparecer nos logs do relayer quando ele tenta processar mensagens.

---

## ⚠️ IMPORTANTE

1. **Verifique o Owner**: Certifique-se de que a private key é do owner do Warp Route
2. **Tenha ETH**: Você precisa de ETH no Sepolia para pagar as transações
3. **Verifique Transações**: Sempre verifique as transações no Etherscan antes de confirmar
4. **Backup**: Anote o ISM atual antes de mudar (caso precise reverter)

---

## ✅ RESULTADO ESPERADO

Após a correção:

```
Warp Route Sepolia:
  ISM = DomainRoutingISM (tipo 1) ✅
  DomainRoutingISM.module(1325) = ISM do Terra Classic ✅
  
Status: ✅ Configurado corretamente (como no Solana)
```

---

## 📊 COMPARAÇÃO

| Aspecto | Antes | Depois |
|---------|-------|--------|
| ISM | MESSAGE_ID_MULTISIG | DomainRoutingISM |
| Tipo | 5 | 1 |
| Roteamento | Não | Sim (por domain) |
| Terra Classic | Não configurado | Configurado |

---

## 🆘 TROUBLESHOOTING

### Erro: "Owner não corresponde"
- Verifique se a private key é do owner correto
- Owner atual: 0x133fD7F7094DBd17b576907d052a5aCBd48dB526

### Erro: "Insufficient funds"
- Você precisa de ETH no Sepolia
- Verifique o saldo: https://sepolia.etherscan.io/address/SEU_ENDERECO

### Erro: "ISM do Terra Classic não encontrado"
- Verifique o endereço do ISM
- Tente obter manualmente via Terra Finder

