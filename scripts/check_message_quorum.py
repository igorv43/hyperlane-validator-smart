#!/usr/bin/env python3
"""
Script para verificar o quorum de um message ID específico.
Verifica se há checkpoints suficientes dos validators anunciados.
"""

import json
import sys
import boto3
from datetime import datetime, timezone
from botocore.exceptions import ClientError
from web3 import Web3
from eth_abi import decode
import requests

# Configurações
MESSAGE_ID = "0xa14c33009edde860ef9f01803e8a6df1f35049e4775d79665972b5aa54627e6f"
VALIDATOR_ANNOUNCE_SEPOLIA = "0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
VALIDATOR_ANNOUNCE_TERRA = "0xe604c0fcb8ddcf5eb2ca20bc73f6c5fd3d7eedae2ce0278dd41fb58cec5969fe"

# ABI simplificado do validatorAnnounce
VALIDATOR_ANNOUNCE_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "validator", "type": "address"}],
        "name": "getAnnouncedStorageLocations",
        "outputs": [{"internalType": "string[]", "name": "", "type": "string[]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getAnnouncedValidators",
        "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# RPCs para Sepolia
SEPOLIA_RPCS = [
    "https://1rpc.io/sepolia",
    "https://sepolia.drpc.org",
    "https://rpc.ankr.com/eth_sepolia",
    "https://eth-sepolia-public.unifra.io"
]

# RPCs para Terra Classic
TERRA_RPCS = [
    "https://rpc.luncblaze.com",
    "https://terra-classic-rpc.publicnode.com",
    "https://terraclassic-rpc.publicnode.com"
]

def get_web3_connection(rpcs, chain_name):
    """Tenta conectar a um RPC."""
    for rpc in rpcs:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc, request_kwargs={'timeout': 10}))
            if w3.is_connected():
                print(f"✅ Conectado ao {chain_name} via {rpc}")
                return w3
        except Exception as e:
            continue
    return None

def query_contract(w3, contract_address, abi, function_name, args=[]):
    """Query a contract function."""
    try:
        contract = w3.eth.contract(address=Web3.to_checksum_address(contract_address), abi=abi)
        func = getattr(contract.functions, function_name)
        if args:
            result = func(*args).call()
        else:
            result = func().call()
        return result
    except Exception as e:
        print(f"❌ Erro ao chamar {function_name}: {e}")
        return None

def parse_s3_path(s3_path):
    """Parse S3 path: s3://bucket/region/folder"""
    if not s3_path.startswith("s3://"):
        return None
    
    parts = s3_path[5:].split("/")
    if len(parts) < 2:
        return None
    
    bucket = parts[0]
    region = parts[1]
    folder = "/".join(parts[2:]) if len(parts) > 2 else None
    
    return {
        "bucket": bucket,
        "region": region,
        "folder": folder,
        "s3_path": s3_path
    }

def check_checkpoint_in_s3(bucket, region, message_id, folder=None):
    """Verifica se existe checkpoint para o message ID no S3."""
    try:
        s3_client = boto3.client('s3', region_name=region)
        
        # Padrões de nome de checkpoint
        patterns = [
            f"checkpoint_{message_id}.json",
            f"checkpoint_{message_id}_with_id.json",
            f"checkpoint_{message_id.replace('0x', '')}.json",
            f"checkpoint_{message_id.replace('0x', '')}_with_id.json"
        ]
        
        if folder:
            patterns = [f"{folder}/{p}" if not p.startswith(folder) else p for p in patterns]
        
        # Lista todos os arquivos no bucket
        prefix = folder + "/" if folder else ""
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
        
        if 'Contents' not in response:
            return None
        
        # Procura por checkpoints que contenham o message ID
        message_id_short = message_id.replace("0x", "").lower()
        found_checkpoints = []
        
        for obj in response['Contents']:
            key = obj['Key']
            # Verifica se o nome do arquivo contém o message ID
            if message_id_short in key.lower() or any(p in key for p in patterns):
                try:
                    # Tenta baixar e verificar o conteúdo
                    obj_response = s3_client.get_object(Bucket=bucket, Key=key)
                    content = json.loads(obj_response['Body'].read().decode('utf-8'))
                    
                    # Verifica se o checkpoint contém o message ID correto
                    if 'value' in content and 'message_id' in content['value']:
                        checkpoint_msg_id = content['value']['message_id']
                        if checkpoint_msg_id.lower() == message_id.lower():
                            found_checkpoints.append({
                                "key": key,
                                "last_modified": obj['LastModified'].isoformat(),
                                "size": obj['Size'],
                                "url": f"https://{bucket}.s3.{region}.amazonaws.com/{key}",
                                "content": content
                            })
                except Exception as e:
                    # Se não conseguir ler, ainda adiciona o arquivo encontrado
                    found_checkpoints.append({
                        "key": key,
                        "last_modified": obj['LastModified'].isoformat(),
                        "size": obj['Size'],
                        "url": f"https://{bucket}.s3.{region}.amazonaws.com/{key}",
                        "error": str(e)
                    })
        
        return found_checkpoints if found_checkpoints else None
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'AccessDenied':
            return {"error": "AccessDenied", "bucket": bucket}
        return {"error": str(e), "bucket": bucket}
    except Exception as e:
        return {"error": str(e), "bucket": bucket}

