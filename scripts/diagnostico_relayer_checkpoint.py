#!/usr/bin/env python3
"""
Script para diagnosticar por que o relayer não está enviando transações
mesmo com checkpoint disponível no S3.
"""

import json
import sys
from web3 import Web3
import requests
from datetime import datetime

# Configuração
SEPOLIA_RPC = "https://1rpc.io/sepolia"
MAILBOX_ADDRESS = "0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766"
MESSAGE_ID = "0x93cb428f4bfd3fa2ccd552412b4e963f1dd7a9ac1bc702ce98c3c68dda9af860"
CHECKPOINT_URL = "https://hyperlane-validator-signatures-igorveras-sepolia.s3.us-east-1.amazonaws.com/checkpoint_864656_with_id.json"
TERRA_CLASSIC_DOMAIN = 1325
SEPOLIA_DOMAIN = 11155111

def main():
    print("=" * 80)
    print("🔍 DIAGNÓSTICO: Relayer não enviando transação para Terra Classic")
    print("=" * 80)
    print()
    
    # 1. Verificar checkpoint
    print("1️⃣ Verificando checkpoint no S3...")
    try:
        response = requests.get(CHECKPOINT_URL, timeout=10)
        if response.status_code == 200:
            checkpoint_data = response.json()
            print(f"   ✅ Checkpoint encontrado no S3")
            print(f"   📋 Message ID: {checkpoint_data['value']['message_id']}")
            print(f"   📋 Mailbox Domain: {checkpoint_data['value']['checkpoint']['mailbox_domain']}")
            print(f"   📋 Index: {checkpoint_data['value']['checkpoint']['index']}")
            print(f"   📋 Root: {checkpoint_data['value']['checkpoint']['root']}")
            print(f"   📋 Signature: {checkpoint_data['signature']['r'][:20]}...")
        else:
            print(f"   ❌ Erro ao acessar checkpoint: HTTP {response.status_code}")
            return
    except Exception as e:
        print(f"   ❌ Erro ao acessar checkpoint: {e}")
        return
    
    print()
    
    # 2. Verificar mensagem no mailbox
    print("2️⃣ Verificando mensagem no Mailbox de Sepolia...")
    try:
        w3 = Web3(Web3.HTTPProvider(SEPOLIA_RPC))
        if not w3.is_connected():
            print("   ❌ Erro ao conectar ao Sepolia")
            return
        
        print(f"   ✅ Conectado ao Sepolia (block: {w3.eth.block_number})")
        
        # ABI simplificado do Mailbox para verificar mensagens
        mailbox_abi = [
            {
                "anonymous": False,
                "inputs": [
                    {"indexed": True, "name": "messageId", "type": "bytes32"},
                    {"indexed": True, "name": "nonce", "type": "uint256"},
                    {"indexed": False, "name": "sender", "type": "address"},
                    {"indexed": False, "name": "destination", "type": "uint32"},
                    {"indexed": False, "name": "recipient", "type": "bytes32"},
                    {"indexed": False, "name": "body", "type": "bytes"}
                ],
                "name": "Dispatch",
                "type": "event"
            }
        ]
        
        mailbox = w3.eth.contract(address=Web3.to_checksum_address(MAILBOX_ADDRESS), abi=mailbox_abi)
        
        # Buscar eventos Dispatch recentes
        print(f"   🔍 Buscando eventos Dispatch recentes...")
        current_block = w3.eth.block_number
        from_block = max(0, current_block - 10000)
        
        events = mailbox.events.Dispatch.get_logs(fromBlock=from_block, toBlock=current_block)
        print(f"   📊 Encontrados {len(events)} eventos Dispatch nos últimos ~{current_block - from_block} blocos")
        
        # Verificar se a mensagem específica existe
        message_found = False
        for event in events:
            if event.args.messageId.hex() == MESSAGE_ID:
                message_found = True
                print(f"   ✅ Mensagem encontrada no evento Dispatch!")
                print(f"      📋 Nonce: {event.args.nonce}")
                print(f"      📋 Sender: {event.args.sender}")
                print(f"      📋 Destination: {event.args.destination}")
                print(f"      📋 Recipient: {event.args.recipient.hex()}")
                if event.args.destination == TERRA_CLASSIC_DOMAIN:
                    print(f"      ✅ Destino é Terra Classic ({TERRA_CLASSIC_DOMAIN})")
                else:
                    print(f"      ⚠️  Destino é {event.args.destination}, não Terra Classic ({TERRA_CLASSIC_DOMAIN})")
                break
        
        if not message_found:
            print(f"   ⚠️  Mensagem {MESSAGE_ID} não encontrada nos eventos recentes")
            print(f"   💡 Pode estar em blocos mais antigos")
        
    except Exception as e:
        print(f"   ❌ Erro ao verificar mailbox: {e}")
        import traceback
        traceback.print_exc()
    
    print()
    
    # 3. Verificar configuração do relayer
    print("3️⃣ Verificando configuração do relayer...")
    print("   💡 Verifique manualmente:")
    print("      - allowLocalCheckpointSyncers deve ser 'false'")
    print("      - relayChains deve incluir 'sepolia' e 'terraclassictestnet'")
    print("      - whitelist deve incluir {originDomain: [11155111], destinationDomain: [1325]}")
    print("      - AWS credentials devem estar configuradas")
    print("      - Signer key para terraclassictestnet deve estar configurada")
    
    print()
    
    # 4. Verificar validadores anunciados
    print("4️⃣ Verificando validadores anunciados para Sepolia...")
    print("   💡 O relayer precisa encontrar checkpoints de validadores anunciados")
    print("   💡 Verifique se o validador 'igorveras-sepolia' está anunciado no contrato validatorAnnounce")
    
    print()
    
    # 5. Resumo e recomendações
    print("=" * 80)
    print("📋 RESUMO E RECOMENDAÇÕES")
    print("=" * 80)
    print()
    print("✅ Checkpoint está disponível no S3")
    print()
    print("🔍 Próximos passos para diagnóstico:")
    print("   1. Verificar logs do relayer:")
    print("      docker logs hpl-relayer-testnet --tail 1000 | grep -i 'quorum\\|checkpoint\\|message'")
    print()
    print("   2. Verificar se o relayer está lendo do S3:")
    print("      docker logs hpl-relayer-testnet --tail 1000 | grep -i 's3\\|storage\\|validator.*announce'")
    print()
    print("   3. Verificar configuração do relayer:")
    print("      docker exec hpl-relayer-testnet cat /tmp/relayer.testnet.json | jq '.'")
    print()
    print("   4. Verificar se há erros de quorum:")
    print("      docker logs hpl-relayer-testnet --tail 1000 | grep -i 'unable.*reach.*quorum'")
    print()
    print("   5. Verificar se o validador está anunciado:")
    print("      python3 scripts/query_validator_announce.py")
    print()
    print("=" * 80)

if __name__ == "__main__":
    main()
