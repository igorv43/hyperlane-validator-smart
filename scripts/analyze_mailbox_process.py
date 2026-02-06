#!/usr/bin/env python3
"""
Script para analisar transações Process do Mailbox Sepolia
e identificar quem está processando mensagens
"""

import requests
import json
from datetime import datetime

MAILBOX_ADDRESS = "0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766"
ETHERSCAN_URL = "https://sepolia.etherscan.io"

print("=" * 70)
print("📊 ANÁLISE DE TRANSAÇÕES PROCESS DO MAILBOX")
print("=" * 70)
print(f"Mailbox: {MAILBOX_ADDRESS}")
print(f"Etherscan: {ETHERSCAN_URL}/address/{MAILBOX_ADDRESS}")
print("")
print("💡 INSTRUÇÕES:")
print("1. Acesse o Etherscan acima")
print("2. Vá na aba 'Transactions'")
print("3. Filtre por transações 'Process'")
print("4. Anote os endereços 'From' que estão processando")
print("")
print("Ou use o comando abaixo para verificar via API:")
print("")
print("curl 'https://api-sepolia.etherscan.io/api?module=account&action=txlist&address=0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766&startblock=10189000&endblock=99999999&sort=desc&apikey=YOUR_API_KEY' | jq '.result[] | select(.methodId != null) | {from: .from, hash: .hash, block: .blockNumber}'")
print("")
print("=" * 70)

