# 🔧 Configuração do Warp Route com Threshold 1

## ✅ Validator Ativo (Gerando Checkpoints em 2026)

**Endereço do Validator:**
```
0x01227B3361d200722c3656f899b48dE187A32494
```

**Informações do Validator:**
- **Bucket S3**: `hyperlane-validator-signatures-mitocateth`
- **Região**: `ap-northeast-2`
- **S3 Path**: `s3://hyperlane-validator-signatures-mitocateth/ap-northeast-2`
- **Último checkpoint**: 2026-01-29T07:32:25.000Z (há 6 dias)
- **Total de checkpoints**: 624
- **Status**: ✅ ATIVO (gerando checkpoints recentes)

**URL do último checkpoint:**
```
https://hyperlane-validator-signatures-mitocateth.s3.amazonaws.com/checkpoint_0_with_id.json
```

## 🔧 Como Configurar Warp Route com Threshold 1

### Opção 1: Criar Novo ISM Multisig com Threshold 1

Para aceitar apenas 1 validação (threshold 1 de 1), você precisa criar um novo ISM Multisig:

**Configuração:**
```json
{
  "validators": [
    "0x01227B3361d200722c3656f899b48dE187A32494"
  ],
  "threshold": 1
}
```

**Passos:**
1. Use o contrato `MessageIdMultisigIsmFactory` no Sepolia
2. Crie um novo ISM com:
   - Validators: `["0x01227B3361d200722c3656f899b48dE187A32494"]`
   - Threshold: `1`
3. Configure o Warp Route para usar este novo ISM

### Opção 2: Atualizar ISM Existente (se possível)

Se você tem controle sobre o ISM atual, pode atualizar para:
- Validators: `["0x01227B3361d200722c3656f899b48dE187A32494"]`
- Threshold: `1`

## ⚠️ ATENÇÕES IMPORTANTES

### Segurança
- **Com threshold 1, qualquer mensagem assinada por este validator será aceita**
- Isso reduz significativamente a segurança
- **Recomendado APENAS para testnet**
- Em produção, sempre use threshold 2 de 3 ou maior

### Dependência
- Você depende de apenas 1 validator
- Se este validator parar de funcionar, suas mensagens não serão processadas
- Não há redundância

### Alternativas
- Se possível, aguarde mais validators ficarem ativos
- Considere usar validators oficiais do Hyperlane
- Verifique se há validators não anunciados que você pode usar

## 📋 Comandos Úteis

### Verificar se o validator está gerando checkpoints:
```bash
curl https://hyperlane-validator-signatures-mitocateth.s3.amazonaws.com/checkpoint_0_with_id.json | jq .
```

### Verificar no Etherscan:
```
https://sepolia.etherscan.io/address/0x01227B3361d200722c3656f899b48dE187A32494
```

### Verificar no validatorAnnounce:
```bash
python3 scripts/query_validator_announce.py | jq '.validators[] | select(.address == "0x01227B3361d200722c3656f899b48dE187A32494")'
```

## 🔄 Próximos Passos

1. **Criar/Atualizar ISM** com threshold 1 usando o validator ativo
2. **Configurar Warp Route** para usar o novo ISM
3. **Testar** enviando uma mensagem
4. **Monitorar** se as mensagens são processadas corretamente

## 📝 Notas

- Este validator está ativo desde janeiro de 2026
- É o único validator ativo de 81 com storage locations
- Os outros validators têm checkpoints muito antigos (2024 ou anteriores)
- Isso explica por que seu relayer não conseguia processar mensagens ("Unable to reach quorum")
