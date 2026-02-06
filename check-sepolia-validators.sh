#!/bin/bash

echo "========================================="
echo "🔍 VERIFICANDO VALIDATORS DE SEPOLIA"
echo "========================================="
echo ""

VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
VALIDATORS=(
  "0xb22b65f202558adf86a8bb2847b76ae1036686a5"
  "0x469f0940684d147defc44f3647146cb90dd0bc8e"
  "0xd3c75dcf15056012a4d74c483a0c6ea11d8c2b83"
)

echo "Contrato validatorAnnounce: $VALIDATOR_ANNOUNCE"
echo ""
echo "Para verificar os validators anunciados, acesse:"
echo "https://sepolia.etherscan.io/address/$VALIDATOR_ANNOUNCE"
echo ""
echo "Na aba 'Read Contract', execute:"
echo "1. getAnnouncedValidators() → Lista todos os validators"
echo ""
echo "Para cada validator abaixo, execute:"
echo "2. getAnnouncedStorageLocations(address) → Retorna buckets S3"
echo ""

for i in "${!VALIDATORS[@]}"; do
  validator="${VALIDATORS[$i]}"
  echo "Validator $((i+1)): $validator"
  echo "  Verificar bucket S3: getAnnouncedStorageLocations($validator)"
  echo ""
done

echo "========================================="
echo "📦 VERIFICAR CHECKPOINTS NO S3"
echo "========================================="
echo ""
echo "Para cada bucket S3 encontrado, execute:"
echo "  aws s3 ls s3://BUCKET_NAME/ --recursive | grep checkpoint | tail -10"
echo ""
echo "Verificar se há checkpoints recentes (últimas 24h):"
echo "  aws s3 ls s3://BUCKET_NAME/ --recursive --recursive | tail -20"
