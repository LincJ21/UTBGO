# 📖 Guía de Migración: Motor de Recomendaciones Gorse

Esta guía detalla los pasos necesarios para activar el motor de recomendaciones **Gorse** en el futuro, reemplazando el motor actual de Python (`custom_ml`).

---

## 🏗️ Paso 1: Infraestructura (Servidor Gorse)

Gorse es un servicio independiente que requiere su propia base de datos. Debes desplegarlo usando Docker o un servicio gestionado.

1.  **Desplegar Gorse:**
    Usa la imagen oficial de Docker: `gorseio/gorse-server`.
2.  **Base de Datos para Gorse:**
    Gorse necesita una base de datos para guardar sus modelos (MySQL, MariaDB o PostgreSQL). **No uses la misma base de datos de la app (`neondb`)** para evitar saturarla; crea una base de datos pequeña independiente.
3.  **Configuración (`config.toml`):**
    Configura las reglas de "ranking", "click-through rate" y las categorías (ej: "video").

---

## 🔑 Paso 2: Configuración del Entorno (`.env`)

En tu archivo `.env` principal en la raíz del proyecto, debes actualizar las credenciales que ya dejamos preparadas:

```env
# URL donde quedó desplegado tu servidor Gorse
GORSE_SERVER_URL=https://tu-servidor-gorse.com

# La Key que definiste en el archivo config.toml de Gorse
GORSE_API_KEY=tu_super_secret_gorse_key

# CAMBIO CRÍTICO: Activar el motor
PRIMARY_RECOMMENDATION_ENGINE=gorse
```

---

## 💻 Paso 3: Activación en el Código (Go API)

Debes realizar dos cambios pequeños en el archivo `api-service/main.go` para "despertar" el cliente que hoy está dormido.

1.  **Habilitar la variable global:**
    Busca la línea ~31 en `main.go` y descoméntala:
    ```go
    var Gorse *GorseClientWrapper
    ```

2.  **Habilitar la inicialización:**
    Busca la sección de `main()` (~273) y descoméntala:
    ```go
    Gorse = NewGorseClient(os.Getenv("GORSE_SERVER_URL"), os.Getenv("GORSE_API_KEY"))
    if Gorse != nil {
        Logger.Info("Cliente Gorse inicializado")
    }
    ```

---

## 🔄 Paso 4: Sincronización de Datos

Gorse necesita datos para aprender. Debes enviarle el historial:

1.  **Sincronización Inicial:** Ejecuta un script para cargar todos tus usuarios y videos actuales a Gorse usando los métodos `RegisterUser` y `RegisterItem` definidos en `api-service/gorse_client.go`.
2.  **Sincronización en Tiempo Real:** Asegúrate de que los Handlers de "Registro de Usuario" y "Upload de Video" llamen a Gorse para mantenerlo actualizado.

---

## 🧪 Paso 5: Verificación

Para confirmar que la migración fue exitosa:

1.  Reinicia el backend de Go.
2.  Busca en los logs el mensaje: `Cliente Gorse inicializado`.
3.  Entra a la app Flutter y verifica el Feed.

---

> [!NOTE]
> **¿Cuándo hacer esto?** Solo si superas los 100,000 usuarios y notas que el motor de Python se queda corto en precisión. Por ahora, el motor de Python es más eficiente y fácil de mantener.
