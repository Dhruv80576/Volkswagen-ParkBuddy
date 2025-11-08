package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Booking represents a parking slot booking
type Booking struct {
	ID                      string     `json:"id"`
	UserID                  string     `json:"userId"`
	SlotID                  string     `json:"slotId"`
	City                    string     `json:"city"`
	Area                    string     `json:"area"`
	Latitude                float64    `json:"latitude"`
	Longitude               float64    `json:"longitude"`
	ParkingType             string     `json:"parkingType"`
	BookingTime             time.Time  `json:"bookingTime"`
	StartTime               time.Time  `json:"startTime"`
	EndTime                 time.Time  `json:"endTime"`
	PricePerHour            float64    `json:"pricePerHour"`
	TotalPrice              float64    `json:"totalPrice"`
	Status                  string     `json:"status"` // pending, confirmed, active, completed, cancelled
	IsEVCharging            bool       `json:"isEVCharging"`
	IsHandicap              bool       `json:"isHandicap"`
	AvailabilityProbability *float64   `json:"availabilityProbability,omitempty"`
	AvailabilityConfidence  *string    `json:"availabilityConfidence,omitempty"`
	VehicleNumber           *string    `json:"vehicleNumber,omitempty"`
	VehicleModel            *string    `json:"vehicleModel,omitempty"`
	SpecialRequests         *string    `json:"specialRequests,omitempty"`
	CheckinTime             *time.Time `json:"checkinTime,omitempty"`
	CheckoutTime            *time.Time `json:"checkoutTime,omitempty"`
}

type CreateBookingRequest struct {
	UserID          string    `json:"userId" binding:"required"`
	SlotID          string    `json:"slotId" binding:"required"`
	StartTime       time.Time `json:"startTime" binding:"required"`
	EndTime         time.Time `json:"endTime" binding:"required"`
	VehicleNumber   *string   `json:"vehicleNumber"`
	VehicleModel    *string   `json:"vehicleModel"`
	SpecialRequests *string   `json:"specialRequests"`
}

// BookingManager handles booking operations
type BookingManager struct {
	bookings map[string]*Booking
	mu       sync.RWMutex
}

var bookingManager *BookingManager

func init() {
	bookingManager = &BookingManager{
		bookings: make(map[string]*Booking),
	}
}

// Create a new booking
func createBooking(c *gin.Context) {
	var req CreateBookingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate times
	if req.EndTime.Before(req.StartTime) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "End time must be after start time"})
		return
	}

	if req.StartTime.Before(time.Now()) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Start time must be in the future"})
		return
	}

	// Get slot details from bipartite graph
	slot := bipartiteGraph.GetSlotByID(req.SlotID)
	if slot == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Parking slot not found"})
		return
	}

	// Check if slot is available
	if slot.Status != "available" {
		c.JSON(http.StatusConflict, gin.H{"error": "Parking slot is not available"})
		return
	}

	// Calculate total price
	duration := req.EndTime.Sub(req.StartTime).Hours()
	totalPrice := duration * slot.PricePerHr

	// Create booking
	booking := &Booking{
		ID:              uuid.New().String(),
		UserID:          req.UserID,
		SlotID:          slot.ID,
		City:            slot.City,
		Area:            slot.Area,
		Latitude:        slot.Latitude,
		Longitude:       slot.Longitude,
		ParkingType:     slot.Type,
		BookingTime:     time.Now(),
		StartTime:       req.StartTime,
		EndTime:         req.EndTime,
		PricePerHour:    slot.PricePerHr,
		TotalPrice:      totalPrice,
		Status:          "pending",
		IsEVCharging:    slot.IsEVCharging,
		IsHandicap:      slot.IsHandicap,
		VehicleNumber:   req.VehicleNumber,
		VehicleModel:    req.VehicleModel,
		SpecialRequests: req.SpecialRequests,
	}

	// Get availability prediction from ML model
	prediction := predictAvailability(slot, req.StartTime)
	if prediction != nil {
		booking.AvailabilityProbability = &prediction.AvailabilityProbability
		confidence := prediction.ConfidenceLevel
		booking.AvailabilityConfidence = &confidence
	}

	// Save booking
	bookingManager.mu.Lock()
	bookingManager.bookings[booking.ID] = booking
	bookingManager.mu.Unlock()

	// Auto-confirm booking for now (in production, may require payment)
	booking.Status = "confirmed"

	// Mark slot as occupied (optimistic locking)
	bipartiteGraph.UpdateSlotStatus(slot.ID, "occupied")

	c.JSON(http.StatusCreated, booking)
}

// Get booking by ID
func getBooking(c *gin.Context) {
	bookingID := c.Param("bookingId")

	bookingManager.mu.RLock()
	booking, exists := bookingManager.bookings[bookingID]
	bookingManager.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Booking not found"})
		return
	}

	c.JSON(http.StatusOK, booking)
}

// Get user's bookings
func getUserBookings(c *gin.Context) {
	userID := c.Param("userId")

	bookingManager.mu.RLock()
	defer bookingManager.mu.RUnlock()

	userBookings := []*Booking{}
	for _, booking := range bookingManager.bookings {
		if booking.UserID == userID {
			userBookings = append(userBookings, booking)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"bookings": userBookings,
		"count":    len(userBookings),
	})
}

