package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
)

func main() {
	// Cargar .env
	if err := godotenv.Load("../../../../.env"); err != nil {
		log.Fatalf("Error cargando .env: %v", err)
	}

	db, err := sql.Open("pgx", os.Getenv("DB_CONNECTION_STRING"))
	if err != nil {
		log.Fatalf("Error conectando: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Error ping: %v", err)
	}

	// Asegurar que los tipos de usuario existan
	_, err = db.Exec(`
		INSERT INTO tipos_usuario (codigo, nombre, descripcion, nivel_acceso) VALUES
			('estudiante', 'Estudiante', 'Rol por defecto', 1),
			('profesor', 'Profesor', 'Puede subir contenido educativo', 3),
			('moderador', 'Moderador', 'Puede moderar contenido y usuarios', 5),
			('admin', 'Administrador', 'Acceso total al sistema', 10)
		ON CONFLICT (codigo) DO NOTHING
	`)
	if err != nil {
		log.Fatalf("Error insertando tipos_usuario: %v", err)
	}

	// Obtener id del tipo 'profesor'
	var profesorTypeID int
	err = db.QueryRow("SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = 'profesor'").Scan(&profesorTypeID)
	if err != nil {
		log.Fatalf("Error obteniendo tipo profesor: %v", err)
	}

	// Actualizar usuario test@utb.edu.co a profesor
	result, err := db.Exec(
		"UPDATE usuarios SET id_tipo_usuario = $1 WHERE email = $2",
		profesorTypeID, "test@utb.edu.co")
	if err != nil {
		log.Fatalf("Error actualizando rol: %v", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		log.Println("⚠️  No se encontró el usuario test@utb.edu.co")
	} else {
		fmt.Println("✅ Usuario test@utb.edu.co ahora tiene rol PROFESOR")
		fmt.Println("   Puede subir videos desde la app")
	}
}
