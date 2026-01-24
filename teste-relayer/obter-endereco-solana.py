#!/usr/bin/env python3
"""
Obtém o endereço público do Solana a partir de uma chave privada em formato hex.
"""
import sys
import base58

def hex_to_solana_address(private_key_hex):
    """Converte chave privada hex para endereço público Solana."""
    try:
        # Remover 0x se presente
        private_key_hex = private_key_hex.replace("0x", "").replace(" ", "")
        
        # Verificar comprimento (deve ser 64 caracteres hex = 32 bytes)
        if len(private_key_hex) != 64:
            print(f"Erro: Chave deve ter 64 caracteres hex (32 bytes), tem {len(private_key_hex)}", file=sys.stderr)
            return None
        
        # Converter hex para bytes
        private_key_bytes = bytes.fromhex(private_key_hex)
        
        # Para Solana/ED25519, precisamos derivar a chave pública da privada
        # Usar a biblioteca ed25519 se disponível
        try:
            import ed25519
            # Criar chave de assinatura a partir da chave privada
            signing_key = ed25519.SigningKey(private_key_bytes)
            public_key_bytes = signing_key.get_verifying_key().to_bytes()
        except ImportError:
            # Se ed25519 não estiver disponível, tentar usar PyNaCl
            try:
                from nacl.signing import SigningKey
                signing_key = SigningKey(private_key_bytes)
                public_key_bytes = bytes(signing_key.verify_key)
            except ImportError:
                # Se nenhuma biblioteca estiver disponível, usar método alternativo
                # Para ED25519, a chave pública pode ser derivada, mas requer biblioteca
                print("Erro: Biblioteca ed25519 ou PyNaCl necessária", file=sys.stderr)
                print("Instale com: pip install ed25519 ou pip install pynacl", file=sys.stderr)
                return None
        
        # Codificar chave pública em base58 (formato Solana)
        address = base58.b58encode(public_key_bytes).decode('utf-8')
        return address
        
    except Exception as e:
        print(f"Erro ao converter chave: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Ler do .env se não fornecido
        import os
        from pathlib import Path
        
        env_file = Path(".env")
        if env_file.exists():
            with open(env_file, 'r') as f:
                for line in f:
                    if line.startswith("HYP_CHAINS_SOLANATESTNET_SIGNER_KEY="):
                        private_key = line.split("=", 1)[1].strip().strip('"').strip("'")
                        break
                else:
                    print("Erro: HYP_CHAINS_SOLANATESTNET_SIGNER_KEY não encontrada no .env", file=sys.stderr)
                    sys.exit(1)
        else:
            print("Uso: python3 obter-endereco-solana.py <chave_privada_hex>", file=sys.stderr)
            sys.exit(1)
    else:
        private_key = sys.argv[1]
    
    address = hex_to_solana_address(private_key)
    if address:
        print(address)
        # Salvar em arquivo temporário
        with open("/tmp/solana-relayer-address.txt", "w") as f:
            f.write(address)
    else:
        sys.exit(1)

