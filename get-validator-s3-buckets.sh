#!/bin/bash

VALIDATOR_ANNOUNCE="0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
API_KEY="CYUPN3Q66JIMRGQWYUDXJKQH4SX8YIYZMW"

VALIDATORS=(
  "0xb22b65f202558adf86a8bb2847b76ae1036686a5"
  "0x469f0940684d147defc44f3647146cb90dd0bc8e"
  "0xd3c75dcf15056012a4d74c483a0c6ea11d8c2b83"
)

echo "========================================="
echo "📦 BUCKETS S3 DOS VALIDATORS DE SEPOLIA"
echo "========================================="
echo ""
echo "Contrato validatorAnnounce: $VALIDATOR_ANNOUNCE"
echo ""

for i in "${!VALIDATORS[@]}"; do
  validator="${VALIDATORS[$i]}"
  echo "Validator $((i+1)): $validator"
  echo "  Para obter os buckets S3, acesse:"
  echo "  https://sepolia.etherscan.io/address/$VALIDATOR_ANNOUNCE"
  echo "  Na aba 'Read Contract', execute:"
  echo "  getAnnouncedStorageLocations($validator)"
  echo ""
done

echo "========================================="
echo "💡 ALTERNATIVA: Usar cast com RPC"
echo "========================================="
echo ""
echo "cast call $VALIDATOR_ANNOUNCE \\"
echo "  \"getAnnouncedStorageLocations(address)(string[])\" \\"
echo "  VALIDATOR_ADDRESS \\"
echo "  --rpc-url https://sepolia.drpc.org"
echo ""
