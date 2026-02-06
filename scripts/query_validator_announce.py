#!/usr/bin/env python3
"""
Script para consultar TODAS as funções do contrato ValidatorAnnounce
Gera relatório completo em JSON com informações sobre validators e seus buckets S3

Uso:
    python3 query_validator_announce.py > validator_announce_report.json

Requisitos:
    pip install web3

Autor: Hyperlane Validator Smart
Data: 2026-02-04
"""

import json
import sys
from web3 import Web3
from datetime import datetime
import time

# Configuração do contrato ValidatorAnnounce no Sepolia
CONTRACT_ADDRESS = "0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9"
CHAIN_ID = 11155111  # Sepolia Testnet

# Validators específicos para consulta (pode ser modificado)
VALIDATORS = [
    "0xb22b65f202558adf86a8bb2847b76ae1036686a5",
    "0x469f0940684d147defc44f3647146cb90dd0bc8e",
    "0xd3c75dcf15056012a4d74c483a0c6ea11d8c2b83"
]

# ABI completo do contrato ValidatorAnnounce
VALIDATOR_ANNOUNCE_ABI = [
    {
        "inputs": [{"internalType": "address[]", "name": "_validators", "type": "address[]"}],
        "name": "getAnnouncedStorageLocations",
        "outputs": [{"internalType": "string[][]", "name": "", "type": "string[][]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getAnnouncedValidators",
        "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "localDomain",
        "outputs": [{"internalType": "uint32", "name": "", "type": "uint32"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "mailbox",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function"
    }
]

# Lista de RPCs para tentar (fallback)
RPCS = [
    {"url": "https://sepolia.drpc.org", "name": "drpc.org"},
    {"url": "https://rpc.ankr.com/eth_sepolia", "name": "ankr"},
    {"url": "https://eth-sepolia-public.unifra.io", "name": "unifra"},
    {"url": "https://1rpc.io/sepolia", "name": "1rpc.io"}
]


def query_contract(rpc_url, function_name, *args, max_retries=2):
    """
    Consulta uma função do contrato com retry automático
    
    Args:
        rpc_url: URL do RPC endpoint
        function_name: Nome da função a ser chamada
        *args: Argumentos para a função
        max_retries: Número máximo de tentativas
    
    Returns:
        tuple: (resultado, erro, tipo_erro)
    """
    for attempt in range(max_retries):
        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url, request_kwargs={'timeout': 15}))
            if not w3.is_connected():
                if attempt < max_retries - 1:
                    time.sleep(1)
                    continue
                return None, f"Falha ao conectar ao RPC: {rpc_url}", None
            
            contract = w3.eth.contract(
                address=Web3.to_checksum_address(CONTRACT_ADDRESS),
                abi=VALIDATOR_ANNOUNCE_ABI
            )
            
            func = getattr(contract.functions, function_name)
            if args:
                result = func(*args).call()
            else:
                result = func().call()
            
            return result, None, None
        except Exception as e:
            error_msg = str(e)
            error_type = type(e).__name__
            if attempt < max_retries - 1:
                time.sleep(1)
                continue
            return None, error_msg, error_type
    return None, "Max retries exceeded", None


def main():
    """
    Função principal que gera o relatório completo
    """
    result = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "contract": {
            "address": CONTRACT_ADDRESS,
            "chain": "Sepolia Testnet",
            "chainId": CHAIN_ID,
            "etherscan_url": f"https://sepolia.etherscan.io/address/{CONTRACT_ADDRESS}#readContract"
        },
        "contract_info": {},
        "all_announced_validators": {},
        "validators": []
    }
    
    # Consulta informações do contrato (funções sem parâmetros)
    print("Consultando informações do contrato...", file=sys.stderr)
    for func in ["localDomain", "mailbox", "getAnnouncedValidators"]:
        for rpc in RPCS:
            value, error, error_type = query_contract(rpc["url"], func)
            if value is not None:
                if func == "getAnnouncedValidators":
                    result["all_announced_validators"] = {
                        "value": [addr for addr in value] if isinstance(value, (list, tuple)) else [str(value)],
                        "count": len(value) if isinstance(value, (list, tuple)) else 1,
                        "rpc_used": rpc["name"],
                        "success": True
                    }
                else:
                    result["contract_info"][func] = {
                        "value": str(value) if isinstance(value, (int, bytes)) else value,
                        "rpc_used": rpc["name"],
                        "success": True
                    }
                break
            else:
                if "execution reverted" not in str(error).lower():
                    if func == "getAnnouncedValidators":
                        result["all_announced_validators"] = {
                            "error": error,
                            "error_type": error_type,
                            "rpc_attempted": rpc["name"],
                            "success": False
                        }
                    else:
                        result["contract_info"][func] = {
                            "error": error,
                            "error_type": error_type,
                            "rpc_attempted": rpc["name"],
                            "success": False
                        }
    
    # Consulta getAnnouncedStorageLocations para TODOS os validators de uma vez
    print("Consultando storage locations para todos validators...", file=sys.stderr)
    validator_addresses = [Web3.to_checksum_address(v) for v in VALIDATORS]
    for rpc in RPCS:
        value, error, error_type = query_contract(rpc["url"], "getAnnouncedStorageLocations", validator_addresses)
        if value is not None:
            result["all_validators_storage_locations"] = {
                "value": [[loc for loc in validator_locs] if isinstance(validator_locs, (list, tuple)) else [str(validator_locs)] 
                          for validator_locs in value],
                "rpc_used": rpc["name"],
                "success": True
            }
            break
        else:
            result["all_validators_storage_locations"] = {
                "error": error,
                "error_type": error_type,
                "success": False
            }
    
    # Consulta individual para cada validator
    for i, validator in enumerate(VALIDATORS, 1):
        print(f"Consultando validator {i} individualmente...", file=sys.stderr)
        validator_addr = Web3.to_checksum_address(validator)
        validator_result = {
            "index": i,
            "address": validator,
            "checksum_address": validator_addr,
            "etherscan_url": f"https://sepolia.etherscan.io/address/{validator}",
            "storage_locations": []
        }
        
        # Busca storage locations deste validator no resultado coletivo
        if result.get("all_validators_storage_locations", {}).get("success"):
            all_locs = result["all_validators_storage_locations"]["value"]
            if i <= len(all_locs):
                validator_result["storage_locations"] = all_locs[i-1]
                validator_result["storage_locations_count"] = len(all_locs[i-1])
                validator_result["has_announcements"] = len(all_locs[i-1]) > 0
            else:
                validator_result["storage_locations"] = []
                validator_result["storage_locations_count"] = 0
                validator_result["has_announcements"] = False
        else:
            validator_result["storage_locations"] = []
            validator_result["storage_locations_count"] = 0
            validator_result["has_announcements"] = False
            validator_result["error"] = "Não foi possível consultar storage locations"
        
        result["validators"].append(validator_result)
    
    # Resumo
    summary = {
        "total_validators_consulted": len(VALIDATORS),
        "validators_with_announcements": sum(1 for v in result["validators"] if v.get("has_announcements", False)),
        "total_storage_locations": sum(v.get("storage_locations_count", 0) for v in result["validators"]),
        "all_announced_validators_count": result.get("all_announced_validators", {}).get("count", 0),
        "functions_consulted": [
            "localDomain",
            "mailbox",
            "getAnnouncedValidators",
            "getAnnouncedStorageLocations"
        ],
        "abi_functions": [
            {
                "name": "localDomain",
                "description": "Retorna o domain ID local (11155111 para Sepolia)",
                "inputs": [],
                "outputs": ["uint32"]
            },
            {
                "name": "mailbox",
                "description": "Retorna o endereço do contrato Mailbox",
                "inputs": [],
                "outputs": ["address"]
            },
            {
                "name": "getAnnouncedValidators",
                "description": "Retorna array de todos os endereços de validators que fizeram anúncios",
                "inputs": [],
                "outputs": ["address[]"]
            },
            {
                "name": "getAnnouncedStorageLocations",
                "description": "Retorna array de arrays de strings com os storage locations (S3 buckets) para cada validator",
                "inputs": ["address[] _validators"],
                "outputs": ["string[][]"]
            }
        ]
    }
    
    result["summary"] = summary
    
    # Output JSON
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
