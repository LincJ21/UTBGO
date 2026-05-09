# ==============================================================================
# UTBGO — Despliegue Manual a Azure Virtual Machine
# ==============================================================================
# Uso: .\desplegar_vm.ps1
# Requisitos: az login, Terraform
#
# Este script levanta una Maquina Virtual en Azure usando Terraform.
# ==============================================================================

$ErrorActionPreference = "Stop"
$TF_DIR = "../azure/terraform/virtual-machine"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " UTBGO — Despliegue a Maquina Virtual" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# --- Paso 0: Verificar prerrequisitos ---
Write-Host "`n[0/3] Verificando prerrequisitos..." -ForegroundColor Yellow

$tools = @("az", "terraform")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$tool' no esta instalado o no esta en el PATH." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  az, terraform -> OK" -ForegroundColor Green

# Verificar login en Azure
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "ERROR: No estas logueado en Azure. Ejecuta 'az login' primero." -ForegroundColor Red
    exit 1
}
Write-Host "  Azure Account: $($account.name)" -ForegroundColor Green

# --- Paso 1: Terraform Init ---
Write-Host "`n[1/3] Inicializando Terraform..." -ForegroundColor Yellow
Push-Location $TF_DIR
terraform init -input=false
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "ERROR: terraform init fallo." -ForegroundColor Red
    exit 1
}
Write-Host "  Terraform inicializado -> OK" -ForegroundColor Green

# --- Paso 2: Terraform Apply ---
Write-Host "`n[2/3] Creando la Maquina Virtual en Azure..." -ForegroundColor Yellow
terraform apply -auto-approve -input=false
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "ERROR: Terraform apply fallo." -ForegroundColor Red
    exit 1
}

# Obtener IPs
$PUBLIC_IP = terraform output -raw public_ip_address 2>$null
Pop-Location

# --- Resultado Final ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " DESPLIEGUE A VM COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
if ($PUBLIC_IP) {
    Write-Host "  IP Publica de la VM:  $PUBLIC_IP" -ForegroundColor White
    Write-Host "  Para conectarte:      ssh azureuser@$PUBLIC_IP" -ForegroundColor DarkCyan
}
Write-Host ""
Write-Host "Recuerda que la VM tardara unos minutos en inicializar Docker y levantar los servicios." -ForegroundColor Yellow
Write-Host "Puedes revisar el progreso conectandote por SSH y viendo los logs de cloud-init." -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
