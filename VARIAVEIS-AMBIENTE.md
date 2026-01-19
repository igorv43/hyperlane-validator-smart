# Variáveis de Ambiente - Configuração no Easypanel

Este documento descreve todas as variáveis de ambiente que devem ser configuradas no **Easypanel** em **Variáveis de Ambiente (Environment Variables)**.

## ⚠️ Importante

- **NUNCA** commite arquivos `.env` ou arquivos de configuração com chaves privadas no git
- Configure todas as variáveis de ambiente diretamente no Easypanel
- Mantenha suas chaves privadas seguras e nunca as compartilhe

---

## 🔐 Variáveis Obrigatórias

### AWS Credentials

Credenciais AWS para acesso ao S3 bucket onde os checkpoints do validator são armazenados.

```bash
AWS_ACCESS_KEY_ID=sua_access_key_aqui
AWS_SECRET_ACCESS_KEY=sua_secret_key_aqui
AWS_REGION=us-east-1
```

### S3 Bucket Configuration (Obrigatório para Validator)

Configuração do bucket S3 onde os checkpoints serão armazenados.

```bash
HYP_CHECKPOINT_SYNCER_BUCKET=hyperlane-validator-signatures-seu-nome-aqui
HYP_CHECKPOINT_SYNCER_REGION=us-east-1
```

- **HYP_CHECKPOINT_SYNCER_BUCKET**: Nome do bucket S3 (deve ser único globalmente na AWS)
  - **Obrigatório**: Sim (para validator)
  - **Exemplo**: `hyperlane-validator-signatures-igorverasvalidador-terraclassic`
  
- **HYP_CHECKPOINT_SYNCER_REGION**: Região do bucket S3
  - **Obrigatório**: Sim (para validator)
  - **Padrão**: Usa `AWS_REGION` se não especificado
  - **Exemplo**: `us-east-1`

---

## 🔑 Relayer - Chaves Privadas

Chaves privadas para o relayer em formato hex. Estas variáveis sobrescrevem os placeholders `0xYOUR_PRIVATE_KEY_HERE` nos arquivos JSON.

### BSC Testnet
```bash
HYP_CHAINS_BSCTESTNET_SIGNER_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```
- **Formato**: hexKey (64 caracteres hex após `0x`)
- **Obrigatório**: Sim
- **Exemplo**: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

### Solana Testnet
```bash
HYP_CHAINS_SOLANATESTNET_SIGNER_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```
- **Formato**: hexKey (64 caracteres hex após `0x`)
- **Obrigatório**: Sim
- **Exemplo**: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

### Terra Classic Testnet
```bash
HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```
- **Formato**: cosmosKey (64 caracteres hex após `0x`)
- **Obrigatório**: Sim
- **Exemplo**: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

---

## ✅ Validator - Chaves Privadas

Chaves privadas para o validator em formato hex. Estas variáveis sobrescrevem os placeholders `0xYOUR_PRIVATE_KEY_HERE` nos arquivos JSON.

### Validator Key
```bash
HYP_VALIDATOR_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```
- **Formato**: hexKey (64 caracteres hex após `0x`)
- **Obrigatório**: Sim
- **Descrição**: Chave privada do validator
- **Exemplo**: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

### Terra Classic Testnet (Validator Chain)
```bash
HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```
- **Formato**: cosmosKey (64 caracteres hex após `0x`)
- **Obrigatório**: Sim
- **Nota**: Pode ser a mesma chave do `HYP_VALIDATOR_KEY` ou diferente
- **Exemplo**: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

---

## 📝 Formato das Chaves Privadas

Todas as chaves privadas devem seguir o seguinte formato:

- **Prefixo obrigatório**: `0x`
- **Tamanho**: Exatamente **64 caracteres hexadecimais** após o `0x`
- **Total**: 66 caracteres (`0x` + 64 hex chars)

**Exemplo válido:**
```
0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

**Exemplos inválidos:**
```
❌ 1234567890abcdef... (sem prefixo 0x)
❌ 0x1234... (menos de 64 caracteres hex)
❌ 0xYOUR_PRIVATE_KEY_HERE (placeholder não substituído)
```

---

## 🔧 Como Configurar no Easypanel

1. Acesse o seu projeto no Easypanel
2. Vá em **Variáveis de Ambiente** (Environment Variables)
3. Adicione cada variável acima com seus valores reais
4. Certifique-se de que todas as variáveis obrigatórias estão configuradas
5. Reinicie os serviços após adicionar as variáveis

---

## 🔑 Como Gerar Chaves Privadas

### BSC Testnet
```bash
# Usando MetaMask ou outras ferramentas EVM
# A chave privada exportada do MetaMask já está no formato correto (0x...)
```

### Solana Testnet
```bash
# Gerar chave Solana
solana-keygen new -o solana-keypair.json

# Converter para formato hex (ver get-solana-hexkey.py no projeto)
python3 get-solana-hexkey.py
```

### Terra Classic Testnet
```bash
# Usando terrad
terrad keys add minha-chave-testnet

# Exportar chave privada
terrad keys export minha-chave-testnet --unarmored-hex
```

---

## ✅ Checklist de Configuração

Antes de iniciar os serviços, certifique-se de ter configurado:

### AWS e S3 (Obrigatório)
- [ ] `AWS_ACCESS_KEY_ID`
- [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] `AWS_REGION`
- [ ] `HYP_CHECKPOINT_SYNCER_BUCKET` (apenas para validator)
- [ ] `HYP_CHECKPOINT_SYNCER_REGION` (apenas para validator)

### Relayer - Chaves Privadas (Obrigatório)
- [ ] `HYP_CHAINS_BSCTESTNET_SIGNER_KEY`
- [ ] `HYP_CHAINS_SOLANATESTNET_SIGNER_KEY`
- [ ] `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY`

### Validator - Chaves Privadas (Obrigatório)
- [ ] `HYP_VALIDATOR_KEY`
- [ ] `HYP_CHAINS_TERRACLASSICTESTNET_SIGNER_KEY`

---

## 🆘 Resolução de Problemas

### Erro: "Expected a valid private key in hex, base58 or bech32"

**Causa**: A chave privada está no formato incorreto ou ainda contém placeholders.

**Solução**:
1. Verifique se todas as variáveis de ambiente estão configuradas no Easypanel
2. Certifique-se de que as chaves começam com `0x` e têm 64 caracteres hex
3. Verifique se não há espaços extras antes ou depois das chaves

### Erro: "Provided config path via CONFIG_FILES does not exist"

**Causa**: Os arquivos de configuração JSON não foram criados.

**Solução**: Os arquivos `.example` são copiados automaticamente. Certifique-se de que os arquivos `.example` existem no diretório `hyperlane/`.

---

## 📚 Referências

- [Hyperlane Documentation](https://docs.hyperlane.xyz/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Easypanel Documentation](https://easypanel.io/docs)
