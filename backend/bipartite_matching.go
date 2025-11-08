package main

import (
	"encoding/json"
	"math"
	"os"
	"sort"
	"sync"
	"time"

	"github.com/uber/h3-go/v4"
)

// SearchRequest represents a user's parking search request
type SearchRequest struct {
	ID               string    `json:"id"`
	UserLat          float64   `json:"userLat"`
	UserLng          float64   `json:"userLng"`
	MaxDistance      float64   `json:"maxDistance"`      // in km
	MaxPrice         float64   `json:"maxPrice"`         // max price per hour
	RequiresEV       bool      `json:"requiresEV"`       // needs EV charging
	RequiresHandicap bool      `json:"requiresHandicap"` // needs handicap access
	PreferredTypes   []string  `json:"preferredTypes"`   // preferred parking types
	Timestamp        time.Time `json:"timestamp"`
	Priority         float64   `json:"priority"` // calculated priority score
}

// ParkingMatch represents a matched parking slot for a user
type ParkingMatch struct {
	RequestID   string      `json:"requestId"`
	ParkingSlot ParkingSlot `json:"parkingSlot"`
	Distance    float64     `json:"distance"`   // in km
	Score       float64     `json:"score"`      // matching score
	TravelTime  float64     `json:"travelTime"` // estimated in minutes
	MatchedAt   time.Time   `json:"matchedAt"`
}

// BatchMatchingResult contains results for a batch of requests
type BatchMatchingResult struct {
	Matches        []ParkingMatch `json:"matches"`
	UnmatchedReqs  []string       `json:"unmatchedRequests"`
	ProcessingTime float64        `json:"processingTimeMs"`
	TotalRequests  int            `json:"totalRequests"`
	MatchedCount   int            `json:"matchedCount"`
}

// BipartiteGraph represents the matching system
type BipartiteGraph struct {
	parkingSlots    []ParkingSlot
	parkingSlotsMap map[string]*ParkingSlot // for quick lookup
	h3Index         map[string][]int        // H3 cell to parking slot indices
	mu              sync.RWMutex
	resolution      int // H3 resolution for indexing
}

// NewBipartiteGraph creates a new bipartite matching system
func NewBipartiteGraph(resolution int) *BipartiteGraph {
	return &BipartiteGraph{
		parkingSlots:    make([]ParkingSlot, 0),
		parkingSlotsMap: make(map[string]*ParkingSlot),
		h3Index:         make(map[string][]int),
		resolution:      resolution,
	}
}

// LoadParkingSlots loads parking slots from JSON file
func (bg *BipartiteGraph) LoadParkingSlots(filename string) error {
	bg.mu.Lock()
	defer bg.mu.Unlock()

	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	var cityData map[string][]ParkingSlot
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&cityData); err != nil {
		return err
	}

	// Flatten all cities into single slice
	for _, slots := range cityData {
		for _, slot := range slots {
			// Only add available slots
			if slot.Status == "available" {
				idx := len(bg.parkingSlots)
				bg.parkingSlots = append(bg.parkingSlots, slot)
				bg.parkingSlotsMap[slot.ID] = &bg.parkingSlots[idx]

				// Index by H3 cell
				latLng := h3.NewLatLng(slot.Latitude, slot.Longitude)
				cell := h3.LatLngToCell(latLng, bg.resolution)
				cellStr := cell.String()
				bg.h3Index[cellStr] = append(bg.h3Index[cellStr], idx)
			}
		}
	}

	return nil
}

