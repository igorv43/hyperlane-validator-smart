#!/usr/bin/env python3
"""
Obtém o endereço público do Solana usando solana-keygen ou método alternativo.
"""
import subprocess
import sys
import json
import os
from pathlib import Path

def get_key_from_env():
    """Obtém chave do .env"""
    env_file = Path(".env")
    if not env_file.exists():
        return None
    
    with open(env_file, 'r') as f:
        for line in f:
            if line.startswith("HYP_CHAINS_SOLANATESTNET_SIGNER_KEY="):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
                return key
    return None

def create_temp_keypair(hex_key):
    """Cria arquivo keypair temporário do formato Solana"""
    # Remover 0x
    hex_key = hex_key.replace("0x", "").replace(" ", "")
    
    if len(hex_key) != 64:
        return None
    
    # Converter hex para bytes
    private_key_bytes = bytes.fromhex(hex_key)
    
    # Para Solana, precisamos criar um keypair JSON
    # O formato é um array de 64 bytes: [32 bytes privados + 32 bytes públicos]
    # Mas só temos os privados, então precisamos derivar os públicos
    
    # Tentar usar solana-keygen para criar keypair a partir da seed
    temp_seed = "/tmp/solana_seed.txt"
    with open(temp_seed, 'wb') as f:
        f.write(private_key_bytes)
    
    # Tentar gerar keypair a partir da seed
    try:
        result = subprocess.run(
            ['solana-keygen', 'new', '--no-bip39-passphrase', '--force', '--outfile', '/tmp/solana_temp_keypair.json'],
            input=private_key_bytes,
            capture_output=True,
            timeout=5
        )
        
        if result.returncode == 0 and os.path.exists('/tmp/solana_temp_keypair.json'):
            # Ler e obter endereço
            with open('/tmp/solana_temp_keypair.json', 'r') as f:
                keypair = json.load(f)
            
            # Obter endereço público
            result = subprocess.run(
                ['solana-keygen', 'pubkey', '/tmp/solana_temp_keypair.json'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                address = result.stdout.strip()
                # Limpar arquivos temporários
                os.remove('/tmp/solana_temp_keypair.json')
                os.remove(temp_seed)
                return address
    except:
        pass
    
    # Limpar
    if os.path.exists(temp_seed):
        os.remove(temp_seed)
    if os.path.exists('/tmp/solana_temp_keypair.json'):
        os.remove('/tmp/solana_temp_keypair.json')
    
    return None

def main():
    hex_key = get_key_from_env()
    
    if not hex_key:
        print("Erro: Chave não encontrada no .env", file=sys.stderr)
        sys.exit(1)
    
    # Tentar método 1: criar keypair temporário
    address = create_temp_keypair(hex_key)
    
    if address:
        print(address)
        with open("/tmp/solana-relayer-address.txt", "w") as f:
            f.write(address)
        sys.exit(0)
    
    # Método 2: Usar solana-keygen recover
    print("Tentando método alternativo...", file=sys.stderr)
    
    # Criar arquivo com a chave privada em formato que solana-keygen aceita
    # Solana aceita seeds de 32 bytes
    hex_key_clean = hex_key.replace("0x", "").replace(" ", "")
    
    if len(hex_key_clean) == 64:
        # Tentar usar como seed
        try:
            # Escrever seed em arquivo
            seed_file = "/tmp/solana_seed_hex.txt"
            with open(seed_file, 'w') as f:
                f.write(hex_key_clean)
            
            # Tentar recuperar keypair
            result = subprocess.run(
                ['solana-keygen', 'recover', 'prompt://?full-path=/tmp/solana_seed_hex.txt', '--outfile', '/tmp/solana_recovered.json'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if os.path.exists('/tmp/solana_recovered.json'):
                result = subprocess.run(
                    ['solana-keygen', 'pubkey', '/tmp/solana_recovered.json'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    address = result.stdout.strip()
                    # Limpar
                    for f in [seed_file, '/tmp/solana_recovered.json']:
                        if os.path.exists(f):
                            os.remove(f)
                    print(address)
                    with open("/tmp/solana-relayer-address.txt", "w") as f:
                        f.write(address)
                    sys.exit(0)
        except:
            pass
    
    print("Erro: Não foi possível obter endereço. Use solana-keygen manualmente.", file=sys.stderr)
    print(f"Chave privada (hex): {hex_key[:20]}...", file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
    main()

