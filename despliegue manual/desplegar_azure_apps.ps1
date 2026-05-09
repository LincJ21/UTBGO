# ==============================================================================
# UTBGO — Despliegue Manual a Azure Container Apps
# ==============================================================================

$ErrorActionPreference = 'Stop'
$TF_DIR = '../azure/terraform/container-apps'
$VERSION = 'v' + (Get-Date -Format 'yyyyMMdd-HHmm')

Write-Host ''
Write-Host '=========================================='
Write-Host ' UTBGO — Despliegue Manual a Azure'
Write-Host " Version: $VERSION"
Write-Host '=========================================='

# --- Paso 0: Verificar prerrequisitos ---
Write-Host '[0/6] Verificando prerrequisitos...'

$tools = @('az', 'docker', 'terraform')
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $tool no esta instalado."
        exit 1
    }
}

# --- Paso 1: Terraform Init ---
Write-Host '[1/6] Inicializando Terraform...'
Push-Location $TF_DIR
terraform init -input=false
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host 'ERROR: terraform init fallo.'
    exit 1
}

# --- Paso 2: Crear ACR ---
Write-Host '[2/6] Creando infraestructura base...'
terraform apply -target='azurerm_resource_group.rg' -target='azurerm_container_registry.acr' -auto-approve -input=false
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host 'ERROR: No se pudo crear la infraestructura base.'
    exit 1
}

$ACR_LOGIN_SERVER = terraform output -raw acr_login_server
$ACR_NAME = $ACR_LOGIN_SERVER.Replace('.azurecr.io', '')
Pop-Location

# --- Paso 3: Login en ACR ---
Write-Host '[3/6] Autenticandose en ACR...'
az acr login --name $ACR_NAME

# --- Paso 4: Build de imagenes ---
Write-Host '[4/6] Construyendo imagenes Docker...'

$images = @(
    @{ Name = 'API'; File = '../Dockerfile'; Context = '..'; Tag = "$ACR_LOGIN_SERVER/utbgo-api:$VERSION" },
    @{ Name = 'Tracking'; File = '../tracking-service/Dockerfile'; Context = '../tracking-service'; Tag = "$ACR_LOGIN_SERVER/utbgo-tracking:$VERSION" },
    @{ Name = 'Recommendations'; File = '../recommendations-service/Dockerfile'; Context = '../recommendations-service'; Tag = "$ACR_LOGIN_SERVER/utbgo-recommendations:$VERSION" },
    @{ Name = 'Video Worker'; File = '../video-worker-service/Dockerfile'; Context = '../video-worker-service'; Tag = "$ACR_LOGIN_SERVER/utbgo-video-worker:$VERSION" }
)

foreach ($img in $images) {
    Write-Host "Construyendo $($img.Name)..."
    docker build -f $img.File -t $img.Tag $img.Context
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Paso 5: Push de imagenes ---
Write-Host '[5/6] Subiendo imagenes...'
foreach ($img in $images) {
    docker push $img.Tag
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Paso 6: Terraform Apply completo ---
Write-Host '[6/6] Desplegando en Azure...'
Push-Location $TF_DIR
terraform apply -auto-approve -input=false `
    -var="api_image=$ACR_LOGIN_SERVER/utbgo-api:$VERSION" `
    -var="tracking_image=$ACR_LOGIN_SERVER/utbgo-tracking:$VERSION" `
    -var="recommendations_image=$ACR_LOGIN_SERVER/utbgo-recommendations:$VERSION" `
    -var="video_worker_image=$ACR_LOGIN_SERVER/utbgo-video-worker:$VERSION"

$API_URL = terraform output -raw api_url 2>$null
Pop-Location

Write-Host '=========================================='
Write-Host ' DESPLIEGUE COMPLETADO EXITOSAMENTE'
Write-Host " URL: $API_URL"
Write-Host '=========================================='
