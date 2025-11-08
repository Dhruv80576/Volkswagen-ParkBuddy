package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// PricingAPIClient handles communication with the ML pricing service
type PricingAPIClient struct {
	baseURL    string
	httpClient *http.Client
}

// PricePredictionRequest represents a request to the pricing API
type PricePredictionRequest struct {
	City          string  `json:"city"`
	Area          string  `json:"area,omitempty"`
	ParkingType   string  `json:"parking_type"`
	BasePrice     float64 `json:"base_price"`
	IsEVCharging  bool    `json:"is_ev_charging"`
	IsHandicap    bool    `json:"is_handicap"`
	DemandScore   float64 `json:"demand_score,omitempty"`
	OccupancyRate float64 `json:"occupancy_rate,omitempty"`
	Weather       string  `json:"weather,omitempty"`
	IsEvent       bool    `json:"is_event,omitempty"`
	Hour          int     `json:"hour,omitempty"`
	DayOfWeek     int     `json:"day_of_week,omitempty"`
	Month         int     `json:"month,omitempty"`
}

// PricePredictionResponse represents the response from the pricing API
type PricePredictionResponse struct {
	PredictedPrice  float64                `json:"predicted_price"`
	BasePrice       float64                `json:"base_price"`
	PriceMultiplier float64                `json:"price_multiplier"`
	Confidence      string                 `json:"confidence"`
	Timestamp       string                 `json:"timestamp"`
	FeaturesUsed    map[string]interface{} `json:"features_used"`
}

// DemandCalculationRequest represents a request to calculate demand
type DemandCalculationRequest struct {
	City           string `json:"city"`
	ParkingType    string `json:"parking_type"`
	AvailableSlots int    `json:"available_slots"`
	TotalSlots     int    `json:"total_slots"`
	RecentRequests int    `json:"recent_requests"`
	Hour           int    `json:"hour,omitempty"`
	DayOfWeek      int    `json:"day_of_week,omitempty"`
}

// DemandCalculationResponse represents the demand calculation response
type DemandCalculationResponse struct {
	DemandScore   float64 `json:"demand_score"`
	OccupancyRate float64 `json:"occupancy_rate"`
	DemandLevel   string  `json:"demand_level"`
}

// NewPricingAPIClient creates a new pricing API client
func NewPricingAPIClient(baseURL string) *PricingAPIClient {
	return &PricingAPIClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// HealthCheck checks if the pricing API is healthy
func (c *PricingAPIClient) HealthCheck() (bool, error) {
	resp, err := c.httpClient.Get(c.baseURL + "/health")
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("API returned status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return false, err
	}

	status, ok := result["status"].(string)
	return ok && status == "healthy", nil
}

// PredictPrice gets a dynamic price prediction for a parking slot
func (c *PricingAPIClient) PredictPrice(req PricePredictionRequest) (*PricePredictionResponse, error) {
	// Marshal request
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Make request
	resp, err := c.httpClient.Post(
		c.baseURL+"/api/predict-price",
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Check status
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var result PricePredictionResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	return &result, nil
}

// CalculateDemand calculates the current demand score
func (c *PricingAPIClient) CalculateDemand(req DemandCalculationRequest) (*DemandCalculationResponse, error) {
	// Marshal request
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Make request
	resp, err := c.httpClient.Post(
		c.baseURL+"/api/calculate-demand",
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Check status
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var result DemandCalculationResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	return &result, nil
}

// GetDynamicPriceForSlot is a helper function to get dynamic price for a parking slot
func (c *PricingAPIClient) GetDynamicPriceForSlot(slot *ParkingSlot, demandScore, occupancyRate float64) (float64, error) {
	now := time.Now()

	req := PricePredictionRequest{
		City:          slot.City,
		Area:          slot.Area,
		ParkingType:   slot.Type,
		BasePrice:     slot.PricePerHr,
		IsEVCharging:  slot.IsEVCharging,
		IsHandicap:    slot.IsHandicap,
		DemandScore:   demandScore,
		OccupancyRate: occupancyRate,
		Hour:          now.Hour(),
		DayOfWeek:     int(now.Weekday()),
		Month:         int(now.Month()),
	}

	resp, err := c.PredictPrice(req)
	if err != nil {
		// Fallback to base price if API fails
		fmt.Printf("Warning: Failed to get dynamic price, using base price: %v\n", err)
		return slot.PricePerHr, nil
	}

	return resp.PredictedPrice, nil
}

// Example usage function
func exampleUsage() {
	// Initialize the pricing API client
	pricingClient := NewPricingAPIClient("http://localhost:5000")

	// Check if the API is healthy
	healthy, err := pricingClient.HealthCheck()
	if err != nil {
		fmt.Printf("Health check failed: %v\n", err)
		return
	}
	fmt.Printf("Pricing API healthy: %v\n", healthy)

	// Example 1: Calculate demand
	demandReq := DemandCalculationRequest{
		City:           "Mumbai",
		ParkingType:    "commercial",
		AvailableSlots: 30,
		TotalSlots:     200,
		RecentRequests: 45,
	}

	demandResp, err := pricingClient.CalculateDemand(demandReq)
	if err != nil {
		fmt.Printf("Demand calculation failed: %v\n", err)
		return
	}
	fmt.Printf("Demand Score: %.2f (Level: %s)\n", demandResp.DemandScore, demandResp.DemandLevel)

	// Example 2: Get price prediction
	priceReq := PricePredictionRequest{
		City:          "Mumbai",
		Area:          "Bandra",
		ParkingType:   "commercial",
		BasePrice:     25.0,
		IsEVCharging:  true,
		IsHandicap:    false,
		DemandScore:   demandResp.DemandScore,
		OccupancyRate: demandResp.OccupancyRate,
	}

	priceResp, err := pricingClient.PredictPrice(priceReq)
	if err != nil {
		fmt.Printf("Price prediction failed: %v\n", err)
		return
	}

	fmt.Printf("Dynamic Price: ₹%.2f (Base: ₹%.2f, Multiplier: %.2fx)\n",
		priceResp.PredictedPrice,
		priceResp.BasePrice,
		priceResp.PriceMultiplier)
	fmt.Printf("Confidence: %s\n", priceResp.Confidence)
}
