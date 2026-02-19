package main

import (
	"context"
	"database/sql"
	"log"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // Driver de PostgreSQL para database/sql
)

// DB es el pool de conexiones a la base de datos, accesible globalmente.
var DB *sql.DB

// InitDB inicializa la conexión con la base de datos usando la cadena de conexión proporcionada.
func InitDB(connStr string) {
	var err error

	// Abrimos la conexión a la base de datos. sql.Open no establece ninguna conexión,
	// solo prepara el pool de conexiones.
	DB, err = sql.Open("pgx", connStr)
	if err != nil {
		log.Fatalf("Error al preparar la conexión a la base de datos: %v", err)
	}

	// Usamos PingContext para verificar que la conexión a la base de datos es válida.
	// Aumentamos el timeout a 30 segundos. Las conexiones iniciales a servicios en la nube
	// pueden ser lentas si la base de datos está "dormida". 5 segundos puede ser muy poco.
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err = DB.PingContext(ctx); err != nil {
		log.Fatalf("Error al conectar con la base de datos: %v", err)
	}

	log.Println("Conexión a la base de datos establecida exitosamente.")
}
