import http from 'k6/http';
import { check, sleep } from 'k6';

// Configuración de la prueba:
// Simula 50 usuarios virtuales escalando gradualmente durante 1 minuto,
// se mantiene 1 minuto, y luego baja a 0.
export const options = {
  stages: [
    { duration: '30s', target: 50 }, // Ramp-up a 50 usuarios
    { duration: '1m', target: 50 },  // Mantener 50 usuarios por 1 minuto
    { duration: '30s', target: 0 },  // Ramp-down
  ],
  thresholds: {
    // Los SLOs (Service Level Objectives) del proyecto
    http_req_duration: ['p(95)<2000'], // 95% de las peticiones deben tardar menos de 2s
    http_req_failed: ['rate<0.05'],    // Tasa de error debe ser menor al 5%
  },
};

export default function () {
  // Tomamos la URL base desde las variables de entorno inyectadas por GitHub Actions
  const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

  // Prueba 1: Endpoint de Salud (Healthcheck)
  const healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health status is 200': (r) => r.status === 200,
  });

  // Prueba 2: Búsqueda genérica (si la API lo permite sin Auth)
  // Reemplazar con endpoint real público o inyectar un JWT de prueba si es necesario
  const searchRes = http.get(`${BASE_URL}/api/v1/videos/search?q=test`);
  check(searchRes, {
    'search status is 200': (r) => r.status === 200,
  });

  // Simular tiempo de lectura/pensamiento del usuario
  sleep(1);
}
