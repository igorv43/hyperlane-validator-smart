#!/usr/bin/env python3
"""
Script completo para verificar TODOS os validators anunciados no Sepolia
e identificar quais estão gerando checkpoints recentes.

Este script:
1. Consulta o validatorAnnounce para obter TODOS os validators
2. Para cada validator, obtém seus storage locations (S3 buckets)
3. Verifica cada bucket S3 para checkpoints recentes
4. Gera relatório completo com validators ativos

Uso:
    python3 scripts/check_all_validators_checkpoints.py [--recent-days 7] [--output report.json]

Requisitos:
    - web3.py
    - requests
"""

import json
import sys
import time
import argparse
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from collections import defaultdict

try:
    from web3 import Web3
except ImportError:
    print("❌ Erro: web3.py não instalado. Execute: pip install web3")
    sys.exit(1)

# Configuração
VALIDATOR_ANNOUNCE_ADDRESS = "0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
RPC_URLS = [
    "https://1rpc.io/sepolia",
    "https://sepolia.drpc.org",
    "https://rpc.ankr.com/eth_sepolia",
    "https://eth-sepolia-public.unifra.io"
]

# ABI do ValidatorAnnounce (apenas funções necessárias)
VALIDATOR_ANNOUNCE_ABI = [
    {
        "inputs": [],
        "name": "getAnnouncedValidators",
        "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address[]", "name": "_validators", "type": "address[]"}],
        "name": "getAnnouncedStorageLocations",
        "outputs": [{"internalType": "string[][]", "name": "", "type": "string[][]"}],
        "stateMutability": "view",
        "type": "function"
    }
]


def get_web3_connection() -> Optional[Web3]:
    """Conecta ao Web3 usando um dos RPCs disponíveis"""
    for rpc_url in RPC_URLS:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url, request_kwargs={'timeout': 30}))
            if w3.is_connected():
                return w3
        except Exception as e:
            continue
    return None


def get_all_announced_validators(w3: Web3) -> List[str]:
    """Obtém todos os validators anunciados"""
    try:
        contract = w3.eth.contract(address=Web3.to_checksum_address(VALIDATOR_ANNOUNCE_ADDRESS), abi=VALIDATOR_ANNOUNCE_ABI)
        validators = contract.functions.getAnnouncedValidators().call()
        return [Web3.to_checksum_address(v) for v in validators]
    except Exception as e:
        print(f"❌ Erro ao obter validators: {e}")
        return []


def get_validator_storage_locations(w3: Web3, validators: List[str]) -> Dict[str, List[str]]:
    """Obtém storage locations para uma lista de validators"""
    result = {}
    
    # Processa em lotes de 50 para evitar timeout
    batch_size = 50
    for i in range(0, len(validators), batch_size):
        batch = validators[i:i + batch_size]
        try:
            contract = w3.eth.contract(address=Web3.to_checksum_address(VALIDATOR_ANNOUNCE_ADDRESS), abi=VALIDATOR_ANNOUNCE_ABI)
            locations = contract.functions.getAnnouncedStorageLocations(batch).call()
            
            for validator, location_list in zip(batch, locations):
                # Filtra apenas S3 buckets
                s3_locations = [loc for loc in location_list if loc.startswith("s3://")]
                if s3_locations:
                    result[validator] = s3_locations
        except Exception as e:
            print(f"⚠️  Erro ao obter storage locations para lote {i//batch_size + 1}: {e}")
            continue
    
    return result


def parse_s3_path(s3_path: str) -> Optional[Dict[str, str]]:
    """Parse s3://bucket/region/folder into components"""
    if not s3_path.startswith("s3://"):
        return None
    
    parts = s3_path.replace("s3://", "").split("/")
    return {
        "bucket": parts[0],
        "region": parts[1] if len(parts) > 1 else "us-east-1",
        "folder": "/".join(parts[2:]) if len(parts) > 2 else "",
        "full_path": s3_path
    }


