package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	_ "github.com/jackc/pgx/v5/stdlib" // CORRECCIÓN: Usar el mismo driver que el resto de la app
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
)

// getDBConnection se conecta a la base de datos usando los datos de tu script de Python.
func getDBConnection() (*sql.DB, error) {
	// Datos de conexión extraídos de tu archivo db.py
	connStr := os.Getenv("DB_CONNECTION_STRING") // Usar la variable de entorno

	db, err := sql.Open("pgx", connStr) // CORRECCIÓN: Usar el nombre de driver 'pgx'
	if err != nil {
		return nil, fmt.Errorf("fallo al abrir la conexión a la base de datos: %w", err)
	}

	if err = db.Ping(); err != nil {
		return nil, fmt.Errorf("no se pudo hacer ping a la base de datos: %w", err)
	}

	log.Println("Conexión a la base de datos exitosa.")
	return db, nil
}

func main() {
	// Cargar variables de entorno desde el archivo .env
	err := godotenv.Load("../../.env") // CORRECCIÓN: La ruta correcta al .env desde lib/app
	if err != nil {
		log.Fatalf("Error al cargar el archivo .env: %v", err)
	}

	log.Println("🚀 Iniciando herramienta para crear usuario de ejemplo...")

	db, err := getDBConnection()
	if err != nil {
		log.Fatalf("❌ Error de conexión: %v", err)
	}
	defer db.Close()

	// --- 1. Definir los datos del nuevo usuario ---
	email := "usuario.ejemplo@email.com"
	password := "password123" // Contraseña en texto plano
	nombre := "Usuario"
	apellido := "Ejemplo"
	userTypeCode := "estudiante" // Código del tipo de usuario
	userStatusCode := "activo"   // Código del estado del usuario

	// --- 2. Obtener IDs de las tablas de referencia ---
	var userTypeID int
	err = db.QueryRow("SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = $1", userTypeCode).Scan(&userTypeID)
	if err != nil {
		log.Fatalf("❌ Error al obtener id para tipo '%s': %v", userTypeCode, err)
	}
	log.Printf("✔️  ID para tipo '%s' obtenido: %d", userTypeCode, userTypeID)

	var userStatusID int
	err = db.QueryRow("SELECT id_estado_usuario FROM estados_usuario WHERE codigo = $1", userStatusCode).Scan(&userStatusID)
	if err != nil {
		log.Fatalf("❌ Error al obtener id para estado '%s': %v", userStatusCode, err)
	}
	log.Printf("✔️  ID para estado '%s' obtenido: %d", userStatusCode, userStatusID)

	// --- 3. Generar hash de la contraseña (¡MUY IMPORTANTE!) ---
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("❌ Error al generar el hash de la contraseña: %v", err)
	}
	log.Println("✔️  Hash de contraseña generado.")

	// --- 4. Iniciar una transacción para asegurar la consistencia ---
	tx, err := db.Begin()
	if err != nil {
		log.Fatalf("❌ Error al iniciar la transacción: %v", err)
	}
	// Si algo sale mal, hacemos rollback para deshacer los cambios
	defer tx.Rollback()

	// --- 5. Insertar en la tabla 'usuarios' ---
	var newUserID int
	userInsertQuery := `
		INSERT INTO usuarios (id_tipo_usuario, id_estado_usuario, email, password_hash, fecha_registro)
		VALUES ($1, $2, $3, $4, NOW())
		RETURNING id_usuario
	`
	err = tx.QueryRow(userInsertQuery, userTypeID, userStatusID, email, string(hashedPassword)).Scan(&newUserID)
	if err != nil {
		// Comprobamos si el error es por email duplicado usando strings.Contains
		if strings.Contains(err.Error(), "usuarios_email_key") {
			log.Fatalf("❌ Error: El email '%s' ya existe en la base de datos.", email)
		}
		log.Fatalf("❌ Error al insertar en la tabla 'usuarios': %v", err)
	}
	log.Printf("✔️  Usuario insertado en 'usuarios' con ID: %d", newUserID)

	// --- 6. Insertar en la tabla 'perfiles' ---
	profileInsertQuery := `
		INSERT INTO perfiles (id_usuario, nombre, apellido)
		VALUES ($1, $2, $3)
	`
	_, err = tx.Exec(profileInsertQuery, newUserID, nombre, apellido)
	if err != nil {
		log.Fatalf("❌ Error al insertar en la tabla 'perfiles': %v", err)
	}
	log.Println("✔️  Perfil insertado en 'perfiles'.")

	// --- 7. Confirmar la transacción ---
	if err = tx.Commit(); err != nil {
		log.Fatalf("❌ Error al confirmar la transacción: %v", err)
	}

	log.Println("🎉 ¡Usuario de ejemplo creado exitosamente!")
	log.Printf("   Email: %s", email)
	log.Printf("   Contraseña: %s", password)
}