// FindNearbyParkingSlots finds parking slots within radius using H3
func (bg *BipartiteGraph) FindNearbyParkingSlots(lat, lng, radiusKm float64) []int {
	bg.mu.RLock()
	defer bg.mu.RUnlock()

	// Convert user location to H3 cell
	latLng := h3.NewLatLng(lat, lng)
	centerCell := h3.LatLngToCell(latLng, bg.resolution)

	// Calculate number of rings needed based on radius
	// At resolution 9, edge length is ~174m
	// Each ring adds approximately this distance
	ringCount := int(math.Ceil(radiusKm * 1000 / 174))
	if ringCount < 1 {
		ringCount = 1
	}
	if ringCount > 10 {
		ringCount = 10 // Cap at 10 rings for performance
	}

	// Get all cells within radius
	nearbyCells := h3.GridDisk(centerCell, ringCount)

	// Collect all parking slot indices from nearby cells
	slotIndices := make(map[int]bool)
	for _, cell := range nearbyCells {
		if indices, exists := bg.h3Index[cell.String()]; exists {
			for _, idx := range indices {
				slotIndices[idx] = true
			}
		}
	}

	// Convert to slice
	result := make([]int, 0, len(slotIndices))
	for idx := range slotIndices {
		result = append(result, idx)
	}

	return result
}

// CalculateScore computes matching score based on multiple parameters
func CalculateScore(req SearchRequest, slot ParkingSlot, distance float64) float64 {
	score := 100.0

	// Distance factor (0-40 points) - closer is better
	distanceScore := 40.0 * (1.0 - math.Min(distance/req.MaxDistance, 1.0))
	score += distanceScore

	// Price factor (0-25 points) - cheaper is better
	if slot.PricePerHr <= req.MaxPrice {
		priceScore := 25.0 * (1.0 - slot.PricePerHr/req.MaxPrice)
		score += priceScore
	} else {
		score -= 20.0 // Penalty for exceeding max price
	}

	// EV charging bonus (0-15 points)
	if req.RequiresEV && slot.IsEVCharging {
		score += 15.0
	} else if req.RequiresEV && !slot.IsEVCharging {
		score -= 50.0 // Heavy penalty if required but not available
	}

	// Handicap access bonus (0-15 points)
	if req.RequiresHandicap && slot.IsHandicap {
		score += 15.0
	} else if req.RequiresHandicap && !slot.IsHandicap {
		score -= 50.0 // Heavy penalty if required but not available
	}

	// Parking type preference (0-10 points)
	if len(req.PreferredTypes) > 0 {
		for _, prefType := range req.PreferredTypes {
			if slot.Type == prefType {
				score += 10.0
				break
			}
		}
	}

	// Request priority multiplier
	score *= req.Priority

	return score
}

// HaversineDistance calculates distance between two points in km
func HaversineDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadius = 6371.0 // km

	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLng := (lng2 - lng1) * math.Pi / 180.0

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLng/2)*math.Sin(dLng/2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadius * c
}

// EstimateTravelTime estimates travel time in minutes
func EstimateTravelTime(distanceKm float64) float64 {
	// Assume average speed of 30 km/h in city traffic
	const avgSpeedKmh = 30.0
	return (distanceKm / avgSpeedKmh) * 60.0
}

// MatchCandidate represents a potential match for scoring
type MatchCandidate struct {
	slotIndex int
	distance  float64
	score     float64
}

// FindBestMatch finds the best parking slot for a single request
func (bg *BipartiteGraph) FindBestMatch(req SearchRequest) *ParkingMatch {
	// Find nearby parking slots
	nearbyIndices := bg.FindNearbyParkingSlots(req.UserLat, req.UserLng, req.MaxDistance)

	if len(nearbyIndices) == 0 {
		return nil
	}

	var bestCandidate *MatchCandidate

	// Evaluate each candidate
	for _, idx := range nearbyIndices {
		slot := bg.parkingSlots[idx]

		// Calculate distance
		distance := HaversineDistance(req.UserLat, req.UserLng, slot.Latitude, slot.Longitude)

		// Skip if beyond max distance
		if distance > req.MaxDistance {
			continue
		}

		// Calculate score
		score := CalculateScore(req, slot, distance)

		// Skip if score is too low (e.g., missing required features)
		if score < 0 {
			continue
		}

		// Update best candidate
		if bestCandidate == nil || score > bestCandidate.score {
			bestCandidate = &MatchCandidate{
				slotIndex: idx,
				distance:  distance,
				score:     score,
			}
		}
	}

	if bestCandidate == nil {
		return nil
	}

	// Create match
	slot := bg.parkingSlots[bestCandidate.slotIndex]
	travelTime := EstimateTravelTime(bestCandidate.distance)

	return &ParkingMatch{
		RequestID:   req.ID,
		ParkingSlot: slot,
		Distance:    bestCandidate.distance,
		Score:       bestCandidate.score,
		TravelTime:  travelTime,
		MatchedAt:   time.Now(),
	}
}

