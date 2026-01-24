# 📊 Resultado: Consulta ValidatorAnnounce Terra Classic

## 🔍 Tentativas Realizadas

### 1. Endereço do Exemplo Fornecido
- **Endereço:** `terra1e604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe`
- **Resultado:** ❌ Erro: "decoding bech32 failed: invalid character not part of charset: 98"
- **Problema:** O endereço contém caracteres inválidos para bech32 (o caractere 'b' não é válido)

### 2. Endereço Convertido do Config
- **Endereço Hex no Config:** `0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe`
- **Endereço Bech32 Convertido:** `terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5`
- **Status:** Testando...

## 📋 Queries Testadas

### Query 1: announced_validators
```bash
terrad query wasm contract-state smart \
  terra1e604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe \
  '{"announced_validators": {}}' \
  --chain-id rebel-2 \
  --node https://rpc.luncblaze.com
```

### Query 2: announced_storage_location (para cada validator)
```bash
terrad query wasm contract-state smart \
  terra1e604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe \
  '{"announced_storage_location": {"validator": "0x242d8a855a8c932dec51f7999ae7d1e48b10c95e"}}' \
  --chain-id rebel-2 \
  --node https://rpc.luncblaze.com
```

### Query 3: announced_storage_locations (todos)
```bash
terrad query wasm contract-state smart \
  terra1e604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe \
  '{"announced_storage_locations": {}}' \
  --chain-id rebel-2 \
  --node https://rpc.luncblaze.com
```

## ⚠️ Problema Identificado

O endereço do exemplo fornecido (`terra1e604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe`) não é um endereço bech32 válido. O caractere 'b' (ASCII 98) não faz parte do charset bech32.

## ✅ Próximos Passos

1. **Verificar endereço correto do ValidatorAnnounce no Terra Classic**
   - O endereço no config é: `0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe`
   - Convertido para bech32: `terra1uczvpl9cmh84avk2yz788ak9l57hamdw9nsz0rw5r76cemzed8lqntfxf5`

2. **Testar com endereço convertido**
   - Usar o endereço bech32 convertido corretamente

3. **Verificar se o contrato existe**
   - Consultar o contrato diretamente para verificar se existe

4. **Alternativa: Consultar via Block Explorer**
   - Usar Terra Finder ou outro explorer para verificar o contrato

## 🔗 Referências

- [Fonte fornecida](https://github.com/igorv43/hyperlane-validator/blob/main/COMO-RELAYER-DESCOBRE-S3.md)
- Config: `hyperlane/agent-config.docker-testnet.json` linha 174
