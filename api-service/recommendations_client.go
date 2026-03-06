package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// CustomRecommendationClient acts as a client to the new Python Recommendation Service
type CustomRecommendationClient struct {
	baseURL string
	apiKey  string
}

// NewCustomRecommendationClient initializes the client to the python recommendation service
func NewCustomRecommendationClient(baseURL string, apiKey string) *CustomRecommendationClient {
	if baseURL == "" || apiKey == "" {
		Logger.Warn("ADVERTENCIA: RECOMMENDATIONS_SERVICE_URL o RECOMMENDATIONS_API_KEY no están configurados")
		return nil
	}
	return &CustomRecommendationClient{
		baseURL: baseURL,
		apiKey:  apiKey,
	}
}

// RecommendationRequest is the payload sent to the recommendation service
type RecommendationRequest struct {
	UserID int `json:"user_id"`
	Limit  int `json:"limit"`
}

// RecommendationResponse is the response returned by the recommendation service
type RecommendationResponse struct {
	UserID          int   `json:"user_id"`
	Recommendations []int `json:"recommendations"`
}

// GetRecommendations calls the python ML service to get personalized recommendations
func (c *CustomRecommendationClient) GetRecommendations(ctx context.Context, userID int, limit int) ([]int, error) {
	if c == nil {
		return nil, fmt.Errorf("custom recommendation client not initialized")
	}

	url := fmt.Sprintf("%s/api/v1/recommendations", c.baseURL)

	reqBody := RecommendationRequest{
		UserID: userID,
		Limit:  limit,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("error marshaling recommendation request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("error creating recommendation request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-Key", c.apiKey)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("error calling recommendation service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("recommendation service responded with error: %s", resp.Status)
	}

	var recResp RecommendationResponse
	if err := json.NewDecoder(resp.Body).Decode(&recResp); err != nil {
		return nil, fmt.Errorf("error decoding recommendation response: %w", err)
	}

	return recResp.Recommendations, nil
}