// Cancel a booking
func cancelBooking(c *gin.Context) {
	bookingID := c.Param("bookingId")

	bookingManager.mu.Lock()
	defer bookingManager.mu.Unlock()

	booking, exists := bookingManager.bookings[bookingID]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Booking not found"})
		return
	}

	if booking.Status == "completed" || booking.Status == "cancelled" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot cancel completed or already cancelled booking"})
		return
	}

	// Update booking status
	booking.Status = "cancelled"

	// Free up the slot
	bipartiteGraph.UpdateSlotStatus(booking.SlotID, "available")

	c.JSON(http.StatusOK, booking)
}

// Confirm a booking
func confirmBooking(c *gin.Context) {
	bookingID := c.Param("bookingId")

	bookingManager.mu.Lock()
	defer bookingManager.mu.Unlock()

	booking, exists := bookingManager.bookings[bookingID]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Booking not found"})
		return
	}

	if booking.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Booking is not pending"})
		return
	}

	booking.Status = "confirmed"

	c.JSON(http.StatusOK, booking)
}

// Check in to a booking
func checkinBooking(c *gin.Context) {
	bookingID := c.Param("bookingId")

	bookingManager.mu.Lock()
	defer bookingManager.mu.Unlock()

	booking, exists := bookingManager.bookings[bookingID]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Booking not found"})
		return
	}

	if booking.Status != "confirmed" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Booking must be confirmed to check in"})
		return
	}

	now := time.Now()
	booking.CheckinTime = &now
	booking.Status = "active"

	c.JSON(http.StatusOK, booking)
}

// Check out from a booking
func checkoutBooking(c *gin.Context) {
	bookingID := c.Param("bookingId")

	bookingManager.mu.Lock()
	defer bookingManager.mu.Unlock()

	booking, exists := bookingManager.bookings[bookingID]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Booking not found"})
		return
	}

	if booking.Status != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Booking must be active to check out"})
		return
	}

	now := time.Now()
	booking.CheckoutTime = &now
	booking.Status = "completed"

	// Free up the slot
	bipartiteGraph.UpdateSlotStatus(booking.SlotID, "available")

	c.JSON(http.StatusOK, booking)
}

// AvailabilityPredictionResponse from ML API
type AvailabilityPredictionResponse struct {
	Success                 bool    `json:"success"`
	IsAvailable             bool    `json:"is_available"`
	AvailabilityProbability float64 `json:"availability_probability"`
	OccupancyProbability    float64 `json:"occupancy_probability"`
	Confidence              float64 `json:"confidence"`
	PredictionTime          string  `json:"prediction_time"`
	ConfidenceLevel         string  `json:"-"`
}

// Predict availability using ML model
func predictAvailability(slot *ParkingSlot, timestamp time.Time) *AvailabilityPredictionResponse {
	// Call availability prediction API
	url := "http://localhost:5001/api/predict-availability"

	requestBody := map[string]interface{}{
		"city":               slot.City,
		"area":               slot.Area,
		"parking_type":       slot.Type,
		"timestamp":          timestamp.Format(time.RFC3339),
		"is_ev_charging":     slot.IsEVCharging,
		"is_handicap":        slot.IsHandicap,
		"price_per_hour":     slot.PricePerHr,
		"nearby_slots_count": 10,
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		fmt.Printf("Error marshaling request: %v\n", err)
		return nil
	}

	resp, err := http.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		fmt.Printf("Error calling availability API: %v\n", err)
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("Availability API returned status: %d\n", resp.StatusCode)
		return nil
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("Error reading response: %v\n", err)
		return nil
	}

	var prediction AvailabilityPredictionResponse
	if err := json.Unmarshal(body, &prediction); err != nil {
		fmt.Printf("Error unmarshaling response: %v\n", err)
		return nil
	}

	// Calculate confidence level
	if prediction.Confidence >= 0.9 {
		prediction.ConfidenceLevel = "Very High"
	} else if prediction.Confidence >= 0.8 {
		prediction.ConfidenceLevel = "High"
	} else if prediction.Confidence >= 0.7 {
		prediction.ConfidenceLevel = "Medium"
	} else if prediction.Confidence >= 0.6 {
		prediction.ConfidenceLevel = "Low"
	} else {
		prediction.ConfidenceLevel = "Very Low"
	}

	return &prediction
}

// UpdateSlotStatus updates a parking slot's status
func (bg *BipartiteGraph) UpdateSlotStatus(slotID string, status string) error {
	bg.mu.Lock()
	defer bg.mu.Unlock()

	slot := bg.GetSlotByID(slotID)
	if slot == nil {
		return fmt.Errorf("slot not found")
	}

	slot.Status = status
	return nil
}

// GetSlotByID retrieves a parking slot by ID
func (bg *BipartiteGraph) GetSlotByID(slotID string) *ParkingSlot {
	bg.mu.RLock()
	defer bg.mu.RUnlock()

	// Use the parkingSlotsMap for quick lookup
	if slot, exists := bg.parkingSlotsMap[slotID]; exists {
		return slot
	}
	return nil
}

// Register booking routes
func registerBookingRoutes(r *gin.Engine) {
	r.POST("/api/booking/create", createBooking)
	r.GET("/api/booking/:bookingId", getBooking)
	r.GET("/api/booking/user/:userId", getUserBookings)
	r.POST("/api/booking/cancel/:bookingId", cancelBooking)
	r.POST("/api/booking/confirm/:bookingId", confirmBooking)
	r.POST("/api/booking/checkin/:bookingId", checkinBooking)
	r.POST("/api/booking/checkout/:bookingId", checkoutBooking)
}
