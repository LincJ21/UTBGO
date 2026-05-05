package main

import (
	"context"
	"fmt"
)

// PostgresPollRepository implementa PollRepository usando PostgreSQL.
type PostgresPollRepository struct{}

// NewPostgresPollRepository crea una nueva instancia del repositorio.
func NewPostgresPollRepository() *PostgresPollRepository {
	return &PostgresPollRepository{}
}

// Create inserta una encuesta con sus opciones en una transacción atómica.
func (r *PostgresPollRepository) Create(ctx context.Context, p *Poll) (int, error) {
	tx, err := DB.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("error al iniciar transacción: %w", err)
	}
	defer tx.Rollback()

	// 1. Insertar la encuesta
	var pollID int
	err = tx.QueryRowContext(ctx,
		`INSERT INTO encuestas (id_contenido, pregunta) VALUES ($1, $2) RETURNING id_encuesta`,
		p.ContentID, p.Question,
	).Scan(&pollID)
	if err != nil {
		return 0, fmt.Errorf("error al crear encuesta: %w", err)
	}

	// 2. Insertar las opciones
	for i, opt := range p.Options {
		_, err = tx.ExecContext(ctx,
			`INSERT INTO opciones_encuesta (id_encuesta, texto, orden) VALUES ($1, $2, $3)`,
			pollID, opt.Text, i,
		)
		if err != nil {
			return 0, fmt.Errorf("error al crear opción %d: %w", i, err)
		}
	}

	if err = tx.Commit(); err != nil {
		return 0, fmt.Errorf("error al confirmar transacción: %w", err)
	}

	return pollID, nil
}

// GetByContentID obtiene una encuesta completa (con opciones y total de votos).
func (r *PostgresPollRepository) GetByContentID(ctx context.Context, contentID int) (*Poll, error) {
	poll := &Poll{}

	// 1. Obtener la encuesta
	err := DB.QueryRowContext(ctx,
		`SELECT id_encuesta, id_contenido, pregunta FROM encuestas WHERE id_contenido = $1`,
		contentID,
	).Scan(&poll.ID, &poll.ContentID, &poll.Question)
	if err != nil {
		return nil, fmt.Errorf("encuesta no encontrada: %w", err)
	}

	// 2. Obtener las opciones
	rows, err := DB.QueryContext(ctx,
		`SELECT id_opcion, texto, votos, orden FROM opciones_encuesta
		 WHERE id_encuesta = $1 ORDER BY orden`, poll.ID,
	)
	if err != nil {
		return nil, fmt.Errorf("error al obtener opciones: %w", err)
	}
	defer rows.Close()

	totalVotes := 0
	for rows.Next() {
		opt := PollOption{}
		if err := rows.Scan(&opt.ID, &opt.Text, &opt.Votes, &opt.Order); err != nil {
			return nil, fmt.Errorf("error al leer opción: %w", err)
		}
		totalVotes += opt.Votes
		poll.Options = append(poll.Options, opt)
	}
	poll.TotalVotes = totalVotes

	return poll, nil
}

// Vote registra el voto de un usuario en una encuesta.
// Usa una transacción para garantizar atomicidad (insertar voto + incrementar contador).
func (r *PostgresPollRepository) Vote(ctx context.Context, pollID, optionID, userID int) error {
	tx, err := DB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("error al iniciar transacción: %w", err)
	}
	defer tx.Rollback()

	// 1. Registrar el voto (falla si ya votó — UNIQUE constraint)
	_, err = tx.ExecContext(ctx,
		`INSERT INTO votos_encuesta (id_encuesta, id_opcion, id_usuario) VALUES ($1, $2, $3)`,
		pollID, optionID, userID,
	)
	if err != nil {
		return fmt.Errorf("ya has votado en esta encuesta o error: %w", err)
	}

	// 2. Incrementar el contador de votos de la opción
	_, err = tx.ExecContext(ctx,
		`UPDATE opciones_encuesta SET votos = votos + 1 WHERE id_opcion = $1 AND id_encuesta = $2`,
		optionID, pollID,
	)
	if err != nil {
		return fmt.Errorf("error al actualizar contador de votos: %w", err)
	}

	return tx.Commit()
}

// HasVoted verifica si un usuario ya votó en una encuesta.
func (r *PostgresPollRepository) HasVoted(ctx context.Context, pollID, userID int) (bool, error) {
	var count int
	err := DB.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM votos_encuesta WHERE id_encuesta = $1 AND id_usuario = $2`,
		pollID, userID,
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("error al verificar voto: %w", err)
	}
	return count > 0, nil
}
