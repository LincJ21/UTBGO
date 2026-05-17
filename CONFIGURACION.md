# UTBGO — Guía de Configuración de Credenciales

> **Propósito:** Esta guía explica paso a paso qué cuentas externas necesitas crear, qué credenciales debes obtener y cómo colocarlas en cada archivo `.env` para que el proyecto UTBGO funcione correctamente en tu entorno local o de producción.

---

## Resumen rápido

El proyecto UTBGO está compuesto por **3 servicios backend**, cada uno con su propio archivo de configuración:

| Servicio | Carpeta | Archivo a crear |
|---|---|---|
| API principal (Go/Gin) | `api-service/` | `api-service/.env` |
| Recomendaciones (Python) | `recommendations-service/` | `recommendations-service/.env` |
| Tracking de actividad (Python) | `tracking-service/` | `tracking-service/.env` |

Antes de cualquier otra cosa, copia los archivos de ejemplo:

```bash
cp api-service/.env.example            api-service/.env
cp recommendations-service/.env.example recommendations-service/.env
cp tracking-service/.env.example        tracking-service/.env
```

> **IMPORTANTE:** Los archivos `.env` ya están en el `.gitignore`. Nunca los subas al repositorio porque contienen contraseñas y claves privadas.

---

## Servicio 1 — `api-service/.env` (Go/Gin)

Este es el backend principal. Necesita las credenciales de todos los servicios externos.

---

### Sección 1: Servidor

No requieren cuentas externas. Solo configura los valores según tu entorno.

| Variable | Valor para desarrollo | Descripción |
|---|---|---|
| `PORT` | `8080` | Puerto donde escucha el servidor |
| `GIN_MODE` | `debug` | Usa `release` en producción |
| `JWT_SECRET_KEY` | *(genera una clave)* | Clave secreta para los tokens JWT |
| `ALLOWED_ORIGINS` | `http://localhost:3000` | Orígenes permitidos para CORS |

**Cómo generar la clave JWT:**
```bash
openssl rand -hex 32
```
Copia el resultado y pégalo en `JWT_SECRET_KEY`.

---

### Sección 2: Base de datos — PostgreSQL

**Cuenta necesaria:** Neon.tech (recomendado) o PostgreSQL local con Docker.

#### Opción A — Neon.tech (gratuito, cloud)

1. Ve a **https://neon.tech** y crea una cuenta gratuita.
2. Crea un nuevo **proyecto**.
3. En el panel del proyecto, ve a **"Connection Details"**.
4. Copia la **"Connection string"**. Tiene este formato:
   ```
   postgres://usuario:contraseña@hostname/base_de_datos?sslmode=require
   ```
5. Pégala en las variables:

| Variable | Dónde colocar |
|---|---|
| `DB_CONNECTION_STRING` | La cadena de conexión completa de Neon |
| `DATABASE_URL` | La misma cadena de conexión (es un alias) |

#### Opción B — PostgreSQL local con Docker

```bash
docker-compose up -d postgres
# Usa: postgres://postgres:postgres@localhost:5432/utbgo
```

---

### Sección 3: Caché y rate-limiting — Redis

**Cuenta necesaria:** Upstash (recomendado) o Redis local con Docker.

#### Opción A — Upstash Redis (gratuito, cloud)

1. Ve a **https://upstash.com** y crea una cuenta gratuita.
2. Crea una nueva **base de datos Redis** y selecciona la región más cercana.
3. En el panel, copia la **"Redis URL"**. Tiene este formato:
   ```
   rediss://default:contraseña@hostname:puerto
   ```
4. Pégala en `REDIS_URL`.

#### Opción B — Redis local con Docker

```bash
docker-compose up -d redis
# Usa: redis://localhost:6379
```

---

### Sección 4: Almacenamiento de multimedia — Cloudinary

**Cuenta necesaria:** Cloudinary (plan gratuito disponible).

1. Ve a **https://cloudinary.com** y crea una cuenta gratuita.
2. Una vez dentro, ve al **Dashboard** (página de inicio).
3. Busca el cuadro **"API Environment variable"**. Tiene este formato:
   ```
   CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name
   ```
4. Copia **solo el valor** (la parte después del `=`) y pégalo en:

| Variable | Dónde colocar |
|---|---|
| `STORAGE_PROVIDER` | Déjalo como `cloudinary` |
| `CLOUDINARY_URL` | El valor `cloudinary://...` del dashboard |

---

### Sección 5: Claves internas de microservicios

Estas claves **no requieren cuentas externas**. Son contraseñas que tú mismo inventas para que los servicios se comuniquen entre sí de forma segura.

**Regla:** El valor que pongas en `api-service/.env` debe ser **exactamente igual** al valor en el servicio correspondiente.

| Variable en `api-service/.env` | Variable equivalente | Archivo donde debe coincidir |
|---|---|---|
| `TRACKING_API_KEY` | `API_KEY` | `tracking-service/.env` |
| `RECOMMENDATIONS_API_KEY` | `API_KEY` | `recommendations-service/.env` |

**Ejemplo:**
```dotenv
# En api-service/.env
TRACKING_API_KEY=mi_clave_super_secreta_123

# En tracking-service/.env  <- debe ser IGUAL
API_KEY=mi_clave_super_secreta_123
```

Genera claves seguras con:
```bash
openssl rand -hex 24
```

---

### Sección 6: Autenticación Google / Firebase

Esta sección requiere configurar **2 servicios de Google**. Son los más importantes del proyecto porque gestionan el login de los usuarios institucionales.

#### Paso 1 — Crear proyecto en Firebase

