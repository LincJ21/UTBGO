# Script de Despliegue Local para UTBGO (Modo Híbrido)
# Resuelve el problema "Huevo y Gallina": Crea el registro primero, sube imágenes y luego crea las apps.

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 Iniciando Despliegue Local de UTBGO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Crear el Registro en Azure primero (ACR)
Write-Host "`n[1/5] Preparando infraestructura base (Creando Azure Registry)..." -ForegroundColor Yellow
Set-Location -Path "./azure/terraform"
terraform init
# Aplicamos SOLO el registro y el grupo de recursos para poder subir las imágenes
terraform apply -target="azurerm_resource_group.rg" -target="azurerm_container_registry.acr" -auto-approve
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al crear la infraestructura base." -ForegroundColor Red
    Set-Location -Path "../../"
    exit
}

# Obtener el nombre generado del registro desde Terraform
$ACR_LOGIN_SERVER = terraform output -raw acr_login_server
$ACR_NAME = $ACR_LOGIN_SERVER.Replace(".azurecr.io", "")
Set-Location -Path "../../"

Write-Host "✅ Registro creado: $ACR_LOGIN_SERVER" -ForegroundColor Green

# 2. Login a Azure ACR
Write-Host "`n[2/5] Iniciando sesión en el nuevo registro..." -ForegroundColor Yellow
az acr login --name $ACR_NAME
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al iniciar sesión en ACR. Asegúrate de ejecutar 'az login' primero." -ForegroundColor Red
    exit
}

# 3. Build de Imágenes
Write-Host "`n[3/5] Construyendo imágenes de Docker..." -ForegroundColor Yellow
Write-Host "-> Construyendo API..."
docker build -f ./Dockerfile -t $ACR_LOGIN_SERVER/utbgo-api:v3 .
Write-Host "-> Construyendo Tracking..."
docker build -t $ACR_LOGIN_SERVER/utbgo-tracking:v3 ./tracking-service
Write-Host "-> Construyendo Recomendaciones..."
docker build -t $ACR_LOGIN_SERVER/utbgo-recommendations:v3 ./recommendations-service
Write-Host "-> Construyendo Video Worker..."
docker build -t $ACR_LOGIN_SERVER/utbgo-video-worker:v3 ./video-worker-service

# 4. Push de Imágenes
Write-Host "`n[4/5] Subiendo imágenes a Azure Container Registry..." -ForegroundColor Yellow
docker push $ACR_LOGIN_SERVER/utbgo-api:v3
docker push $ACR_LOGIN_SERVER/utbgo-tracking:v3
docker push $ACR_LOGIN_SERVER/utbgo-recommendations:v3
docker push $ACR_LOGIN_SERVER/utbgo-video-worker:v3

# 5. Desplegar el resto (Container Apps)
Write-Host "`n[5/5] Desplegando Aplicaciones con Terraform..." -ForegroundColor Yellow
Set-Location -Path "./azure/terraform"
# Ahora aplicamos todo, inyectando dinámicamente las URLs exactas de las imágenes
terraform apply -auto-approve `
  -var="api_image=$ACR_LOGIN_SERVER/utbgo-api:v3" `
  -var="tracking_image=$ACR_LOGIN_SERVER/utbgo-tracking:v3" `
  -var="recommendations_image=$ACR_LOGIN_SERVER/utbgo-recommendations:v3" `
  -var="video_worker_image=$ACR_LOGIN_SERVER/utbgo-video-worker:v3"
Set-Location -Path "../../"

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "✅ ¡Despliegue Completado Exitosamente!" -ForegroundColor Green
Write-Host "Tus servicios están corriendo en Azure." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
