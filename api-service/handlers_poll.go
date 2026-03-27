package main

import (
	"fmt"
	"html"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// CreatePollRequest es el payload para crear una encuesta.
type CreatePollRequest struct {
	Title       string   `json:"title" binding:"required,max=255"`
	Description string   `json:"description" binding:"max=500"`
	Question    string   `json:"question" binding:"required,max=500"`
	Options     []string `json:"options" binding:"required,min=2,max=6"`
}

// VotePollRequest es el payload para votar en una encuesta.
type VotePollRequest struct {
	OptionID int `json:"option_id" binding:"required"`
}

// handleCreatePoll crea una nueva encuesta con opciones.
// POST /api/v1/polls (Auth requerido)
func handleCreatePoll(c *gin.Context) {
	userIDVal, _ := c.Get("userID")
	userID := int(userIDVal.(float64))

	var req CreatePollRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos: " + err.Error()})
		return
	}

	// Validar que hay al menos 2 opciones no vacías
	validOptions := []string{}
	for _, opt := range req.Options {
		trimmed := strings.TrimSpace(opt)
		if trimmed != "" {
			validOptions = append(validOptions, html.EscapeString(trimmed))
		}
	}
	if len(validOptions) < 2 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Se necesitan al menos 2 opciones"})
		return
	}

	// Sanitizar inputs
	req.Title = html.EscapeString(strings.TrimSpace(req.Title))
	req.Description = html.EscapeString(strings.TrimSpace(req.Description))
	req.Question = html.EscapeString(strings.TrimSpace(req.Question))

	// 1. Crear el contenido padre en la tabla contenidos
	var contentID int
	err := DB.QueryRowContext(c.Request.Context(),
		`INSERT INTO contenidos (titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido, url_contenido)
		 VALUES ($1, $2, $3, $4, $5, '') RETURNING id_contenido`,
		req.Title, req.Description, userID, pollContentTypeID, publishedContentStateID,
	).Scan(&contentID)
	if err != nil {
		Logger.Error("Error al crear contenido para encuesta", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear encuesta"})
		return
	}

	// 2. Crear la encuesta con las opciones
	poll := &Poll{
		ContentID: contentID,
		Question:  req.Question,
	}
	for _, opt := range validOptions {
		poll.Options = append(poll.Options, PollOption{Text: opt})
	}

	pollID, err := Repos.Polls.Create(c.Request.Context(), poll)
	if err != nil {
		Logger.Error("Error al crear encuesta", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al guardar encuesta"})
		return
	}

	Logger.Info("Encuesta creada", "id", pollID, "content_id", contentID, "user_id", userID, "opciones", len(validOptions))
	c.JSON(http.StatusOK, gin.H{
		"message":    "Encuesta creada con éxito",
		"id":         pollID,
		"content_id": contentID,
	})
}

// handleGetPoll obtiene una encuesta completa con opciones y estado de voto del usuario.
// GET /api/v1/polls/:id (Auth requerido para saber si votó)
func handleGetPoll(c *gin.Context) {
	contentID := 0
	fmt.Sscanf(c.Param("id"), "%d", &contentID)
	if contentID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	poll, err := Repos.Polls.GetByContentID(c.Request.Context(), contentID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Encuesta no encontrada"})
		return
	}

	// Verificar si el usuario ya votó
	userIDVal, exists := c.Get("userID")
	if exists {
		userID := int(userIDVal.(float64))
		hasVoted, _ := Repos.Polls.HasVoted(c.Request.Context(), poll.ID, userID)
		poll.HasVoted = hasVoted
	}

	c.JSON(http.StatusOK, poll)
}

// handleVotePoll registra el voto de un usuario en una encuesta.
// POST /api/v1/polls/:id/vote (Auth requerido)
func handleVotePoll(c *gin.Context) {
	userIDVal, _ := c.Get("userID")
	userID := int(userIDVal.(float64))

	contentID := 0
	fmt.Sscanf(c.Param("id"), "%d", &contentID)
	if contentID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	var req VotePollRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos"})
		return
	}

	// Obtener la encuesta para verificar que existe
	poll, err := Repos.Polls.GetByContentID(c.Request.Context(), contentID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Encuesta no encontrada"})
		return
	}

	// Intentar votar
	err = Repos.Polls.Vote(c.Request.Context(), poll.ID, req.OptionID, userID)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Ya has votado en esta encuesta"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Voto registrado con éxito"})
}
