#!/usr/bin/env python3
"""
Script para verificar os últimos checkpoints dos validators Sepolia
Baseado nos buckets S3 anunciados no contrato ValidatorAnnounce

Uso:
    python3 scripts/check_validator_checkpoints.py [validator_announce_report.json]

Requisitos:
    - AWS CLI configurado (opcional, para acesso direto aos buckets)
    - Ou análise via logs do relayer
"""

import json
import sys
import subprocess
from datetime import datetime
from pathlib import Path

def parse_s3_path(s3_path):
    """Parse s3://bucket/region/folder into components"""
    if not s3_path.startswith('s3://'):
        return None
    
    parts = s3_path.replace('s3://', '').split('/')
    return {
        'bucket': parts[0],
        'region': parts[1] if len(parts) > 1 else 'us-east-1',
        'folder': '/'.join(parts[2:]) if len(parts) > 2 else '',
        'full_path': s3_path
    }

def check_s3_bucket(bucket, region, folder=''):
    """Tenta listar arquivos no bucket S3"""
    s3_path = f"s3://{bucket}/{region}/"
    if folder:
        s3_path += folder + "/"
    
    try:
        result = subprocess.run(
            ['aws', 's3', 'ls', s3_path, '--recursive', '--region', region],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0 and result.stdout.strip():
            lines = result.stdout.strip().split('\n')
            checkpoint_files = [l for l in lines if 'checkpoint' in l.lower() or '.json' in l.lower()]
            return {
                'success': True,
                'total_files': len(lines),
                'checkpoints': len(checkpoint_files),
                'last_checkpoint': checkpoint_files[-1] if checkpoint_files else None,
                'all_files': lines[-10:]  # Últimos 10 arquivos
            }
        elif 'AccessDenied' in result.stderr:
            return {
                'success': False,
                'error': 'AccessDenied',
                'message': 'Bucket privado - sem permissão de acesso'
            }
        else:
            return {
                'success': False,
                'error': 'Empty',
                'message': 'Bucket vazio ou sem arquivos'
            }
    except FileNotFoundError:
        return {
            'success': False,
            'error': 'AWS_CLI_NOT_FOUND',
            'message': 'AWS CLI não instalado'
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(type(e).__name__),
            'message': str(e)
        }

def main():
    # Lê o arquivo JSON
    json_file = sys.argv[1] if len(sys.argv) > 1 else 'validator_announce_complete_report.json'
    
    if not Path(json_file).exists():
        print(f"❌ Arquivo não encontrado: {json_file}")
        print("Execute primeiro: python3 scripts/query_validator_announce.py > validator_announce_report.json")
        sys.exit(1)
    
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    print("=" * 70)
    print("📦 VERIFICAÇÃO DE CHECKPOINTS - VALIDATORS SEPOLIA")
    print("=" * 70)
    print(f"Arquivo: {json_file}")
    print(f"Timestamp: {data.get('timestamp', 'N/A')}")
    print("")
    
    # Extrai informações dos validators
    validators_info = []
    for validator in data.get('validators', []):
        validator_addr = validator.get('address', 'unknown')
        storage_locs = validator.get('storage_locations', [])
        
        for loc in storage_locs:
            if loc.startswith('s3://'):
                s3_info = parse_s3_path(loc)
                if s3_info:
                    validators_info.append({
                        'validator': validator_addr,
                        **s3_info
                    })
    
    if not validators_info:
        print("⚠️  Nenhum bucket S3 encontrado no relatório")
        sys.exit(0)
    
    print(f"Total de validators com buckets S3: {len(validators_info)}")
    print("")
    
    results = []
    for i, info in enumerate(validators_info, 1):
        print(f"Validator {i}: {info['validator'][:20]}...")
        print(f"  Bucket: {info['bucket']}")
        print(f"  Region: {info['region']}")
        print(f"  Path: {info['full_path']}")
        
        # Verifica bucket
        check_result = check_s3_bucket(info['bucket'], info['region'], info['folder'])
        
        if check_result.get('success'):
            print(f"  ✅ Arquivos encontrados: {check_result['total_files']}")
            print(f"  📄 Checkpoints: {check_result['checkpoints']}")
            if check_result.get('last_checkpoint'):
                print(f"  📅 Último checkpoint:")
                print(f"     {check_result['last_checkpoint']}")
        else:
            error_type = check_result.get('error', 'Unknown')
            message = check_result.get('message', '')
            if error_type == 'AccessDenied':
                print(f"  🔒 {message}")
            else:
                print(f"  ⚠️  {message}")
        
        results.append({
            'validator': info['validator'],
            'bucket': info['bucket'],
            **check_result
        })
        print("")
    
    # Resumo
    print("=" * 70)
    print("📊 RESUMO")
    print("=" * 70)
    
    accessible = sum(1 for r in results if r.get('success'))
    with_checkpoints = sum(1 for r in results if r.get('checkpoints', 0) > 0)
    
    print(f"Validators com acesso ao bucket: {accessible}/{len(results)}")
    print(f"Validators com checkpoints: {with_checkpoints}/{len(results)}")
    print("")
    
    if accessible == 0:
        print("💡 NOTA:")
        print("Os buckets são privados e pertencem a outros validators.")
        print("Para verificar checkpoints, você pode:")
        print("1. Verificar logs do relayer:")
        print("   docker logs hpl-relayer-testnet 2>&1 | grep -i checkpoint")
        print("2. Verificar métricas do relayer:")
        print("   curl http://localhost:9112/metrics | grep checkpoint")
        print("3. Verificar se o relayer consegue buscar checkpoints:")
        print("   docker logs hpl-relayer-testnet 2>&1 | grep -i 'Unable to reach quorum'")
    
    print("=" * 70)
    
    # Salva resultado em JSON
    output_file = 'validator_checkpoints_check.json'
    with open(output_file, 'w') as f:
        json.dump({
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'validators': results,
            'summary': {
                'total': len(results),
                'accessible': accessible,
                'with_checkpoints': with_checkpoints
            }
        }, f, indent=2)
    
    print(f"✅ Resultado salvo em: {output_file}")

if __name__ == "__main__":
    main()