def main():
    print("=" * 70)
    print("🔍 VERIFICAÇÃO DE QUORUM PARA MESSAGE ID")
    print("=" * 70)
    print(f"Message ID: {MESSAGE_ID}")
    print("")
    
    # Conecta ao Sepolia para pegar validators
    print("📡 Conectando ao Sepolia...")
    w3_sepolia = get_web3_connection(SEPOLIA_RPCS, "Sepolia")
    
    if not w3_sepolia:
        print("❌ Não foi possível conectar ao Sepolia")
        return
    
    # Pega validators anunciados
    print("📋 Buscando validators anunciados...")
    validators = query_contract(w3_sepolia, VALIDATOR_ANNOUNCE_SEPOLIA, VALIDATOR_ANNOUNCE_ABI, "getAnnouncedValidators")
    
    if not validators:
        print("❌ Não foi possível obter validators")
        return
    
    print(f"✅ Encontrados {len(validators)} validators anunciados")
    print("")
    
    # Para cada validator, busca storage locations e verifica checkpoints
    results = {
        "message_id": MESSAGE_ID,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "validators_checked": 0,
        "validators_with_checkpoint": 0,
        "validators": []
    }
    
    # Foca nos validators ativos que identificamos anteriormente
    active_validator = "0x01227B3361d200722c3656f899b48dE187A32494"
    
    print(f"🔍 Verificando validator ativo: {active_validator}")
    
    storage_locations = query_contract(
        w3_sepolia, 
        VALIDATOR_ANNOUNCE_SEPOLIA, 
        VALIDATOR_ANNOUNCE_ABI, 
        "getAnnouncedStorageLocations",
        [active_validator]
    )
    
    if storage_locations:
        results["validators_checked"] += 1
        validator_result = {
            "validator": active_validator,
            "storage_locations": storage_locations,
            "checkpoints": []
        }
        
        for storage_loc in storage_locations:
            s3_info = parse_s3_path(storage_loc)
            if s3_info:
                print(f"  📦 Verificando bucket: {s3_info['bucket']} ({s3_info['region']})")
                checkpoint = check_checkpoint_in_s3(
                    s3_info['bucket'],
                    s3_info['region'],
                    MESSAGE_ID,
                    s3_info['folder']
                )
                
                if checkpoint:
                    if isinstance(checkpoint, list) and len(checkpoint) > 0:
                        validator_result["checkpoints"].append({
                            "s3_path": storage_loc,
                            "found": True,
                            "checkpoints": checkpoint
                        })
                        results["validators_with_checkpoint"] += 1
                        print(f"    ✅ Checkpoint encontrado!")
                    elif isinstance(checkpoint, dict) and "error" in checkpoint:
                        validator_result["checkpoints"].append({
                            "s3_path": storage_loc,
                            "found": False,
                            "error": checkpoint.get("error")
                        })
                        print(f"    ❌ Erro: {checkpoint.get('error')}")
                else:
                    validator_result["checkpoints"].append({
                        "s3_path": storage_loc,
                        "found": False,
                        "reason": "Nenhum checkpoint encontrado"
                    })
                    print(f"    ❌ Nenhum checkpoint encontrado")
        
        results["validators"].append(validator_result)
    
    print("")
    print("=" * 70)
    print("📊 RESULTADO DA VERIFICAÇÃO")
    print("=" * 70)
    print(f"Validators verificados: {results['validators_checked']}")
    print(f"Validators com checkpoint: {results['validators_with_checkpoint']}")
    print("")
    
    if results['validators_with_checkpoint'] > 0:
        print("✅ QUORUM: Checkpoint encontrado!")
        print("")
        print("Detalhes dos checkpoints encontrados:")
        for validator in results['validators']:
            for checkpoint_info in validator['checkpoints']:
                if checkpoint_info.get('found'):
                    for cp in checkpoint_info.get('checkpoints', []):
                        print(f"  - {cp.get('url', 'N/A')}")
                        print(f"    Modificado: {cp.get('last_modified', 'N/A')}")
    else:
        print("❌ QUORUM: Nenhum checkpoint encontrado")
        print("")
        print("Possíveis razões:")
        print("  1. O validator ainda não gerou o checkpoint para esta mensagem")
        print("  2. O checkpoint está em um bucket diferente")
        print("  3. O message ID está incorreto")
        print("  4. O validator não está ativo")
    
    # Salva resultado em JSON
    output_file = f"message_quorum_check_{MESSAGE_ID[:20]}.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print("")
    print(f"📄 Resultado completo salvo em: {output_file}")

if __name__ == "__main__":
    main()