def check_s3_bucket_for_recent_checkpoints(bucket: str, region: str, folder: str, recent_days: int) -> Dict:
    """Verifica se o bucket S3 tem checkpoints recentes"""
    s3_path = f"s3://{bucket}/{region}/"
    if folder:
        s3_path += folder + "/"
    
    try:
        # Tenta listar checkpoints via API pública S3
        url = f"https://{bucket}.s3.{region}.amazonaws.com/?list-type=2&prefix=checkpoint&max-keys=1000"
        
        # Se não funcionar, tenta formato alternativo
        if region == "us-east-1":
            url = f"https://{bucket}.s3.amazonaws.com/?list-type=2&prefix=checkpoint&max-keys=1000"
        
        result = subprocess.run(
            ['curl', '-s', '--max-time', '10', url],
            capture_output=True,
            text=True,
            timeout=15
        )
        
        if result.returncode == 0 and result.stdout:
            try:
                root = ET.fromstring(result.stdout)
                checkpoints = []
                from datetime import timezone
                cutoff_date = datetime.now(timezone.utc) - timedelta(days=recent_days)
                
                for content in root.findall('.//{http://s3.amazonaws.com/doc/2006-03-01/}Contents'):
                    key = content.find('{http://s3.amazonaws.com/doc/2006-03-01/}Key')
                    last_modified = content.find('{http://s3.amazonaws.com/doc/2006-03-01/}LastModified')
                    size = content.find('{http://s3.amazonaws.com/doc/2006-03-01/}Size')
                    
                    if key is not None and last_modified is not None:
                        try:
                            # Parse date com timezone
                            mod_date_str = last_modified.text.replace('Z', '+00:00')
                            mod_date = datetime.fromisoformat(mod_date_str)
                            # Garante que tem timezone
                            if mod_date.tzinfo is None:
                                mod_date = mod_date.replace(tzinfo=timezone.utc)
                            checkpoints.append({
                                "key": key.text,
                                "last_modified": last_modified.text,
                                "date": mod_date,
                                "size": int(size.text) if size is not None else 0,
                                "url": f"https://{bucket}.s3.amazonaws.com/{key.text}"
                            })
                        except Exception as e:
                            continue
                
                if checkpoints:
                    checkpoints.sort(key=lambda x: x["date"], reverse=True)
                    latest = checkpoints[0]
                    recent_count = sum(1 for cp in checkpoints if cp["date"] >= cutoff_date)
                    
                    from datetime import timezone
                    now = datetime.now(timezone.utc)
                    age_days = (now - latest["date"]).days
                    
                    return {
                        "success": True,
                        "total_checkpoints": len(checkpoints),
                        "recent_checkpoints": recent_count,
                        "latest_checkpoint": latest,
                        "is_recent": latest["date"] >= cutoff_date,
                        "age_days": age_days,
                        "all_checkpoints": checkpoints[:10]  # Primeiros 10
                    }
                else:
                    return {
                        "success": True,
                        "total_checkpoints": 0,
                        "recent_checkpoints": 0,
                        "is_recent": False,
                        "error": "Nenhum checkpoint encontrado"
                    }
            except ET.ParseError:
                return {
                    "success": False,
                    "error": "Erro ao parsear XML do S3"
                }
        else:
            # Tenta verificar se bucket existe mas está vazio ou privado
            if "AccessDenied" in result.stderr or "403" in result.stderr:
                return {
                    "success": False,
                    "error": "AccessDenied - Bucket privado"
                }
            else:
                return {
                    "success": False,
                    "error": "Bucket vazio ou inacessível"
                }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)[:100]
        }


