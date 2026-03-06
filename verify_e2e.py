import os
import time
import requests
from dotenv import load_dotenv

# Try to import SQLAlchemy, but handle failure gracefully
try:
    from sqlalchemy import create_engine, text
except ImportError:
    print("❌ Error: 'sqlalchemy' no está instalada. Ejecuta: pip install sqlalchemy")
    exit(1)

# 1. Setup - Load environment and configuration
load_dotenv(override=True)
DB_URL = os.getenv("DATABASE_URL") or os.getenv("DB_CONNECTION_STRING")
if DB_URL:
    DB_URL = DB_URL.strip().strip("'").strip('"')

# URLs base deseadas
API_HOST = "http://localhost:8080"
TRACKING_HOST = "http://localhost:8091"
RECS_HOST = "http://localhost:8090"

TRACKING_KEY = os.getenv("TRACKING_API_KEY", "your-tracking-key")
RECS_KEY = os.getenv("RECOMMENDATIONS_API_KEY", "your-recs-key")

USER_ID = 777
CONTENT_ID = 101

def check_health():
    print("--- VERIFICANDO SALUD DE LOS SERVICIOS ---")
    services = {
        "Go API": f"{API_HOST}/health",
        "Tracking": f"{TRACKING_HOST}/api/v1/health",
        "Recommendations": f"{RECS_HOST}/api/v1/health"
    }
    
    all_ok = True
    for name, url in services.items():
        try:
            r = requests.get(url, timeout=5)
            if r.status_code == 200:
                print(f"✅ {name}: ONLINE")
            else:
                print(f"⚠️  {name}: {r.status_code} - {r.text}")
                all_ok = False
        except Exception as e:
            print(f"❌ {name}: OFFLINE ({str(e)})")
            all_ok = False
    return all_ok

def run_test():
    if not check_health():
        print("\n⚠️  Algunos servicios no responden. Asegúrate de que 'docker-compose up' esté corriendo sin errores.")

    print(f"\n--- INICIANDO PRUEBA END-TO-END (USER: {USER_ID}) ---")

    # STEP 1: Enviar evento de Trackeo (Simulando un LIKE)
    print("\n1. Enviando evento 'like' al Tracking Service...")
    track_url = f"{TRACKING_HOST}/api/v1/events"
    payload = {
        "user_id": USER_ID,
        "content_id": CONTENT_ID,
        "event_type": "like",
        "event_value": 1.0
    }
    headers = {"X-API-Key": TRACKING_KEY, "Content-Type": "application/json"}
    
    try:
        r = requests.post(track_url, json=payload, headers=headers)
        if r.status_code in [200, 202]:
            print(f"   ✅ ÉXITO: Evento aceptado (Status: {r.status_code})")
        else:
            print(f"   ❌ ERROR: {r.status_code}, Response: {r.text}")
            print(f"   URL intentada: {track_url}")
    except Exception as e:
        print(f"   ❌ FALLO TOTAL al conectar con Tracking: {str(e)}")

    # STEP 2: Verificar persistencia en Neon DB
    print("\n2. Verificando persistencia en Neon DB...")
    if not DB_URL:
        print("   ⚠️  DATABASE_URL no encontrada en .env, saltando verificación de DB.")
    else:
        try:
            # Note: psycopg2 is required by SQLAlchemy for PostgreSQL
            engine = create_engine(DB_URL)
            with engine.connect() as conn:
                event_count = conn.execute(
                    text("SELECT COUNT(*) FROM tracking_events WHERE user_id = :u AND content_id = :c"),
                    {"u": USER_ID, "c": CONTENT_ID}
                ).scalar()
                
                print(f"   Eventos encontrados en DB: {event_count}")
        except ImportError:
            print("   ❌ Error: 'psycopg2' no está instalado. Ejecuta: pip install psycopg2-binary")
        except Exception as e:
            print(f"   ❌ Error al conectar con Neon DB: {str(e)}")

    # STEP 3: Consultar Recomendaciones
    print("\n3. Solicitando recomendaciones personalizadas...")
    rec_url = f"{RECS_HOST}/api/v1/recommendations"
    rec_payload = {"user_id": USER_ID, "limit": 5}
    rec_headers = {"X-API-Key": RECS_KEY, "Content-Type": "application/json"}
    
    try:
        r_rec = requests.post(rec_url, json=rec_payload, headers=rec_headers)
        if r_rec.status_code == 200:
            recommendations = r_rec.json().get("recommendations", [])
            print(f"   ✅ Recomendaciones recibidas: {recommendations}")
        else:
            print(f"   ❌ ERROR en Recomendaciones: {r_rec.status_code} - {r_rec.text}")
    except Exception as e:
        print(f"   ❌ FALLO al conectar con Recommendations: {str(e)}")

if __name__ == "__main__":
    run_test()