// BatchMatch processes multiple requests using bipartite matching
func (bg *BipartiteGraph) BatchMatch(requests []SearchRequest) BatchMatchingResult {
	startTime := time.Now()

	matches := make([]ParkingMatch, 0, len(requests))
	unmatched := make([]string, 0)
	assignedSlots := make(map[string]bool)

	// Sort requests by priority (highest first)
	sort.Slice(requests, func(i, j int) bool {
		return requests[i].Priority > requests[j].Priority
	})

	// Process each request
	for _, req := range requests {
		// Find nearby parking slots
		nearbyIndices := bg.FindNearbyParkingSlots(req.UserLat, req.UserLng, req.MaxDistance)

		var bestMatch *ParkingMatch
		var bestScore float64

		// Evaluate each candidate
		for _, idx := range nearbyIndices {
			slot := bg.parkingSlots[idx]

			// Skip if already assigned
			if assignedSlots[slot.ID] {
				continue
			}

			// Calculate distance
			distance := HaversineDistance(req.UserLat, req.UserLng, slot.Latitude, slot.Longitude)

			// Skip if beyond max distance
			if distance > req.MaxDistance {
				continue
			}

			// Calculate score
			score := CalculateScore(req, slot, distance)

			// Skip if score is too low
			if score < 0 {
				continue
			}

			// Update best match
			if bestMatch == nil || score > bestScore {
				travelTime := EstimateTravelTime(distance)
				bestMatch = &ParkingMatch{
					RequestID:   req.ID,
					ParkingSlot: slot,
					Distance:    distance,
					Score:       score,
					TravelTime:  travelTime,
					MatchedAt:   time.Now(),
				}
				bestScore = score
			}
		}

		if bestMatch != nil {
			matches = append(matches, *bestMatch)
			assignedSlots[bestMatch.ParkingSlot.ID] = true
		} else {
			unmatched = append(unmatched, req.ID)
		}
	}

	processingTime := time.Since(startTime).Milliseconds()

	return BatchMatchingResult{
		Matches:        matches,
		UnmatchedReqs:  unmatched,
		ProcessingTime: float64(processingTime),
		TotalRequests:  len(requests),
		MatchedCount:   len(matches),
	}
}

// MarkSlotAsOccupied marks a parking slot as occupied
func (bg *BipartiteGraph) MarkSlotAsOccupied(slotID string) error {
	bg.mu.Lock()
	defer bg.mu.Unlock()

	if slot, exists := bg.parkingSlotsMap[slotID]; exists {
		slot.Status = "occupied"
		return nil
	}

	return nil
}

// MarkSlotAsAvailable marks a parking slot as available
func (bg *BipartiteGraph) MarkSlotAsAvailable(slotID string) error {
	bg.mu.Lock()
	defer bg.mu.Unlock()

	if slot, exists := bg.parkingSlotsMap[slotID]; exists {
		slot.Status = "available"
		return nil
	}

	return nil
}

// GetAvailableSlotsCount returns count of available slots
func (bg *BipartiteGraph) GetAvailableSlotsCount() int {
	bg.mu.RLock()
	defer bg.mu.RUnlock()

	count := 0
	for _, slot := range bg.parkingSlots {
		if slot.Status == "available" {
			count++
		}
	}
	return count
}
