#!/bin/bash

# Atualizar JSON para mostrar endereços de forma mais clara
jq '.data.ismValidators[] | {
  validator: .validator,
  isAnnounced: .isAnnounced,
  storageLocations: (.storageLocations | if type == "array" then . else [] end),
  note: (if (.storageLocations | length == 0) then "Nenhuma storage location anunciada no BSC ValidatorAnnounce" else "Storage locations encontradas" end)
}' resultado-validatorannounce-bsc.json

