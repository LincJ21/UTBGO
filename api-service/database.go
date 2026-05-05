package main

import (
	"context"
	"database/sql"
	"os"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // Driver de PostgreSQL para database/sql
)

// DB es el pool de conexiones a la base de datos, accesible globalmente.
var DB *sql.DB

// InitDB inicializa la conexión con la base de datos usando la cadena de conexión proporcionada.
// Configura el pool de conexiones para soportar alta concurrencia (~8000+ usuarios).
func InitDB(connStr string) {
	var err error

	DB, err = sql.Open("pgx", connStr)
	if err != nil {
		Logger.Error("Error al preparar la conexión a la base de datos", "error", err)
		os.Exit(1)
	}

	// --- CONFIGURACIÓN DEL POOL DE CONEXIONES ---
	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(10)
	DB.SetConnMaxLifetime(5 * time.Minute)
	DB.SetConnMaxIdleTime(3 * time.Minute)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err = DB.PingContext(ctx); err != nil {
		Logger.Error("Error al conectar con la base de datos", "error", err)
		os.Exit(1)
	}

	Logger.Info("Conexión a la base de datos establecida",
		"max_open", 25, "max_idle", 10, "max_lifetime", "5m", "max_idle_time", "3m")
}
