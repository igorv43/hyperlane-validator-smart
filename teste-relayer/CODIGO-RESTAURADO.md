# ✅ Código Restaurado para Versão que Funcionava

## 🔄 Alterações Aplicadas

O código foi restaurado para a versão que estava processando mensagens corretamente, baseado no `docker-compose-testnet.yml` que funciona.

### Mudanças:

1. **Volume `/etc/hyperlane` agora é editável:**
   - Removido `:ro` (read-only)
   - Permite que o `sed` edite o arquivo diretamente

2. **Comandos `sed` simplificados:**
   - Restaurado para a versão simples que funciona
   - Mesma lógica do `docker-compose-testnet.yml`

3. **Arquivo editado diretamente:**
   - Não usa mais `/tmp/relayer.testnet.json`
   - Edita diretamente `/etc/hyperlane/relayer.testnet.json`

## 📋 Comando para Reiniciar

```bash
cd /home/lunc/hyperlane-validator-smart
docker compose -f teste-relayer/docker-compose-relayer-only.yml down
docker compose -f teste-relayer/docker-compose-relayer-only.yml --env-file .env up -d
```

## ✅ O que Esperar

Após reiniciar, o relayer deve:
- Substituir corretamente as chaves privadas
- Inicializar o Terra Classic corretamente
- Descobrir validators
- Ler checkpoints do S3
- Processar mensagens (pool_size deve aumentar)

---

**Data:** 2026-01-23
**Status:** ✅ Código restaurado para versão funcional
