package main

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/uber/h3-go/v4"
)

// Global bipartite graph instance
var bipartiteGraph *BipartiteGraph

type LocationRequest struct {
	Latitude   float64 `json:"latitude" binding:"required"`
	Longitude  float64 `json:"longitude" binding:"required"`
	Resolution int     `json:"resolution"`
}

type LocationResponse struct {
	Latitude   float64     `json:"latitude"`
	Longitude  float64     `json:"longitude"`
	H3Index    string      `json:"h3Index"`
	H3IndexInt uint64      `json:"h3IndexInt"`
	Resolution int         `json:"resolution"`
	CenterLat  float64     `json:"centerLat"`
	CenterLng  float64     `json:"centerLng"`
	Boundary   [][]float64 `json:"boundary"`
}

type NearbyDriversRequest struct {
	Latitude   float64 `json:"latitude" binding:"required"`
	Longitude  float64 `json:"longitude" binding:"required"`
	Resolution int     `json:"resolution"`
	Radius     int     `json:"radius"` // Number of rings to search
}

type NearbyDriversResponse struct {
	CurrentCell string   `json:"currentCell"`
	NearbyCells []string `json:"nearbyCells"`
	TotalCells  int      `json:"totalCells"`
}

func main() {
	// Initialize bipartite graph with resolution 9 (~174m hexagons)
	bipartiteGraph = NewBipartiteGraph(9)

	// Load parking data
	fmt.Println("Loading parking slots...")
	if err := bipartiteGraph.LoadParkingSlots("parking_slots_all.json"); err != nil {
		fmt.Printf("Warning: Could not load parking data: %v\n", err)
	} else {
		availableCount := bipartiteGraph.GetAvailableSlotsCount()
		fmt.Printf("Loaded %d available parking slots\n", availableCount)
	}

	r := gin.Default()

	// Configure CORS
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization"}
	r.Use(cors.New(config))

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "volkswagen-h3-backend",
		})
	})

	// Get H3 cell for a location
	r.POST("/api/location/h3", getH3Cell)

	// Get nearby cells for finding drivers
	r.POST("/api/location/nearby", getNearbyDrivers)

	// Get H3 cell boundary
	r.GET("/api/h3/boundary/:h3Index", getH3Boundary)

	// Parking search endpoints
	r.POST("/api/parking/search", searchParkingSlot)
	r.POST("/api/parking/batch-search", batchSearchParkingSlots)
	r.POST("/api/parking/mark-occupied/:slotId", markParkingOccupied)
	r.POST("/api/parking/mark-available/:slotId", markParkingAvailable)
	r.GET("/api/parking/stats", getParkingStats)

	// Booking endpoints
	registerBookingRoutes(r)

	r.Run(":8080")
}

// getH3Cell converts latitude/longitude to H3 index
func getH3Cell(c *gin.Context) {
	var req LocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Default resolution to 9 (approximately 174m hexagon edge length)
	resolution := req.Resolution
	if resolution == 0 {
		resolution = 9
	}

	// Validate resolution (0-15)
	if resolution < 0 || resolution > 15 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Resolution must be between 0 and 15"})
		return
	}

	// Convert lat/lng to H3 cell
	latLng := h3.NewLatLng(req.Latitude, req.Longitude)
	cell := h3.LatLngToCell(latLng, resolution)

	// Get cell center
	center := h3.CellToLatLng(cell)

	// Get cell boundary
	boundary := h3.CellToBoundary(cell)
	boundaryCoords := make([][]float64, len(boundary))
	for i, coord := range boundary {
		boundaryCoords[i] = []float64{coord.Lat, coord.Lng}
	}

	response := LocationResponse{
		Latitude:   req.Latitude,
		Longitude:  req.Longitude,
		H3Index:    cell.String(),
		H3IndexInt: uint64(cell),
		Resolution: resolution,
		CenterLat:  center.Lat,
		CenterLng:  center.Lng,
		Boundary:   boundaryCoords,
	}

	c.JSON(http.StatusOK, response)
}

