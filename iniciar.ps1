# Sobe o laboratório inteiro no Windows (PowerShell).
#
#   .\iniciar.ps1
#
# Abre uma janela do PowerShell para o backend (3 microsserviços) e outra para o frontend.
# Feche as janelas (ou use Ctrl+C em cada uma) para encerrar.
# Se a execução de scripts estiver bloqueada: Set-ExecutionPolicy -Scope Process Bypass

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js não encontrado. Instale a versão 22.15 ou superior." -ForegroundColor Red
    exit 1
}

# Portas livres?
$ocupadas = @()
foreach ($porta in 3000, 3001, 3002, 5173) {
    if (Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction SilentlyContinue) {
        $ocupadas += $porta
    }
}
if ($ocupadas.Count -gt 0) {
    Write-Host "As portas $($ocupadas -join ', ') já estão em uso por outro programa." -ForegroundColor Yellow
    Write-Host "Veja a seção 'Problemas comuns' no readme.md."
    exit 1
}

# Dependências
if (-not (Test-Path "backend\node_modules") -or -not (Test-Path "backend\api-gateway\node_modules") `
    -or -not (Test-Path "backend\produtos-service\node_modules") -or -not (Test-Path "backend\pedidos-service\node_modules")) {
    Write-Host ">> Instalando dependências do backend..."
    Push-Location backend
    npm install
    npm run install:all
    Pop-Location
}
if (-not (Test-Path "frontend\node_modules")) {
    Write-Host ">> Instalando dependências do frontend..."
    Push-Location frontend
    npm install
    Pop-Location
}

Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$PSScriptRoot\backend'; npm run dev"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$PSScriptRoot\frontend'; npm run dev"

Write-Host ""
Write-Host "  Frontend:     http://localhost:5173"
Write-Host "  API Gateway:  http://localhost:3000   (health: http://localhost:3000/health)"
