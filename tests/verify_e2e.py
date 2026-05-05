# -*- coding: utf-8 -*-
"""
=============================================================================
 UTBGO — Pruebas End-to-End (E2E)
=============================================================================
 Ejecuta los flujos críticos del producto para verificar que todos los
 microservicios, la base de datos y la API principal funcionan correctamente
 de forma integrada.

 Uso:
   python verify_e2e.py

 Requisitos:
   pip install requests python-dotenv sqlalchemy psycopg2-binary
=============================================================================
"""

import os
import sys
import time
import uuid

# Forzar UTF-8 en la consola de Windows (evita UnicodeEncodeError con cp1252)
if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
import requests
from dotenv import load_dotenv

try:
    from sqlalchemy import create_engine, text
except ImportError:
    print("❌ Error: 'sqlalchemy' no está instalada. Ejecuta: pip install sqlalchemy psycopg2-binary")
    sys.exit(1)

# =============================================================================
# Configuración
# =============================================================================
# Intentar cargar .env desde el directorio raíz (padre de /tests)
env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
if os.path.exists(env_path):
    load_dotenv(env_path, override=True)
else:
    load_dotenv(override=True)

API_HOST = "http://localhost:8080"
TRACKING_HOST = "http://localhost:8091"
RECS_HOST = "http://localhost:8090"

DB_URL = os.getenv("DATABASE_URL") or os.getenv("DB_CONNECTION_STRING")
if DB_URL:
    DB_URL = DB_URL.strip().strip("'").strip('"')

TRACKING_KEY = os.getenv("TRACKING_API_KEY", "your-tracking-key")
RECS_KEY = os.getenv("RECOMMENDATIONS_API_KEY", "your-recs-key")

# Datos del usuario de prueba E2E (se genera un email único por ejecución)
TEST_EMAIL = f"e2e_test_{uuid.uuid4().hex[:8]}@test.utbgo.com"
TEST_PASSWORD = "E2eTest2026!"
TEST_NAME = "E2E"
TEST_LAST_NAME = "TestUser"

# Contadores globales de resultados
_results = {"passed": 0, "failed": 0, "skipped": 0}


# =============================================================================
# Utilidades
# =============================================================================
def _log_pass(msg: str):
    _results["passed"] += 1
    print(f"   [OK] {msg}")


def _log_fail(msg: str):
    _results["failed"] += 1
    print(f"   [FAIL] {msg}")


def _log_skip(msg: str):
    _results["skipped"] += 1
    print(f"   [SKIP] {msg}")


def _log_info(msg: str):
    print(f"   [INFO] {msg}")


