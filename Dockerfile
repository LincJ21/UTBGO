# ===========================================
# UTBGO API — Dockerfile de Producción
# ===========================================
# Multi-stage build para imagen mínima y segura

# ----- Etapa 1: Build -----
FROM golang:1.24-alpine AS builder

# Instalar certificados CA para HTTPS y git para go mod
RUN apk add --no-cache ca-certificates git

WORKDIR /build

# Copiar archivos de dependencias primero (mejor cache de capas)
COPY api-service/go.mod api-service/go.sum ./

# Descargar dependencias
RUN go mod download

# Copiar código fuente
COPY api-service/ .

# Compilar binario estático (sin dependencias de libc)
# CGO_ENABLED=0 para binario completamente estático
# -ldflags: eliminar tabla de símbolos y debug info para binario más pequeño
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=$(date +%Y%m%d)" \
    -o /build/utbgo-api .

# ----- Etapa 2: Runtime -----
FROM alpine:3.21 AS runtime

# Instalar solo lo necesario para runtime
RUN apk add --no-cache ca-certificates tzdata

# Crear usuario no-root para seguridad
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copiar binario desde etapa de build
COPY --from=builder /build/utbgo-api .

# Cambiar ownership del binario
RUN chown appuser:appgroup /app/utbgo-api

# Usar usuario no-root
USER appuser

# Puerto que expone la aplicación
EXPOSE 8080

# Variables de entorno por defecto
ENV GIN_MODE=release
ENV PORT=8080

# Azure Container Apps gestiona los health probes via ingress targetPort

# Ejecutar la aplicación
ENTRYPOINT ["/app/utbgo-api"]