def main():
    parser = argparse.ArgumentParser(description="Verifica todos os validators anunciados e seus checkpoints")
    parser.add_argument("--recent-days", type=int, default=7, help="Dias para considerar checkpoint 'recente' (padrão: 7)")
    parser.add_argument("--output", type=str, default="all_validators_checkpoints_report.json", help="Arquivo de saída JSON")
    parser.add_argument("--limit", type=int, default=None, help="Limitar número de validators a verificar (para testes)")
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("🔍 VERIFICAÇÃO COMPLETA DE VALIDATORS E CHECKPOINTS")
    print("=" * 70)
    print(f"ValidatorAnnounce: {VALIDATOR_ANNOUNCE_ADDRESS}")
    print(f"Checkpoints recentes: últimos {args.recent_days} dias")
    print("")
    
    # Conecta ao Web3
    print("📡 Conectando ao Sepolia...")
    w3 = get_web3_connection()
    if not w3:
        print("❌ Erro: Não foi possível conectar a nenhum RPC")
        sys.exit(1)
    print("✅ Conectado!")
    print("")
    
    # Obtém todos os validators
    print("📋 Obtendo todos os validators anunciados...")
    all_validators = get_all_announced_validators(w3)
    if not all_validators:
        print("❌ Nenhum validator encontrado")
        sys.exit(1)
    
    if args.limit:
        all_validators = all_validators[:args.limit]
        print(f"⚠️  Limitado a {args.limit} validators para teste")
    
    print(f"✅ Encontrados {len(all_validators)} validators anunciados")
    print("")
    
    # Obtém storage locations
    print("📦 Obtendo storage locations dos validators...")
    validator_storages = get_validator_storage_locations(w3, all_validators)
    validators_with_storage = len(validator_storages)
    print(f"✅ {validators_with_storage} validators têm storage locations anunciadas")
    print("")
    
    # Verifica checkpoints de cada validator
    print("🔍 Verificando checkpoints em cada bucket S3...")
    print("(Isso pode demorar alguns minutos...)")
    print("")
    
    results = []
    active_validators = []
    total_buckets = sum(len(storages) for storages in validator_storages.values())
    checked_buckets = 0
    
    for i, (validator, storages) in enumerate(validator_storages.items(), 1):
        print(f"[{i}/{validators_with_storage}] Validator: {validator[:20]}...")
        
        validator_result = {
            "validator": validator,
            "storage_locations": storages,
            "buckets": []
        }
        
        has_recent = False
        
        for storage in storages:
            s3_info = parse_s3_path(storage)
            if not s3_info:
                continue
            
            checked_buckets += 1
            print(f"  📦 Verificando bucket: {s3_info['bucket']}...", end=" ", flush=True)
            
            bucket_result = check_s3_bucket_for_recent_checkpoints(
                s3_info['bucket'],
                s3_info['region'],
                s3_info['folder'],
                args.recent_days
            )
            
            bucket_info = {
                "s3_path": storage,
                "bucket": s3_info['bucket'],
                "region": s3_info['region'],
                **bucket_result
            }
            
            validator_result["buckets"].append(bucket_info)
            
            if bucket_result.get("is_recent", False):
                has_recent = True
                print(f"✅ RECENTE! (último: {bucket_result['latest_checkpoint']['last_modified']})")
            elif bucket_result.get("success"):
                age = bucket_result.get("age_days", 999)
                print(f"⚠️  Antigo ({age} dias)")
            else:
                print(f"❌ {bucket_result.get('error', 'Erro')}")
            
            # Pequeno delay para não sobrecarregar
            time.sleep(0.5)
        
        validator_result["has_recent_checkpoints"] = has_recent
        results.append(validator_result)
        
        if has_recent:
            active_validators.append(validator)
        
        print("")
    
    # Gera relatório
    report = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "config": {
            "recent_days": args.recent_days,
            "validator_announce": VALIDATOR_ANNOUNCE_ADDRESS
        },
        "summary": {
            "total_validators_announced": len(all_validators),
            "validators_with_storage": validators_with_storage,
            "validators_with_recent_checkpoints": len(active_validators),
            "total_buckets_checked": checked_buckets
        },
        "active_validators": active_validators,
        "all_validators": results
    }
    
    # Salva relatório
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    
    # Exibe resumo
    print("=" * 70)
    print("📊 RESUMO")
    print("=" * 70)
    print(f"Total de validators anunciados: {len(all_validators)}")
    print(f"Validators com storage: {validators_with_storage}")
    print(f"✅ Validators com checkpoints recentes: {len(active_validators)}")
    print(f"Buckets verificados: {checked_buckets}")
    print("")
    
    if active_validators:
        print("🎯 VALIDATORS ATIVOS (gerando checkpoints recentes):")
        print("-" * 70)
        for validator in active_validators:
            print(f"  ✅ {validator}")
            # Encontra detalhes do validator
            for v_result in results:
                if v_result["validator"].lower() == validator.lower():
                    for bucket in v_result["buckets"]:
                        if bucket.get("is_recent"):
                            latest = bucket["latest_checkpoint"]
                            print(f"     Bucket: {bucket['bucket']}")
                            print(f"     Último checkpoint: {latest['last_modified']}")
                            print(f"     URL: {latest['url']}")
                    break
            print("")
    else:
        print("⚠️  Nenhum validator com checkpoints recentes encontrado!")
        print("   (Todos os checkpoints são mais antigos que {args.recent_days} dias)")
    
    print("=" * 70)
    print(f"✅ Relatório completo salvo em: {args.output}")
    print("=" * 70)


if __name__ == "__main__":
    main()