// getNearbyDrivers finds nearby H3 cells for driver search
func getNearbyDrivers(c *gin.Context) {
	var req NearbyDriversRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Default resolution to 9
	resolution := req.Resolution
	if resolution == 0 {
		resolution = 9
	}

	// Default radius to 2 (includes adjacent cells)
	radius := req.Radius
	if radius == 0 {
		radius = 2
	}

	// Get current cell
	latLng := h3.NewLatLng(req.Latitude, req.Longitude)
	cell := h3.LatLngToCell(latLng, resolution)

	// Get grid disk (cells within radius)
	nearbyCells := h3.GridDisk(cell, radius)

	// Convert to strings
	nearbyCellsStr := make([]string, len(nearbyCells))
	for i, c := range nearbyCells {
		nearbyCellsStr[i] = c.String()
	}

	response := NearbyDriversResponse{
		CurrentCell: cell.String(),
		NearbyCells: nearbyCellsStr,
		TotalCells:  len(nearbyCells),
	}

	c.JSON(http.StatusOK, response)
}

// getH3Boundary returns the boundary of an H3 cell
func getH3Boundary(c *gin.Context) {
	h3IndexStr := c.Param("h3Index")

	// Parse H3 index
	cell, err := strconv.ParseUint(h3IndexStr, 10, 64)
	if err != nil {
		// Try parsing as H3 string
		cell, err = strconv.ParseUint(h3IndexStr, 16, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid H3 index"})
			return
		}
	}

	h3Cell := h3.Cell(cell)

	// Get boundary
	boundary := h3.CellToBoundary(h3Cell)
	boundaryCoords := make([][]float64, len(boundary))
	for i, coord := range boundary {
		boundaryCoords[i] = []float64{coord.Lat, coord.Lng}
	}

	// Get center
	center := h3.CellToLatLng(h3Cell)

	c.JSON(http.StatusOK, gin.H{
		"h3Index":  h3IndexStr,
		"center":   []float64{center.Lat, center.Lng},
		"boundary": boundaryCoords,
	})
}

// searchParkingSlot handles single parking search request
func searchParkingSlot(c *gin.Context) {
	var req SearchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set defaults
	if req.ID == "" {
		req.ID = fmt.Sprintf("REQ-%d", time.Now().UnixNano())
	}
	if req.MaxDistance == 0 {
		req.MaxDistance = 5.0 // Default 5km radius
	}
	if req.MaxPrice == 0 {
		req.MaxPrice = 100.0 // Default max price
	}
	if req.Priority == 0 {
		req.Priority = 1.0
	}
	req.Timestamp = time.Now()

	// Find best match
	match := bipartiteGraph.FindBestMatch(req)

	if match == nil {
		c.JSON(http.StatusOK, gin.H{
			"success": false,
			"message": "No available parking slots found matching your criteria",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"match":   match,
	})
}

// batchSearchParkingSlots handles batch parking search requests
func batchSearchParkingSlots(c *gin.Context) {
	var requests []SearchRequest
	if err := c.ShouldBindJSON(&requests); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set defaults for each request
	for i := range requests {
		if requests[i].ID == "" {
			requests[i].ID = fmt.Sprintf("REQ-%d-%d", time.Now().UnixNano(), i)
		}
		if requests[i].MaxDistance == 0 {
			requests[i].MaxDistance = 5.0
		}
		if requests[i].MaxPrice == 0 {
			requests[i].MaxPrice = 100.0
		}
		if requests[i].Priority == 0 {
			requests[i].Priority = 1.0
		}
		requests[i].Timestamp = time.Now()
	}

	// Perform batch matching
	result := bipartiteGraph.BatchMatch(requests)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"result":  result,
	})
}

// markParkingOccupied marks a parking slot as occupied
func markParkingOccupied(c *gin.Context) {
	slotID := c.Param("slotId")

	if err := bipartiteGraph.MarkSlotAsOccupied(slotID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Parking slot %s marked as occupied", slotID),
	})
}

// markParkingAvailable marks a parking slot as available
func markParkingAvailable(c *gin.Context) {
	slotID := c.Param("slotId")

	if err := bipartiteGraph.MarkSlotAsAvailable(slotID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Parking slot %s marked as available", slotID),
	})
}

// getParkingStats returns statistics about parking availability
func getParkingStats(c *gin.Context) {
	availableCount := bipartiteGraph.GetAvailableSlotsCount()

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"availableSlots": availableCount,
		"totalSlots":     len(bipartiteGraph.parkingSlots),
		"timestamp":      time.Now(),
	})
}
