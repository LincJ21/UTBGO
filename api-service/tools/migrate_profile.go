package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	err := godotenv.Load("../.env")
	if err != nil {
		log.Println("No .env file found")
	}

	dsn := os.Getenv("DB_CONNECTION_STRING")
	if dsn == "" {
		log.Fatal("DB_CONNECTION_STRING no definida")
	}

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	commands := []string{
		"ALTER TABLE perfiles ADD COLUMN IF NOT EXISTS facultad VARCHAR(100) DEFAULT '';",
		"ALTER TABLE perfiles ADD COLUMN IF NOT EXISTS cvlac_url TEXT;",
		"ALTER TABLE perfiles ADD COLUMN IF NOT EXISTS website_url TEXT;",
	}

	for _, cmd := range commands {
		_, err := db.ExecContext(context.Background(), cmd)
		if err != nil {
			log.Printf("Error running: %s\n%v\n", cmd, err)
		} else {
			fmt.Printf("Success: %s\n", cmd)
		}
	}
	fmt.Println("Migración completada.")
}
