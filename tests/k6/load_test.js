import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 50, // Simular 50 usuarios virtuales al mismo tiempo
  duration: '30s', // Atacar el servidor durante 30 segundos
};

export default function () {
  // Qué debe hacer cada usuario virtual:
  http.get('http://localhost:8080/health'); // Ejemplo pegándole a tu API Go
  sleep(1); // Esperar 1 segundo y volver a atacar
}
