## Arquitectura
El proyecto consiste en 4 componentes principales:
1. **Frontend (Flutter):** Aplicación móvil multiplataforma.
2. **Backend (Go + Gin):** API RESTful principal para manejar usuarios, contenido, y autenticación OIDC.
3. **Tracking Service (Python/FastAPI):** Microservicio para capturar métricas de uso y engagement en tiempo real.
4. **Recommendation Service (Python/FastAPI):** Motor de recomendación híbrido que usa IA (LightGBM) y caché dinámica.

## Tecnologías
- **App:** Flutter, Dart, Firebase Auth
- **Backend APIs:** Golang (Main), Python (Microservicios)
- **Base de Datos:** PostgreSQL (Neon)
- **Caché & Colas:** Redis (Upstash Cloud)
- **Almacenamiento:** Cloudinary

## Estructura del Código

```
📁 api-service/            # API Principal en Go
📁 tracking-service/        # Analíticas y Métricas (Python)
📁 recommendations-service/ # Motor de Recomendación ML (Python)
📁 lib/                    # Frontend Flutter
```

## Guía de Inicio Rápido

Para poner en marcha todo el ecosistema de UTBGO en unos minutos, sigue estos pasos:

### 1. Configuración del Entorno
El proyecto utiliza servicios Cloud (Neon, Upstash, Cloudinary). Debes configurar tus llaves:
1. Copia el archivo de ejemplo: `cp .env.example .env`
2. Edita `.env` y coloca tus credenciales reales.

### 2. Levantar el Backend (Ecosistema Microservicios)
Utilizamos Docker para que no tengas que instalar Go ni Python localmente:
```bash
docker-compose up -d --build
```
*Esto encenderá la API de Go (8080), el Tracking (8091) y el Motor de Recomendaciones (8090).*

### 3. Levantar el Frontend (Flutter)
1. Abre un emulador de Android o iOS.
2. Desde la raíz del proyecto, ejecuta:
```bash
flutter pub get
flutter run
```

---

## Arquitectura del Sistema
El sistema está diseñado bajo una arquitectura de microservicios moderna:
- **API Principal (Go):** Orquestador de peticiones, autenticación y lógica de negocio.
- **Tracking Service (Python):** Ingesta masiva de eventos (vistas, likes).
- **ML Recommendations (Python):** Generación de feeds personalizados.
- **Infraestructura Cloud:** Neon (PostgreSQL), Upstash (Redis), Cloudinary (Media).


