# 🎯 SOLUÇÃO RÁPIDA: ISM Faltando

## Problema Identificado
O relayer não encontra validadores de Solana porque falta configuração do ISM no agent-config.

## O que fazer AGORA:

### 1. Consultar validadores públicos do Hyperlane
Acesse: https://github.com/hyperlane-xyz/hyperlane-registry

Procure por:
- Validadores de `solanatestnet`  
- Validadores de `terraclassictestnet`

### 2. Adicionar ISM no agent-config.docker-testnet.json

Edite o arquivo: `hyperlane/agent-config.docker-testnet.json`

Adicione dentro de cada chain:
```json
"defaultIsm": {
  "type": "messageIdMultisigIsm",
  "validators": [
    "ENDEREÇOS_DOS_VALIDADORES_PUBLICOS_AQUI"
  ],
  "threshold": 1
}
```

### 3. Reiniciar o relayer
```bash
docker-compose -f docker-compose-testnet.yml restart relayer
docker logs hpl-relayer-testnet -f
```

## Links úteis:
- Registry: https://github.com/hyperlane-xyz/hyperlane-registry
- Docs: https://docs.hyperlane.xyz
- Discord: https://discord.gg/hyperlane
