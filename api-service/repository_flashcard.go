package main

import (
	"context"
	"fmt"
)

// PostgresFlashcardRepository implementa FlashcardRepository usando PostgreSQL.
type PostgresFlashcardRepository struct{}

// NewPostgresFlashcardRepository crea una nueva instancia del repositorio.
func NewPostgresFlashcardRepository() *PostgresFlashcardRepository {
	return &PostgresFlashcardRepository{}
}

// Create inserta una flashcard asociada a un contenido existente.
func (r *PostgresFlashcardRepository) Create(ctx context.Context, f *Flashcard) (int, error) {
	var id int
	err := DB.QueryRowContext(ctx,
		`INSERT INTO flashcards (id_contenido, texto_frente, texto_reverso, imagen_frente_url, imagen_reverso_url)
		 VALUES ($1, $2, $3, $4, $5) RETURNING id_flashcard`,
		f.ContentID, f.FrontText, f.BackText, f.FrontImageURL, f.BackImageURL,
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("error al crear flashcard: %w", err)
	}
	return id, nil
}

// GetByContentID obtiene la flashcard asociada a un contenido.
func (r *PostgresFlashcardRepository) GetByContentID(ctx context.Context, contentID int) (*Flashcard, error) {
	f := &Flashcard{}
	err := DB.QueryRowContext(ctx,
		`SELECT id_flashcard, id_contenido, texto_frente, texto_reverso,
		        COALESCE(imagen_frente_url, ''), COALESCE(imagen_reverso_url, '')
		 FROM flashcards WHERE id_contenido = $1`, contentID,
	).Scan(&f.ID, &f.ContentID, &f.FrontText, &f.BackText, &f.FrontImageURL, &f.BackImageURL)
	if err != nil {
		return nil, fmt.Errorf("flashcard no encontrada: %w", err)
	}
	return f, nil
}
