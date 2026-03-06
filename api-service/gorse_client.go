package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	gorse "github.com/gorse-io/gorse-go"
)

// GorseClientWrapper envuelve el cliente oficial de Gorse con lógica específica de UTBGO.
type GorseClientWrapper struct {
	client     *gorse.GorseClient
	entryPoint string
	apiKey     string
}

// NewGorseClient crea una nueva instancia del cliente de Gorse.
func NewGorseClient(url, apiKey string) *GorseClientWrapper {
	if url == "" {
		log.Println("ADVERTENCIA: GORSE_SERVER_URL no configurado")
		return nil
	}
	client := gorse.NewGorseClient(url, apiKey)
	return &GorseClientWrapper{
		client:     client,
		entryPoint: url,
		apiKey:     apiKey,
	}
}

// RegisterUser registra o actualiza un usuario en Gorse.
func (g *GorseClientWrapper) RegisterUser(ctx context.Context, userID int, labels []string) error {
	if g == nil {
		return nil
	}
	user := gorse.User{
		UserId: fmt.Sprintf("user_%d", userID),
		Labels: labels,
	}
	_, err := g.client.InsertUser(ctx, user)
	return err
}

// RegisterItem registra un contenido (video o imagen) en Gorse.
func (g *GorseClientWrapper) RegisterItem(ctx context.Context, contentID int, category string, labels []string) error {
	if g == nil {
		return nil
	}
	item := gorse.Item{
		ItemId:     fmt.Sprintf("content_%d", contentID),
		IsHidden:   false,
		Categories: []string{category}, // "video" o "imagen"
		Labels:     labels,
		Timestamp:  time.Now(),
	}
	_, err := g.client.InsertItem(ctx, item)
	return err
}

// HideItem marca un contenido como oculto (ej. eliminado).
func (g *GorseClientWrapper) HideItem(ctx context.Context, contentID int) error {
	if g == nil {
		return nil
	}
	item, err := g.client.GetItem(ctx, fmt.Sprintf("content_%d", contentID))
	if err != nil {
		return err
	}
	item.IsHidden = true
	_, err = g.client.InsertItem(ctx, item)
	return err
}

// GetRecommendations obtiene recomendaciones personalizadas para un usuario.
func (g *GorseClientWrapper) GetRecommendations(ctx context.Context, userID int, category string, n int) ([]int, error) {
	if g == nil {
		return nil, fmt.Errorf("gorse client not initialized")
	}

	// Si no hay userID (invitado), pedir populares
	if userID <= 0 {
		return g.GetPopular(ctx, category, n)
	}

	res, err := g.client.GetRecommend(ctx, fmt.Sprintf("user_%d", userID), category, n, 0)
	if err != nil {
		return nil, err
	}

	return parseIDsFromStrings(res), nil
}

// GetPopular obtiene los contenidos más populares (trending) vía API directa porque el SDK no lo tiene.
func (g *GorseClientWrapper) GetPopular(ctx context.Context, category string, n int) ([]int, error) {
	if g == nil {
		return nil, fmt.Errorf("gorse client not initialized")
	}

	url := fmt.Sprintf("%s/api/popular/%s?n=%d", g.entryPoint, category, n)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-API-Key", g.apiKey)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("gorse error: %d - %s", resp.StatusCode, string(body))
	}

	var scores []gorse.Score
	if err := json.NewDecoder(resp.Body).Decode(&scores); err != nil {
		return nil, err
	}

	return parseIDsFromScores(scores), nil
}

// GetSimilar obtiene contenidos similares a uno dado.
func (g *GorseClientWrapper) GetSimilar(ctx context.Context, contentID int, category string, n int) ([]int, error) {
	if g == nil {
		return nil, fmt.Errorf("gorse client not initialized")
	}
	// El SDK tiene GetNeighbors(itemId, n) o GetNeighborsCategory(itemId, category, n, offset)
	res, err := g.client.GetNeighborsCategory(ctx, fmt.Sprintf("content_%d", contentID), category, n, 0)
	if err != nil {
		return nil, err
	}
	return parseIDsFromScores(res), nil
}

// parseIDsFromStrings convierte los IDs de string de Gorse ("content_123") de vuelta a int.
func parseIDsFromStrings(gorseIDs []string) []int {
	var ids []int
	for _, gid := range gorseIDs {
		idStr := strings.TrimPrefix(gid, "content_")
		if id, err := strconv.Atoi(idStr); err == nil {
			ids = append(ids, id)
		}
	}
	return ids
}

// parseIDsFromScores convierte los scores de Gorse a una lista de IDs de int.
func parseIDsFromScores(scores []gorse.Score) []int {
	var ids []int
	for _, s := range scores {
		idStr := strings.TrimPrefix(s.Id, "content_")
		if id, err := strconv.Atoi(idStr); err == nil {
			ids = append(ids, id)
		}
	}
	return ids
}
