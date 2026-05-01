# 🚀 Guía de Migración: De Cuenta Estudiantil a Cuenta Personal Azure

Esta guía detalla los pasos exactos para abandonar el script local `desplegar.ps1` y activar el pipeline empresarial de GitHub Actions (`deploy.yml`) cuando adquieras una cuenta personal de Azure sin las restricciones de la universidad.

---

## 🛑 Paso 0: Preparativos
Antes de empezar, asegúrate de tener:
1. Tu nueva cuenta personal de Azure activa.
2. Una terminal en tu PC iniciada con la nueva cuenta:
   ```powershell
   az login
   az account set --subscription "<TU_NUEVA_SUBSCRIPTION_ID>"
   ```

---

## 🔑 Paso 1: Crear el "Usuario Bot" (Service Principal)
GitHub Actions necesita permisos para crear recursos en tu Azure sin pedirte contraseña. Esto se hace creando un Service Principal.

Ejecuta este comando en tu terminal:
```powershell
az ad sp create-for-rbac --name "github-actions-utbgo" --role contributor --scopes /subscriptions/<TU_NUEVA_SUBSCRIPTION_ID> --sdk-auth
```

El comando escupirá un texto en formato JSON. **Cópialo todo**. Se verá parecido a esto:
```json
{
  "clientId": "xxxxx-xxxx-xxxx-xxxx",
  "clientSecret": "xxxxx~xxxxxx",
  "subscriptionId": "xxxxx-xxxx-xxxx-xxxx",
  "tenantId": "xxxxx-xxxx-xxxx-xxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  // ...
}
```

---

## 🛡️ Paso 2: Configurar los Secretos en GitHub
Ve a tu repositorio en GitHub (en la web).
1. Navega a **Settings** > **Secrets and variables** > **Actions**.
2. Haz clic en **New repository secret**.
3. Crea un secreto llamado `AZURE_CREDENTIALS` y pega ahí **todo el JSON** que copiaste en el Paso 1.

Crea los siguientes secretos adicionales si tu pipeline (`deploy.yml`) los requiere explícitamente:
- `AZURE_CLIENT_ID` (sólo el valor de clientId del JSON)
- `AZURE_TENANT_ID` (sólo el valor de tenantId del JSON)
- `AZURE_SUBSCRIPTION_ID` (sólo el valor de subscriptionId del JSON)

> Importante: Nunca comitees estos IDs o secretos directamente en tu código. Siempre usa la pestaña de Secrets de GitHub.

---

## ☁️ Paso 3: Configurar el Estado Remoto de Terraform
Actualmente Terraform guarda su "memoria" (`terraform.tfstate`) en tu disco duro local. Como GitHub Actions corre en servidores en la nube diferentes cada vez, necesitas mover esa memoria a la nube.

1. Crea un Storage Account en Azure (puedes hacerlo desde el portal web o terminal).
2. Crea un contenedor dentro llamado `tfstate`.
3. Abre tu archivo `azure/terraform/backend.tf` (o créalo si no existe) y configúralo así:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-rg"      # RG de tu storage account
    storage_account_name = "utbgotfstate"      # Nombre de tu storage account
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
```

---

## 🤖 Paso 4: Activar GitHub Actions
1. Asegúrate de que el archivo `.github/workflows/deploy.yml` esté habilitado y configurado para dispararse al hacer push a la rama `main`.
2. Revisa que las variables de entorno de tu base de datos (PostgreSQL, Redis, Firebase) estén también configuradas como Secretos en GitHub para que Terraform pueda inyectarlas.

---

## ✈️ Paso 5: El Despliegue Mágico
¡Ya terminaste! Ahora el flujo de trabajo es el estándar de la industria. 

Para desplegar cualquier cambio nuevo en el código, simplemente abre tu terminal y escribe:

```powershell
git add .
git commit -m "Actualizacion para produccion"
git push origin main
```

> **Consejo:** Ve a la pestaña "Actions" en tu repositorio de GitHub. Verás cómo un servidor remoto de Microsoft se enciende, descarga tu código, hace el análisis de seguridad (CodeQL/SonarCloud), construye las imágenes Docker, aplica los cambios de Terraform y reinicia tus Contenedores en Azure. **Todo en 5 minutos y sin intervención humana.**