def _section(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def _step(number: int, description: str):
    print(f"\n  PASO {number}: {description}")
    print(f"  {'-'*50}")


# =============================================================================
# SUITE 1: Verificación de Salud de Microservicios
# =============================================================================
def suite_health_check():
    _section("SUITE 1: VERIFICACIÓN DE SALUD DE MICROSERVICIOS")

    services = {
        "Go API (Core)": {"url": f"{API_HOST}/health", "headers": {}},
        "Tracking Service": {"url": f"{TRACKING_HOST}/api/v1/health", "headers": {"X-API-Key": TRACKING_KEY}},
        "Recommendations Service": {"url": f"{RECS_HOST}/api/v1/health", "headers": {"X-API-Key": RECS_KEY}},
    }

    all_ok = True
    for name, cfg in services.items():
        try:
            r = requests.get(cfg["url"], headers=cfg["headers"], timeout=5)
            if r.status_code == 200:
                _log_pass(f"{name}: ONLINE")
            else:
                _log_fail(f"{name}: HTTP {r.status_code} — {r.text[:100]}")
                all_ok = False
        except requests.ConnectionError:
            _log_fail(f"{name}: OFFLINE (sin conexión)")
            all_ok = False
        except Exception as e:
            _log_fail(f"{name}: ERROR ({e})")
            all_ok = False

    return all_ok


# =============================================================================
# SUITE 2: Flujo Crítico — Registro → Búsqueda → Favorito → Perfil
# =============================================================================
def suite_critical_flow():
    _section("SUITE 2: FLUJO CRÍTICO DE USUARIO")
    print(f"  Usuario de prueba: {TEST_EMAIL}")

    access_token = None
    bookmarked_video_id = None

    # ── PASO 1: Registro de usuario ──────────────────────────────────────
    _step(1, "Registro de usuario nuevo")
    try:
        r = requests.post(f"{API_HOST}/api/v1/auth/register", json={
            "email": TEST_EMAIL,
            "password": TEST_PASSWORD,
            "name": TEST_NAME,
            "last_name": TEST_LAST_NAME,
        }, timeout=10)

        if r.status_code == 201:
            data = r.json()
            access_token = data.get("access_token")
            if access_token:
                _log_pass(f"Usuario registrado exitosamente (HTTP 201)")
            else:
                _log_fail(f"Registro exitoso pero no se recibió token: {data}")
                return
        elif r.status_code == 409:
            _log_info("Email ya registrado, intentando login...")
            # Fallback a login
            r2 = requests.post(f"{API_HOST}/api/v1/auth/login", json={
                "email": TEST_EMAIL,
                "password": TEST_PASSWORD,
            }, timeout=10)
            if r2.status_code == 200:
                data = r2.json()
                access_token = data.get("access_token")
                if access_token:
                    _log_pass(f"Login exitoso como fallback (HTTP 200)")
                else:
                    _log_fail(f"Login exitoso pero sin token: {data}")
                    return
            else:
                _log_fail(f"Login fallback falló: HTTP {r2.status_code} — {r2.text[:100]}")
                return
        else:
            _log_fail(f"Registro falló: HTTP {r.status_code} — {r.text[:200]}")
            return
    except Exception as e:
        _log_fail(f"Error de conexión en registro: {e}")
        return

    auth_headers = {"Authorization": f"Bearer {access_token}"}

    # ── PASO 2: Búsqueda de videos ───────────────────────────────────────
    _step(2, "Búsqueda de videos con filtro de texto")
    search_results = []
    try:
        # Buscar con un término genérico que probablemente tenga resultados
        for query in ["a", "espacio", "universidad", "tutorial"]:
            r = requests.get(
                f"{API_HOST}/api/v1/videos/search",
                params={"q": query},
                timeout=10,
            )
            if r.status_code == 200:
                data = r.json()
                videos = data.get("videos", [])
                if videos:
                    search_results = videos
                    _log_pass(f"Búsqueda '{query}' devolvió {len(videos)} resultado(s)")
                    break
                else:
                    _log_info(f"Búsqueda '{query}' sin resultados, probando siguiente...")
            else:
                _log_fail(f"Búsqueda '{query}' falló: HTTP {r.status_code}")

        if not search_results:
            # Fallback: intentar obtener del feed
            _log_info("Sin resultados de búsqueda, obteniendo video del feed...")
            r = requests.get(
                f"{API_HOST}/api/v1/videos/feed",
                params={"page": 1},
                headers=auth_headers,
                timeout=10,
            )
            if r.status_code == 200:
                feed_data = r.json()
                feed_videos = feed_data.get("videos", [])
                if feed_videos:
                    search_results = feed_videos
                    _log_pass(f"Feed devolvió {len(feed_videos)} video(s) como fallback")
                else:
                    _log_fail("Feed vacío. No hay contenido para probar.")
                    return
            else:
                _log_fail(f"Feed falló: HTTP {r.status_code}")
                return

    except Exception as e:
        _log_fail(f"Error en búsqueda: {e}")
        return

    # Seleccionar el primer video para marcar como favorito
    target_video = search_results[0]
    bookmarked_video_id = target_video.get("id")
    _log_info(f"Video seleccionado para favorito: ID={bookmarked_video_id} — \"{target_video.get('title', 'Sin título')}\"")

    # ── PASO 3: Marcar video como favorito ───────────────────────────────
    _step(3, "Guardar video en favoritos (bookmark)")
    try:
        r = requests.post(
            f"{API_HOST}/api/v1/videos/{bookmarked_video_id}/bookmark",
            headers=auth_headers,
            timeout=10,
        )

        if r.status_code == 200:
            data = r.json()
            is_bookmarked = data.get("is_bookmarked")
            if is_bookmarked is True:
                _log_pass(f"Video {bookmarked_video_id} marcado como favorito")
            elif is_bookmarked is False:
                # Si ya estaba guardado, el toggle lo quitó. Volvemos a togglear.
                _log_info("Video ya estaba guardado, re-toggling...")
                r2 = requests.post(
                    f"{API_HOST}/api/v1/videos/{bookmarked_video_id}/bookmark",
                    headers=auth_headers,
                    timeout=10,
                )
                if r2.status_code == 200 and r2.json().get("is_bookmarked") is True:
                    _log_pass(f"Video {bookmarked_video_id} re-marcado como favorito")
                else:
                    _log_fail(f"Re-toggle falló: {r2.text[:100]}")
                    return
            else:
                _log_fail(f"Respuesta inesperada del bookmark: {data}")
                return
        else:
            _log_fail(f"Bookmark falló: HTTP {r.status_code} — {r.text[:200]}")
            return
    except Exception as e:
        _log_fail(f"Error en bookmark: {e}")
        return

    # ── PASO 4: Verificar que aparece en la lista de favoritos del perfil ─
    _step(4, "Verificar que el video aparece en el perfil de favoritos")
    try:
        r = requests.get(
            f"{API_HOST}/api/v1/profile/bookmarks",
            headers=auth_headers,
            timeout=10,
        )

        if r.status_code == 200:
            bookmarks = r.json()
            # El endpoint puede devolver un array directo o envuelto
            if isinstance(bookmarks, dict):
                bookmarks = bookmarks.get("data", bookmarks.get("videos", []))
            if not isinstance(bookmarks, list):
                bookmarks = []

            # Buscar nuestro video en la lista
            bookmark_ids = [str(b.get("id", "")) for b in bookmarks]
            if str(bookmarked_video_id) in bookmark_ids:
                _log_pass(f"Video {bookmarked_video_id} CONFIRMADO en lista de favoritos del perfil ({len(bookmarks)} guardados)")
            else:
                _log_fail(f"Video {bookmarked_video_id} NO encontrado en favoritos. IDs encontrados: {bookmark_ids}")
        else:
            _log_fail(f"Obtener favoritos falló: HTTP {r.status_code} — {r.text[:200]}")
    except Exception as e:
        _log_fail(f"Error al verificar favoritos: {e}")

    # ── PASO 5: Limpiar — quitar el bookmark de prueba ───────────────────
    _step(5, "Limpieza — Quitar video de favoritos")
    try:
        r = requests.post(
            f"{API_HOST}/api/v1/videos/{bookmarked_video_id}/bookmark",
            headers=auth_headers,
            timeout=10,
        )
        if r.status_code == 200:
            data = r.json()
            if data.get("is_bookmarked") is False:
                _log_pass(f"Video {bookmarked_video_id} removido de favoritos (limpieza)")
            else:
                _log_info(f"Toggle devolvió is_bookmarked=True (puede requerir limpieza manual)")
        else:
            _log_info(f"No se pudo limpiar bookmark: HTTP {r.status_code}")
    except Exception as e:
        _log_info(f"Error en limpieza: {e}")


# =============================================================================
# SUITE 3: Pipeline de Tracking → BD → Recomendaciones
# =============================================================================
def suite_tracking_pipeline():
    _section("SUITE 3: PIPELINE TRACKING → BD → RECOMENDACIONES IA")

    test_user_id = 777
    test_content_id = 101

    # ── PASO 1: Enviar evento de tracking ────────────────────────────────
    _step(1, f"Enviar evento 'like' al Tracking Service (user={test_user_id}, content={test_content_id})")
    try:
        r = requests.post(
            f"{TRACKING_HOST}/api/v1/events",
            json={
                "user_id": test_user_id,
                "content_id": test_content_id,
                "event_type": "like",
                "event_value": 1.0,
            },
            headers={"X-API-Key": TRACKING_KEY, "Content-Type": "application/json"},
            timeout=10,
        )
        if r.status_code in [200, 202]:
            _log_pass(f"Evento aceptado (HTTP {r.status_code})")
        else:
            _log_fail(f"Tracking rechazó evento: HTTP {r.status_code} — {r.text[:100]}")
    except Exception as e:
        _log_fail(f"Error al enviar evento: {e}")

    # ── PASO 2: Verificar persistencia en Neon DB ────────────────────────
    _step(2, "Verificar persistencia del evento en Neon DB")
    if not DB_URL:
        _log_skip("DATABASE_URL no configurada en .env, saltando verificación de BD")
    else:
        try:
            engine = create_engine(DB_URL)
            with engine.connect() as conn:
                event_count = conn.execute(
                    text("SELECT COUNT(*) FROM tracking_events WHERE user_id = :u AND content_id = :c"),
                    {"u": test_user_id, "c": test_content_id},
                ).scalar()

                if event_count and event_count > 0:
                    _log_pass(f"Eventos persistidos en Neon DB: {event_count}")
                else:
                    _log_fail(f"No se encontraron eventos en la BD (count={event_count})")
        except ImportError:
            _log_skip("psycopg2 no instalado. Ejecuta: pip install psycopg2-binary")
        except Exception as e:
            _log_fail(f"Error al conectar con Neon DB: {e}")

    # ── PASO 3: Consultar recomendaciones ────────────────────────────────
    _step(3, f"Solicitar recomendaciones personalizadas (user={test_user_id})")
    try:
        r = requests.post(
            f"{RECS_HOST}/api/v1/recommendations",
            json={"user_id": test_user_id, "limit": 5},
            headers={"X-API-Key": RECS_KEY, "Content-Type": "application/json"},
            timeout=10,
        )
        if r.status_code == 200:
            recs = r.json().get("recommendations", [])
            _log_pass(f"Recomendaciones recibidas: {recs}")
        else:
            _log_fail(f"Recomendaciones fallaron: HTTP {r.status_code} — {r.text[:100]}")
    except Exception as e:
        _log_fail(f"Error al obtener recomendaciones: {e}")


# =============================================================================
# Limpieza de datos de prueba
# =============================================================================
def cleanup_test_user():
    """Elimina el usuario de prueba de la BD para no contaminar datos."""
    if not DB_URL:
        return
    try:
        engine = create_engine(DB_URL)
        with engine.connect() as conn:
            # Obtener ID del usuario de prueba
            user_id = conn.execute(
                text("SELECT id_usuario FROM usuarios WHERE email = :e"),
                {"e": TEST_EMAIL},
            ).scalar()

            if user_id:
                # Eliminar en orden (foreign keys)
                conn.execute(text("DELETE FROM favoritos WHERE id_usuario = :id"), {"id": user_id})
                conn.execute(text("DELETE FROM perfiles WHERE id_usuario = :id"), {"id": user_id})
                conn.execute(text("DELETE FROM usuarios WHERE id_usuario = :id"), {"id": user_id})
                conn.commit()
                _log_info(f"Usuario de prueba (ID={user_id}) eliminado de la BD")
    except Exception as e:
        _log_info(f"No se pudo limpiar usuario de prueba: {e}")


# =============================================================================
# Punto de entrada
# =============================================================================
def main():
    start_time = time.time()

    print()
    print("+" + "="*60 + "+")
    print("|     UTBGO -- Pruebas End-to-End (E2E)                     |")
    print("|     Verificacion integral del nucleo del producto         |")
    print("+" + "="*60 + "+")

    # Ejecutar suites
    services_ok = suite_health_check()
    if not services_ok:
        print("\n   Algunos servicios no responden.")
        print("   Asegurate de que 'docker-compose up' este corriendo.\n")

    suite_critical_flow()
    suite_tracking_pipeline()

    # Limpieza
    _section("LIMPIEZA")
    cleanup_test_user()

    # Resumen final
    elapsed = time.time() - start_time
    total = _results["passed"] + _results["failed"] + _results["skipped"]

    print()
    print("+" + "="*60 + "+")
    print("|                    RESUMEN FINAL                         |")
    print("+" + "-"*60 + "+")
    print(f"|  [OK]  Pasadas:   {_results['passed']:>3}                                    |")
    print(f"|  [XX]  Fallidas:  {_results['failed']:>3}                                    |")
    print(f"|  [--]  Omitidas:  {_results['skipped']:>3}                                    |")
    print(f"|  Total:           {total:>3}                                    |")
    print(f"|  Tiempo:          {elapsed:.1f}s                                   |")
    print("+" + "-"*60 + "+")

    if _results["failed"] == 0:
        print("|  >> RESULTADO: TODAS LAS PRUEBAS PASARON <<              |")
    else:
        print("|  >> RESULTADO: HAY PRUEBAS FALLIDAS <<                   |")

    print("+" + "="*60 + "+")
    print()

    sys.exit(0 if _results["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
