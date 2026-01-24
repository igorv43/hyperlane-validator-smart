#!/bin/bash

# Atualizar resultado-validatorannounce-bsc.json com formato igual ao Terra Classic

cat resultado-validatorannounce-bsc.json | jq '{
  validatorAnnounce: .validatorAnnounce,
  rpc: .rpc,
  timestamp: .timestamp,
  data: {
    storage_locations: [
      .data.ismValidators[] | [
        (.validator | ascii_downcase | gsub("0x"; "")),
        (.storageLocations | if type == "array" then . else [] end)
      ]
    ]
  }
}' 2>/dev/null | tee resultado-validatorannounce-bsc-formato-terra.json && echo "" && echo "✅ JSON atualizado no formato Terra Classic!"