1. Ve a **https://console.firebase.google.com** → **"Agregar proyecto"**.
2. Ingresa un nombre (ej: `utbgo-dev`) y completa el asistente.
3. En Configuración del proyecto (engranaje) → pestaña **"General"** → copia el **"ID del proyecto"**.
4. Colócalo en `FIREBASE_PROJECT_ID`.

#### Paso 2 — Activar login con Google en Firebase

1. **Build** → **Authentication** → **"Sign-in method"**.
2. Activa el proveedor **"Google"** y guarda.

#### Paso 3 — Obtener el Google Client ID

1. Ve a **https://console.cloud.google.com** (mismo proyecto de Firebase).
2. **APIs y servicios** → **Credenciales** → **"+ CREAR CREDENCIALES"** → **"ID de cliente de OAuth 2.0"**.
3. Tipo de aplicación: **Aplicación web**.
4. En **"Orígenes autorizados de JavaScript"** agrega:
   - `http://localhost:3000` (desarrollo)
   - `http://localhost:5173` (desarrollo con Vite)
   - La URL de producción si ya tienes una (ej: `https://app.utbgo.edu.co`)
5. Haz clic en **"Crear"** y copia el **"ID de cliente"** (termina en `.apps.googleusercontent.com`).

| Variable | Dónde colocar |
|---|---|
| `GOOGLE_CLIENT_ID` | El ID de cliente OAuth 2.0 |
| `INSTITUTIONAL_DOMAIN` | `utb.edu.co` (dominio institucional permitido) |
| `ADMIN_DOMAIN` | `admin.utb.edu.co` (dominio del panel de administración) |

#### Paso 4 — Descargar credencial de cuenta de servicio

El servidor Go necesita un archivo JSON para verificar tokens de Firebase.

1. Firebase → Configuración del proyecto → **"Cuentas de servicio"** → **"Generar nueva clave privada"**.
2. Renombra el `.json` descargado a `firebase-service-account.json`.
3. Muévelo a la carpeta `api-service/`:
   ```
   api-service/firebase-service-account.json
   ```

> Este archivo ya está en el `.gitignore`, nunca se subirá al repositorio accidentalmente.

---

## Servicio 2 — `recommendations-service/.env` (Python)

| Variable | Descripción | Requiere cuenta |
|---|---|---|
| `PORT` | Puerto del servicio (por defecto `8090`) | No |
| `API_KEY` | Debe coincidir con `RECOMMENDATIONS_API_KEY` del api-service | No (la inventas tú) |
| `DATABASE_URL` | Cadena de conexión PostgreSQL | Neon.tech o Docker |
| `REDIS_URL` | URL de Redis | Upstash o Docker |
| `RECOMMENDATION_COUNT` | Cantidad de recomendaciones a generar (ej: `10`) | No |
| `MIN_INTERACTIONS` | Interacciones mínimas para el modelo ML (ej: `3`) | No |
| `LOG_LEVEL` | Nivel de logs: `DEBUG`, `INFO`, `WARNING`, `ERROR` | No |

---

## Servicio 3 — `tracking-service/.env` (Python)

Después de configurar el `.env`, ejecuta las migraciones:

```bash
cd tracking-service && python migrate.py
```

| Variable | Descripción | Requiere cuenta |
|---|---|---|
| `PORT` | Puerto del servicio (por defecto `8091`) | No |
| `API_KEY` | Debe coincidir con `TRACKING_API_KEY` del api-service | No (la inventas tú) |
| `DATABASE_URL` | Cadena de conexión PostgreSQL | Neon.tech o Docker |
| `REDIS_URL` | URL de Redis | Upstash o Docker |
| `BATCH_SIZE` | Eventos por ciclo del worker (ej: `100`) | No |
| `WORKER_INTERVAL_SECONDS` | Segundos entre ciclos (ej: `5`) | No |
| `LOG_LEVEL` | Nivel de logs: `DEBUG`, `INFO`, `WARNING`, `ERROR` | No |

---

## Resumen de cuentas necesarias

| Servicio externo | Plan gratuito | Para qué se usa | Variables afectadas |
|---|---|---|---|
| **Neon.tech** | Si | Base de datos PostgreSQL en la nube | `DB_CONNECTION_STRING`, `DATABASE_URL` (en los 3 servicios) |
| **Upstash Redis** | Si | Caché y rate-limiting | `REDIS_URL` (en los 3 servicios) |
| **Cloudinary** | Si | Subida y almacenamiento de imágenes/videos | `CLOUDINARY_URL`, `STORAGE_PROVIDER` |
| **Firebase** | Si | Autenticación de usuarios con Google | `FIREBASE_PROJECT_ID` + archivo `firebase-service-account.json` |
| **Google Cloud** | Si (OAuth es gratis) | Login con cuenta Google institucional | `GOOGLE_CLIENT_ID` |

---

## Checklist final antes de ejecutar

- [ ] `api-service/.env` existe y tiene todas las variables rellenas
- [ ] `recommendations-service/.env` existe con `API_KEY`, `DATABASE_URL` y `REDIS_URL`
- [ ] `tracking-service/.env` existe con `API_KEY`, `DATABASE_URL` y `REDIS_URL`
- [ ] `api-service/firebase-service-account.json` existe (descargado de Firebase)
- [ ] Los valores de `TRACKING_API_KEY` y `API_KEY` del tracking-service son **iguales**
- [ ] Los valores de `RECOMMENDATIONS_API_KEY` y `API_KEY` del recommendations-service son **iguales**
- [ ] Las migraciones fueron ejecutadas: `python tracking-service/migrate.py`

Una vez todo listo:
```bash
docker-compose up --build
```
