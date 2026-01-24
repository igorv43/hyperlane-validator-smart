# 🔄 Como Reiniciar o Docker

## 🪟 Windows (Docker Desktop)

### Método 1: Através da Interface do Docker Desktop

1. **Abrir Docker Desktop**
   - Clique no ícone do Docker na barra de tarefas (systray)
   - Ou abra o aplicativo Docker Desktop

2. **Reiniciar Docker**
   - Clique no ícone de **⚙️ Settings** (Configurações)
   - Vá em **Troubleshoot**
   - Clique em **Restart Docker Desktop**
   - Ou simplesmente: **Quit Docker Desktop** e abra novamente

3. **Verificar se está rodando**
   - O ícone do Docker na barra de tarefas deve ficar verde
   - Deve aparecer "Docker Desktop is running"

### Método 2: Via PowerShell (Como Administrador)

```powershell
# Parar Docker Desktop
Stop-Process -Name "Docker Desktop" -Force

# Aguardar alguns segundos
Start-Sleep -Seconds 5

# Iniciar Docker Desktop novamente
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

### Método 3: Reiniciar WSL (Recomendado se Docker não responde)

```powershell
# No PowerShell como Administrador
wsl --shutdown

# Aguardar alguns segundos
Start-Sleep -Seconds 5

# Abrir WSL novamente (isso reiniciará o Docker também)
```

---

## 🐧 Linux/WSL (Docker Engine)

### Método 1: Via systemd (se disponível)

```bash
# Parar Docker
sudo systemctl stop docker

# Iniciar Docker
sudo systemctl start docker

# Ou reiniciar diretamente
sudo systemctl restart docker

# Verificar status
sudo systemctl status docker
```

### Método 2: Via service (Ubuntu/Debian)

```bash
# Parar Docker
sudo service docker stop

# Iniciar Docker
sudo service docker start

# Ou reiniciar diretamente
sudo service docker restart

# Verificar status
sudo service docker status
```

### Método 3: Reiniciar WSL (Recomendado)

```bash
# No PowerShell do Windows (como administrador)
wsl --shutdown

# Depois, abra o WSL novamente
# O Docker será reiniciado automaticamente
```

---

## ✅ Verificar se Docker Está Rodando

Após reiniciar, verifique se o Docker está funcionando:

```bash
# Verificar se Docker está rodando
docker ps

# Se funcionar, o Docker está OK
# Se der erro, o Docker ainda não está pronto
```

---

## 🔧 Troubleshooting

### Se Docker não iniciar:

1. **Verificar se Docker Desktop está instalado**
   - Windows: Verificar se Docker Desktop está instalado
   - Linux: Verificar se docker está instalado: `which docker`

2. **Verificar logs do Docker**
   - Windows: Ver logs no Docker Desktop → Settings → Troubleshoot
   - Linux: `sudo journalctl -u docker.service`

3. **Reiniciar completamente**
   - Windows: Reiniciar o computador
   - Linux: `sudo reboot`

### Se Docker não conectar no WSL:

1. **Verificar WSL 2 Integration**
   - Docker Desktop → Settings → Resources → WSL Integration
   - Certifique-se de que sua distribuição WSL está marcada como "Enabled"
   - Clique em "Apply & Restart"

2. **Reiniciar WSL**
   ```powershell
   # No PowerShell como Administrador
   wsl --shutdown
   ```
   Depois, abra o WSL novamente.

---

## 📋 Comandos Rápidos

### Reiniciar Docker no WSL (Mais Comum)

```bash
# No PowerShell do Windows (como administrador)
wsl --shutdown

# Depois, abra o WSL novamente e verifique:
docker ps
```

### Reiniciar Docker Desktop (Windows)

1. Clique com botão direito no ícone do Docker na barra de tarefas
2. Clique em "Quit Docker Desktop"
3. Abra Docker Desktop novamente

---

## 🎯 Após Reiniciar

Depois de reiniciar o Docker, você pode executar o relayer:

```bash
cd /home/lunc/hyperlane-validator-smart/teste-relayer
docker compose -f docker-compose-relayer-only.yml up -d relayer
```
