#!/bin/bash

WARP_ISM="0xb14FBB042272786B4Cb3af86207c20E4f865e0F3"
SEPOLIA_RPC="https://1rpc.io/sepolia"

echo "========================================="
echo "🔍 VERIFICAÇÃO FINAL DO ISM"
echo "========================================="
echo ""

echo "📍 ISM do Warp Route:"
echo "   $WARP_ISM"
echo ""
echo "🔗 Links úteis:"
echo "   Etherscan: https://sepolia.etherscan.io/address/$WARP_ISM"
echo "   Código: https://sepolia.etherscan.io/address/$WARP_ISM#code"
echo "   Eventos: https://sepolia.etherscan.io/address/$WARP_ISM#events"
echo "   Storage: https://sepolia.etherscan.io/address/$WARP_ISM#readContract"
echo ""

echo "💡 INSTRUÇÕES PARA OBTER VALIDADORES MANUALMENTE:"
echo ""
echo "1. Acesse: https://sepolia.etherscan.io/address/$WARP_ISM#readContract"
echo ""
echo "2. Tente os seguintes métodos (se disponíveis):"
echo "   - validators() → retorna array de endereços"
echo "   - validatorCount() → retorna número de validadores"
echo "   - validatorAt(uint256 index) → retorna validador em posição específica"
echo "   - threshold() → retorna threshold necessário"
echo ""
echo "3. Se for MessageIdMultisig, os validadores podem estar em:"
echo "   - Storage slots 2, 3, 4... (um validador por slot)"
echo "   - Ou em um mapeamento específico"
echo ""

echo "4️⃣ Tentando método alternativo: verificar eventos de criação/configuração..."
echo ""

# Buscar eventos que possam ter validadores
EVENT_TOPICS=(
    "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0"  # OwnershipTransferred
    "0x"$(cast keccak "ValidatorEnrolled(address)" | cut -c3-)
    "0x"$(cast keccak "ValidatorsUpdated(address[],uint8)" | cut -c3-)
)

for TOPIC in "${EVENT_TOPICS[@]}"; do
    if [ "$TOPIC" != "0x" ]; then
        EVENTS=$(cast logs --from-block 0 --to-block latest --address "$WARP_ISM" --topic0 "$TOPIC" --rpc-url "$SEPOLIA_RPC" 2>/dev/null | head -5)
        if [ -n "$EVENTS" ] && [ "$EVENTS" != "" ]; then
            echo "   Eventos encontrados com topic $TOPIC:"
            echo "$EVENTS" | sed 's/^/      /'
            echo ""
        fi
    fi
done

echo ""
echo "========================================="
echo "✅ Verificação concluída"
echo "========================================="
echo ""
echo "📝 PRÓXIMO PASSO RECOMENDADO:"
echo "   Acesse o Etherscan e use a interface 'Read Contract' para"
echo "   chamar os métodos disponíveis e obter os validadores."
echo ""

