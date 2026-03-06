#  Guía de Ejecución Rápida: UTBGO

Esta guía explica cómo levantar todo el ecosistema de UTBGO de manera sencilla.

## 📌 Requisitos Previos
- **Go** (v1.21+)
- **Python** (v3.10+)
- **Flutter** (v3.16+)
- **Postgres (Neon)**: Asegúrate de tener el string de conexión en el archivo `.env` raíz.

---

##  Paso 1: Levantar el Backend Principal (Go)
1. Abre una terminal en `api-service/`.
2. Asegúrate de que el archivo `.env` esté bien configurado.
3. Ejecuta:
   ```powershell
   go run .
   ```
   *El backend correrá en el puerto **8080**.*

---

##  Paso 2: Levantar el Servicio de Tracking (Python)
Este servicio registra las interacciones (likes, vistas).
1. Abre una terminal en `tracking-service/`.
2. Activa el entorno virtual:
   ```powershell
   .\venv\Scripts\activate
   ```
3. Ejecuta el API:
   ```powershell
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8091
   ```
4. **En otra terminal**, ejecuta el worker (procesa los eventos en segundo plano):
   ```powershell
   python worker.py
   ```

---

##  Paso 3: Levantar el Servicio de Recomendaciones (Python)
Este servicio genera sugerencias basadas en el historial.
1. Abre una terminal en `recommendations-service/`.
2. Activa el entorno virtual:
   ```powershell
   .\venv\Scripts\activate
   ```
3. Ejecuta el API:
   ```powershell
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8090
   ```

---

##  Paso 4: Levantar el Frontend (Flutter)
1. Abre una terminal en la raíz del proyecto.
2. Asegúrate de tener un emulador abierto o dispositivo conectado.
3. Ejecuta:
   ```powershell
   flutter run
   ```

---

##  Verificación de Puertos
Si todo está bien, deberías tener ocupados estos puertos:
- **8080**: API Principal (Go)
- **8091**: Tracking API
- **8090**: Recommendation API

##  Prueba de Fuego (End-to-End)
Para confirmar que el "circuito" de datos funciona, ejecuta el script de prueba maestro desde la raíz:
```powershell
python verify_e2e.py
```
Si ves el mensaje `ÉXITO`, ¡todo el backend está perfectamente sincronizado!
