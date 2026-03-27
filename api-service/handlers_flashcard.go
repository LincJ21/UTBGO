package main

import (
	"fmt"
	"html"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// CreateFlashcardRequest es el payload para crear una flashcard.
type CreateFlashcardRequest struct {
	Title       string `json:"title" binding:"required,max=255"`
	Description string `json:"description" binding:"max=500"`
	FrontText   string `json:"front_text" binding:"required"`
	BackText    string `json:"back_text" binding:"required"`
}

// handleCreateFlashcard crea una nueva flashcard.
// POST /api/v1/flashcards (Auth requerido)
func handleCreateFlashcard(c *gin.Context) {
	userIDVal, _ := c.Get("userID")
	userID := int(userIDVal.(float64))

	var req CreateFlashcardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos: " + err.Error()})
		return
	}

	// Sanitizar inputs
	req.Title = html.EscapeString(strings.TrimSpace(req.Title))
	req.Description = html.EscapeString(strings.TrimSpace(req.Description))
	req.FrontText = html.EscapeString(strings.TrimSpace(req.FrontText))
	req.BackText = html.EscapeString(strings.TrimSpace(req.BackText))

	// 1. Crear el contenido padre en la tabla contenidos
	var contentID int
	err := DB.QueryRowContext(c.Request.Context(),
		`INSERT INTO contenidos (titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido, url_contenido)
		 VALUES ($1, $2, $3, $4, $5, '') RETURNING id_contenido`,
		req.Title, req.Description, userID, flashcardContentTypeID, publishedContentStateID,
	).Scan(&contentID)
	if err != nil {
		Logger.Error("Error al crear contenido para flashcard", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear flashcard"})
		return
	}

	// 2. Crear la flashcard hija
	flashcard := &Flashcard{
		ContentID: contentID,
		FrontText: req.FrontText,
		BackText:  req.BackText,
	}
	flashcardID, err := Repos.Flashcards.Create(c.Request.Context(), flashcard)
	if err != nil {
		Logger.Error("Error al crear flashcard", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al guardar flashcard"})
		return
	}

	Logger.Info("Flashcard creada", "id", flashcardID, "content_id", contentID, "user_id", userID)
	c.JSON(http.StatusOK, gin.H{
		"message":    "Flashcard creada con éxito",
		"id":         flashcardID,
		"content_id": contentID,
	})
}

// handleGetFlashcard obtiene una flashcard por su content ID.
// GET /api/v1/flashcards/:id
func handleGetFlashcard(c *gin.Context) {
	contentID := 0
	fmt.Sscanf(c.Param("id"), "%d", &contentID)
	if contentID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	flashcard, err := Repos.Flashcards.GetByContentID(c.Request.Context(), contentID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Flashcard no encontrada"})
		return
	}

	c.JSON(http.StatusOK, flashcard)
}
