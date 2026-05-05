package main

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// handleGetRecommendations obtiene recomendaciones personalizadas para el usuario logueado.
func handleGetRecommendations(c *gin.Context) {
	userIDFloat, _ := c.Get("userID")
	userID := int(userIDFloat.(float64))

	// Elimina 'category' ya que el nuevo microservicio ML y Postgres no lo usan por ahora
	nStr := c.DefaultQuery("n", "10")
	n, _ := strconv.Atoi(nStr)

	if MLRecommend != nil {
		recommendIDs, err := MLRecommend.GetRecommendations(c.Request.Context(), userID, n)
		if err == nil {
			fetchAndReturnContents(c, recommendIDs)
			return
		}
		Logger.Warn("ML Recommendations service falló, usando fallback de BD", "error", err)
	}

	// Fallback definitivo: contenido popular desde la Base de Datos
	handleGetPopularRecommendations(c)
}

// handleGetPopularRecommendations obtiene los contenidos más populares (trending) desde Postgres.
func handleGetPopularRecommendations(c *gin.Context) {
	nStr := c.DefaultQuery("n", "10")
	n, _ := strconv.Atoi(nStr)

	// Intentar obtener userID si está autenticado
	var userID *int
	if idVal, exists := c.Get("userID"); exists {
		id := int(idVal.(float64))
		userID = &id
	}

	popularVideos, err := Repos.Videos.GetPopular(c.Request.Context(), n, userID)
	if err != nil {
		Logger.Error("BD: Error al obtener populares", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener recomendaciones populares"})
		return
	}

	c.JSON(http.StatusOK, popularVideos)
}

// handleGetSimilarRecommendations obtiene contenidos similares a un id específico desde Postgres.
func handleGetSimilarRecommendations(c *gin.Context) {
	contentID, _ := strconv.Atoi(c.Param("id"))
	nStr := c.DefaultQuery("n", "10")
	n, _ := strconv.Atoi(nStr)

	// Intentar obtener userID si está autenticado
	var userID *int
	if idVal, exists := c.Get("userID"); exists {
		id := int(idVal.(float64))
		userID = &id
	}

	similarVideos, err := Repos.Videos.GetSimilar(c.Request.Context(), contentID, n, userID)
	if err != nil {
		Logger.Error("BD: Error al obtener similares", "error", err, "id", contentID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener contenidos similares"})
		return
	}

	c.JSON(http.StatusOK, similarVideos)
}

// fetchAndReturnContents es un helper para hidratar los IDs de Gorse con los datos de la BD.
func fetchAndReturnContents(c *gin.Context, ids []int) {
	if len(ids) == 0 {
		c.JSON(http.StatusOK, []any{})
		return
	}

	// Obtener los videos/imagenes desde el repositorio usando los IDs hidratados.
	// Nota: Repos.Video.GetByID ya existe? Verificamos en domain.go o handlers.go
	// Por ahora simulamos la hidratación básica.

	contents, err := Repos.Videos.GetByIDs(c.Request.Context(), ids)
	if err != nil {
		Logger.Error("Error al hidratar contenidos desde BD", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al cargar detalles de contenidos"})
		return
	}

	c.JSON(http.StatusOK, contents)
}
