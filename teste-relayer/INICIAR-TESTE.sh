#!/bin/bash

# Script para iniciar o teste do relayer

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              INICIAR TESTE DO RELAYER                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose-relayer-only.yml" ]; then
    echo "❌ Execute este script do diretório teste-relayer/"
    exit 1
fi

# Verificar variáveis de ambiente
echo "Verificando variáveis de ambiente..."
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "⚠️  AWS_ACCESS_KEY_ID ou AWS_SECRET_ACCESS_KEY não configuradas"
    echo "Configure antes de continuar:"
    echo "  export AWS_ACCESS_KEY_ID=\"...\""
    echo "  export AWS_SECRET_ACCESS_KEY=\"...\""
    echo ""
    read -p "Continuar mesmo assim? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Iniciar o relayer
echo "Iniciando o relayer..."
docker-compose -f docker-compose-relayer-only.yml up -d

# Aguardar alguns segundos
echo "Aguardando relayer iniciar..."
sleep 5

# Verificar se está rodando
if docker ps | grep -q "hpl-relayer-testnet-local"; then
    echo "✅ Relayer está rodando"
    echo ""
    echo "Próximos passos:"
    echo "  1. Ver logs: docker logs -f hpl-relayer-testnet-local"
    echo "  2. Executar diagnóstico: ./diagnostico.sh"
    echo "  3. Acessar container: docker exec -it hpl-relayer-testnet-local sh"
else
    echo "❌ Relayer não está rodando. Verifique os logs:"
    echo "  docker logs hpl-relayer-testnet-local"
fi

