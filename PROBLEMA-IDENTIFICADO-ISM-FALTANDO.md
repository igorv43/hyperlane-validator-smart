# 🎯 PROBLEMA IDENTIFICADO: ISM Faltando na Configuração

## 📋 Resumo do Problema

**Sintoma:** Mensagens de Solana → Terra Classic não chegam ao destino

**Causa Raiz:** Falta configuração do ISM (Interchain Security Module) no agent-config

## 🔍 Diagnóstico Realizado

### ✅ O que está funcionando:
1. Relayer está rodando e sincronizando mensagens de Solana
2. Whitelist está configurada: Solana (1399811150) ↔ Terra Classic (1325)
3. Solana está nas chains do relayer: `terraclassictestnet,bsctestnet,solanatestnet`
4. RPC do Solana está acessível: `https://api.testnet.solana.com`
5. Contratos do Solana estão configurados:
   - Mailbox: `75HBBLae3ddeneJVrZeyrDfv6vb7SMC3aCpBucSXS5aR`
   - ValidatorAnnounce: `8qNYSi9EP1xSnRjtMpyof88A26GBbdcrsa61uSaHiwx3`

### ❌ O que está faltando:

**ISM (Interchain Security Module) não está configurado!**

```json
// Terra Classic - agent-config
{
  "messageIdMultisigIsm": null,
  "interchainSecurityModule": null  // ❌ PROBLEMA!
}

// Solana - agent-config  
{
  "interchainSecurityModule": null  // ❌ PROBLEMA!
}
```

## 🎯 O que é o ISM?

O **ISM (Interchain Security Module)** informa ao relayer:
- Quais validadores ele deve consultar
- Onde buscar os checkpoints (S3, localstorage, etc)
- Quantas assinaturas são necessárias (threshold)
- De onde os validadores públicos do Hyperlane devem ser descobertos

**Sem ISM configurado, o relayer não sabe onde procurar os checkpoints!**

## 🔧 Solução

### Opção 1: Usar Validadores Públicos do Hyperlane (Recomendado)

Você precisa adicionar a configuração do ISM no `agent-config.docker-testnet.json` para informar ao relayer onde estão os validadores públicos do Hyperlane.

**Passos:**

1. **Consultar o repositório oficial do Hyperlane para validadores públicos:**
   - GitHub: https://github.com/hyperlane-xyz/hyperlane-registry
   - Procurar por validadores de `solanatestnet` e `terraclassictestnet`

2. **Adicionar configuração do ISM no agent-config:**

```json
{
  "chains": {
    "terraclassictestnet": {
      // ... configurações existentes ...
      "defaultIsm": {
        "type": "messageIdMultisigIsm",
        "validators": [
          // Endereços dos validadores públicos do Hyperlane
          "ENDEREÇO_VALIDATOR_1",
          "ENDEREÇO_VALIDATOR_2"
        ],
        "threshold": 1
      }
    },
    "solanatestnet": {
      // ... configurações existentes ...
      "defaultIsm": {
        "type": "messageIdMultisigIsm",
        "validators": [
          // Endereços dos validadores públicos do Hyperlane para Solana
          "ENDEREÇO_VALIDATOR_SOLANA_1",
          "ENDEREÇO_VALIDATOR_SOLANA_2"
        ],
        "threshold": 1
      }
    }
  }
}
```

3. **Reiniciar o relayer:**
```bash
docker-compose -f docker-compose-testnet.yml restart relayer
```

### Opção 2: Consultar Documentação do Hyperlane

Acessar a documentação oficial do Hyperlane para verificar:
- Lista de validadores públicos testnet
- Configuração do ISM para testnet
- Exemplo de configuração completa

**Links úteis:**
- Documentação: https://docs.hyperlane.xyz
- Registry: https://github.com/hyperlane-xyz/hyperlane-registry
- Discord: https://discord.gg/hyperlane (para suporte)

## 📊 Por que Terra Classic → Solana funciona?

Terra Classic → Solana funciona porque:
1. Você tem um validator de Terra Classic rodando
2. Esse validator está gerando checkpoints e salvando no S3
3. O relayer consegue ler esses checkpoints do S3

## 📊 Por que Solana → Terra Classic não funciona?

Solana → Terra Classic não funciona porque:
1. ❌ Não há ISM configurado informando onde estão os validadores de Solana
2. ❌ Relayer não sabe onde procurar checkpoints de mensagens de Solana
3. ❌ Mesmo que existam validadores públicos do Hyperlane, o relayer não sabe como encontrá-los

## 🚀 Próximos Passos

1. **Pesquisar validadores públicos do Hyperlane:**
   ```bash
   # Verificar no repositório do Hyperlane
   git clone https://github.com/hyperlane-xyz/hyperlane-registry
   cd hyperlane-registry
   # Procurar por configurações de solanatestnet e terraclassictestnet
   ```

2. **Atualizar agent-config.docker-testnet.json:**
   - Adicionar `defaultIsm` com lista de validadores públicos
   - Configurar `threshold` (geralmente 1 para testnet)

3. **Reiniciar relayer e monitorar:**
   ```bash
   docker-compose -f docker-compose-testnet.yml restart relayer
   docker logs hpl-relayer-testnet -f | grep -i "checkpoint\|validator"
   ```

4. **Verificar se checkpoints estão sendo encontrados:**
   - Logs devem mostrar: "Reading checkpoint from..."
   - Logs devem mostrar validadores sendo descobertos

## 📝 Conclusão

O problema não é falta de validadores públicos do Hyperlane, mas sim **falta de configuração do ISM** no agent-config para informar ao relayer onde esses validadores estão.

**Status:** Aguardando configuração do ISM com validadores públicos do Hyperlane

**Documentos criados:**
- `diagnostico-solana-terra.sh` - Script de diagnóstico
- `DIAGNOSTICO-SOLANA-TERRA.md` - Análise inicial
- `PROBLEMA-IDENTIFICADO-ISM-FALTANDO.md` - Este documento (causa raiz)
- `verificar-validadores-publicos-solana.sh` - Script de verificação

---

**Data:** 2026-01-29  
**Relayer:** hpl-relayer-testnet  
**Próximo passo:** Configurar ISM com validadores públicos do Hyperlane
