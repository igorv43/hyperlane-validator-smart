# Script: Verificação Completa de Validators e Checkpoints

## 📋 Descrição

Este script verifica **TODOS** os validators anunciados no contrato `validatorAnnounce` do Sepolia e identifica quais estão gerando checkpoints recentes.

## 🎯 Objetivo

Identificar validators ativos que você pode usar, já que estão gerando checkpoints recentes.

## 🚀 Como Usar

### Execução Completa (Recomendado)

```bash
# Verifica TODOS os validators (pode demorar 10-30 minutos)
python3 scripts/check_all_validators_checkpoints.py --recent-days 7
```

### Opções Disponíveis

```bash
# Considerar checkpoints dos últimos 30 dias
python3 scripts/check_all_validators_checkpoints.py --recent-days 30

# Salvar em arquivo específico
python3 scripts/check_all_validators_checkpoints.py --output meu_relatorio.json

# Limitar a N validators (útil para testes)
python3 scripts/check_all_validators_checkpoints.py --limit 10

# Combinar opções
python3 scripts/check_all_validators_checkpoints.py --recent-days 30 --output validators_ativos.json
```

## 📊 Saída

O script gera um arquivo JSON (`all_validators_checkpoints_report.json` por padrão) com:

- **Resumo**: Total de validators, validators com storage, validators ativos
- **Validators ativos**: Lista de validators gerando checkpoints recentes
- **Detalhes completos**: Para cada validator:
  - Endereço
  - Storage locations (buckets S3)
  - Status dos checkpoints (recentes/antigos)
  - Data do último checkpoint
  - URLs dos checkpoints

## ⏱️ Tempo de Execução

- **Teste rápido** (--limit 10): ~2-3 minutos
- **Análise completa** (todos os validators): ~10-30 minutos

O tempo depende de:
- Número de validators anunciados
- Número de buckets S3 por validator
- Velocidade de resposta dos buckets S3

## 📝 Exemplo de Saída

```
======================================================================
🔍 VERIFICAÇÃO COMPLETA DE VALIDATORS E CHECKPOINTS
======================================================================
✅ Encontrados 793 validators anunciados
✅ 150 validators têm storage locations anunciadas
✅ Validators com checkpoints recentes: 5

🎯 VALIDATORS ATIVOS (gerando checkpoints recentes):
  ✅ 0x1234...5678
     Bucket: hyperlane-validator-active-1
     Último checkpoint: 2026-02-04T12:00:00.000Z
     URL: https://hyperlane-validator-active-1.s3.amazonaws.com/checkpoint_12345.json
```

## 🔍 Interpretação dos Resultados

### Validators Ativos ✅
- Estão gerando checkpoints recentes (dentro do período especificado)
- Você pode usar esses validators
- Seus buckets S3 têm checkpoints atualizados

### Validators Inativos ⚠️
- Checkpoints são antigos (mais antigos que o período especificado)
- Não estão gerando checkpoints recentes
- Não recomendado para uso

## 💡 Dicas

1. **Comece com um teste**: Use `--limit 10` para testar rapidamente
2. **Ajuste o período**: Use `--recent-days 30` para verificar últimos 30 dias
3. **Execute em background**: Para análise completa, execute em background:
   ```bash
   nohup python3 scripts/check_all_validators_checkpoints.py > check_validators.log 2>&1 &
   ```
4. **Verifique o relatório**: O JSON gerado tem todas as informações detalhadas

## 🐛 Solução de Problemas

### Erro: "web3.py não instalado"
```bash
pip install web3
```

### Erro: "Timeout ao conectar RPC"
- O script tenta múltiplos RPCs automaticamente
- Se todos falharem, verifique sua conexão

### Buckets retornam "AccessDenied"
- Normal para buckets privados
- O script continua verificando outros buckets

## 📄 Arquivos Gerados

- `all_validators_checkpoints_report.json`: Relatório completo em JSON
- Logs no console: Progresso em tempo real
