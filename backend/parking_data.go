package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/uber/h3-go/v4"
)

// ParkingSlot represents a single parking slot
type ParkingSlot struct {
	ID           string  `json:"id"`
	Latitude     float64 `json:"latitude"`
	Longitude    float64 `json:"longitude"`
	H3Index      string  `json:"h3Index"`
	City         string  `json:"city"`
	Area         string  `json:"area"`
	Type         string  `json:"type"`   // street, mall, residential, commercial, airport
	Status       string  `json:"status"` // available, occupied, reserved
	PricePerHr   float64 `json:"pricePerHour"`
	IsEVCharging bool    `json:"isEVCharging"`
	IsHandicap   bool    `json:"isHandicap"`
}

// CityArea defines areas within a city with coordinate bounds
type CityArea struct {
	Name     string
	MinLat   float64
	MaxLat   float64
	MinLng   float64
	MaxLng   float64
	AreaType string
}

// City configuration with multiple areas
var cityConfigs = map[string][]CityArea{
	"Trichy": {
		{Name: "Thillai Nagar", MinLat: 10.790, MaxLat: 10.810, MinLng: 78.680, MaxLng: 78.705, AreaType: "residential"},
		{Name: "Srirangam", MinLat: 10.855, MaxLat: 10.875, MinLng: 78.685, MaxLng: 78.710, AreaType: "religious"},
		{Name: "Anna Nagar", MinLat: 10.805, MaxLat: 10.825, MinLng: 78.685, MaxLng: 78.710, AreaType: "residential"},
		{Name: "Cantonment", MinLat: 10.795, MaxLat: 10.815, MinLng: 78.695, MaxLng: 78.720, AreaType: "commercial"},
		{Name: "K K Nagar", MinLat: 10.780, MaxLat: 10.800, MinLng: 78.695, MaxLng: 78.720, AreaType: "residential"},
		{Name: "Palakarai", MinLat: 10.775, MaxLat: 10.795, MinLng: 78.705, MaxLng: 78.730, AreaType: "commercial"},
		{Name: "Chathiram Bus Stand", MinLat: 10.800, MaxLat: 10.820, MinLng: 78.700, MaxLng: 78.725, AreaType: "commercial"},
		{Name: "Airport Area", MinLat: 10.755, MaxLat: 10.775, MinLng: 78.700, MaxLng: 78.730, AreaType: "airport"},
	},
	"Delhi": {
		{Name: "Connaught Place", MinLat: 28.625, MaxLat: 28.640, MinLng: 77.215, MaxLng: 77.230, AreaType: "commercial"},
		{Name: "Karol Bagh", MinLat: 28.645, MaxLat: 28.660, MinLng: 77.185, MaxLng: 77.200, AreaType: "commercial"},
		{Name: "South Extension", MinLat: 28.565, MaxLat: 28.580, MinLng: 77.215, MaxLng: 77.230, AreaType: "mall"},
		{Name: "Rohini", MinLat: 28.730, MaxLat: 28.750, MinLng: 77.060, MaxLng: 77.085, AreaType: "residential"},
		{Name: "Dwarka", MinLat: 28.580, MaxLat: 28.605, MinLng: 77.030, MaxLng: 77.060, AreaType: "residential"},
		{Name: "Vasant Kunj", MinLat: 28.510, MaxLat: 28.535, MinLng: 77.140, MaxLng: 77.170, AreaType: "residential"},
		{Name: "Saket", MinLat: 28.520, MaxLat: 28.540, MinLng: 77.200, MaxLng: 77.225, AreaType: "mall"},
		{Name: "IGI Airport", MinLat: 28.545, MaxLat: 28.570, MinLng: 77.090, MaxLng: 77.120, AreaType: "airport"},
		{Name: "Nehru Place", MinLat: 28.545, MaxLat: 28.555, MinLng: 77.245, MaxLng: 77.260, AreaType: "commercial"},
		{Name: "Lajpat Nagar", MinLat: 28.560, MaxLat: 28.575, MinLng: 77.235, MaxLng: 77.250, AreaType: "commercial"},
	},
	"Mumbai": {
		{Name: "Bandra", MinLat: 19.050, MaxLat: 19.070, MinLng: 72.825, MaxLng: 72.845, AreaType: "commercial"},
		{Name: "Andheri", MinLat: 19.110, MaxLat: 19.135, MinLng: 72.825, MaxLng: 72.855, AreaType: "residential"},
		{Name: "Worli", MinLat: 19.010, MaxLat: 19.030, MinLng: 72.810, MaxLng: 72.830, AreaType: "commercial"},
		{Name: "Lower Parel", MinLat: 18.995, MaxLat: 19.010, MinLng: 72.825, MaxLng: 72.840, AreaType: "mall"},
		{Name: "Powai", MinLat: 19.110, MaxLat: 19.135, MinLng: 72.890, MaxLng: 72.920, AreaType: "residential"},
		{Name: "Malad", MinLat: 19.175, MaxLat: 19.200, MinLng: 72.835, MaxLng: 72.865, AreaType: "residential"},
		{Name: "Churchgate", MinLat: 18.930, MaxLat: 18.945, MinLng: 72.820, MaxLng: 72.835, AreaType: "commercial"},
		{Name: "BKC", MinLat: 19.055, MaxLat: 19.070, MinLng: 72.860, MaxLng: 72.875, AreaType: "commercial"},
		{Name: "Navi Mumbai", MinLat: 19.030, MaxLat: 19.060, MinLng: 73.000, MaxLng: 73.030, AreaType: "residential"},
		{Name: "Airport", MinLat: 19.085, MaxLat: 19.105, MinLng: 72.865, MaxLng: 72.890, AreaType: "airport"},
	},
	"Bangalore": {
		{Name: "Indiranagar", MinLat: 12.970, MaxLat: 12.985, MinLng: 77.635, MaxLng: 77.650, AreaType: "commercial"},
		{Name: "Koramangala", MinLat: 12.925, MaxLat: 12.945, MinLng: 77.610, MaxLng: 77.635, AreaType: "commercial"},
		{Name: "Whitefield", MinLat: 12.960, MaxLat: 12.985, MinLng: 77.735, MaxLng: 77.765, AreaType: "residential"},
		{Name: "Electronic City", MinLat: 12.835, MaxLat: 12.860, MinLng: 77.660, MaxLng: 77.690, AreaType: "commercial"},
		{Name: "Jayanagar", MinLat: 12.920, MaxLat: 12.940, MinLng: 77.575, MaxLng: 77.600, AreaType: "residential"},
		{Name: "MG Road", MinLat: 12.970, MaxLat: 12.980, MinLng: 77.600, MaxLng: 77.615, AreaType: "commercial"},
		{Name: "Malleshwaram", MinLat: 13.000, MaxLat: 13.020, MinLng: 77.560, MaxLng: 77.580, AreaType: "residential"},
		{Name: "Yeshwanthpur", MinLat: 13.020, MaxLat: 13.040, MinLng: 77.535, MaxLng: 77.560, AreaType: "commercial"},
		{Name: "HSR Layout", MinLat: 12.905, MaxLat: 12.925, MinLng: 77.630, MaxLng: 77.655, AreaType: "residential"},
		{Name: "Airport", MinLat: 13.190, MaxLat: 13.210, MinLng: 77.695, MaxLng: 77.720, AreaType: "airport"},
	},
	"Chennai": {
		{Name: "T Nagar", MinLat: 13.035, MaxLat: 13.050, MinLng: 80.230, MaxLng: 80.250, AreaType: "commercial"},
		{Name: "Anna Nagar", MinLat: 13.080, MaxLat: 13.100, MinLng: 80.200, MaxLng: 80.225, AreaType: "residential"},
		{Name: "Adyar", MinLat: 13.000, MaxLat: 13.020, MinLng: 80.250, MaxLng: 80.270, AreaType: "residential"},
		{Name: "Velachery", MinLat: 12.970, MaxLat: 12.990, MinLng: 80.210, MaxLng: 80.235, AreaType: "residential"},
		{Name: "OMR", MinLat: 12.910, MaxLat: 12.940, MinLng: 80.220, MaxLng: 80.250, AreaType: "commercial"},
		{Name: "Mylapore", MinLat: 13.030, MaxLat: 13.045, MinLng: 80.260, MaxLng: 80.275, AreaType: "residential"},
		{Name: "Nungambakkam", MinLat: 13.055, MaxLat: 13.070, MinLng: 80.235, MaxLng: 80.250, AreaType: "commercial"},
		{Name: "Porur", MinLat: 13.030, MaxLat: 13.050, MinLng: 80.145, MaxLng: 80.170, AreaType: "mall"},
		{Name: "Guindy", MinLat: 13.005, MaxLat: 13.020, MinLng: 80.210, MaxLng: 80.230, AreaType: "commercial"},
		{Name: "Airport", MinLat: 12.980, MaxLat: 13.000, MinLng: 80.165, MaxLng: 80.185, AreaType: "airport"},
	},
}

// Generate parking slots for a city
func generateParkingSlotsForCity(city string, areas []CityArea, count int) []ParkingSlot {
	slots := make([]ParkingSlot, 0, count)
	rand.Seed(time.Now().UnixNano())

	slotsPerArea := count / len(areas)
	remainder := count % len(areas)

	for areaIdx, area := range areas {
		areaSlots := slotsPerArea
		if areaIdx == 0 {
			areaSlots += remainder
		}

		for i := 0; i < areaSlots; i++ {
			// Generate random location within area bounds
			lat := area.MinLat + rand.Float64()*(area.MaxLat-area.MinLat)
			lng := area.MinLng + rand.Float64()*(area.MaxLng-area.MinLng)

			// Calculate H3 index at resolution 9 (~174m hexagons)
			latLng := h3.NewLatLng(lat, lng)
			cell := h3.LatLngToCell(latLng, 9)

			// Generate slot ID
			slotID := fmt.Sprintf("%s-%s-%05d", city, area.Name, i+1)

			// Determine parking type based on area type
			parkingType := determineParkingType(area.AreaType)

			// Generate status (70% available, 25% occupied, 5% reserved)
			status := generateStatus()

			// Price varies by area type
			price := generatePrice(area.AreaType)

			// 15% chance of EV charging
			isEV := rand.Float32() < 0.15

			// 5% chance of handicap parking
			isHandicap := rand.Float32() < 0.05

			slot := ParkingSlot{
				ID:           slotID,
				Latitude:     lat,
				Longitude:    lng,
				H3Index:      cell.String(),
				City:         city,
				Area:         area.Name,
				Type:         parkingType,
				Status:       status,
				PricePerHr:   price,
				IsEVCharging: isEV,
				IsHandicap:   isHandicap,
			}

			slots = append(slots, slot)
		}
	}

	return slots
}

func determineParkingType(areaType string) string {
	types := map[string][]string{
		"commercial":  {"street", "commercial", "commercial", "street"},
		"residential": {"residential", "street", "residential"},
		"mall":        {"mall", "mall", "commercial"},
		"airport":     {"airport", "airport", "commercial"},
		"religious":   {"street", "commercial"},
	}

	options := types[areaType]
	if options == nil {
		options = []string{"street", "commercial"}
	}

	return options[rand.Intn(len(options))]
}

func generateStatus() string {
	r := rand.Float32()
	if r < 0.70 {
		return "available"
	} else if r < 0.95 {
		return "occupied"
	}
	return "reserved"
}

func generatePrice(areaType string) float64 {
	basePrices := map[string]float64{
		"commercial":  50.0,
		"residential": 20.0,
		"mall":        40.0,
		"airport":     80.0,
		"religious":   30.0,
	}

	base := basePrices[areaType]
	if base == 0 {
		base = 30.0
	}

	// Add random variation ±30%
	variation := base * 0.3 * (rand.Float64()*2 - 1)
	return base + variation
}

// GenerateAllParkingData generates parking data for all cities
func GenerateAllParkingData() map[string][]ParkingSlot {
	allData := make(map[string][]ParkingSlot)

	for city, areas := range cityConfigs {
		fmt.Printf("Generating parking slots for %s...\n", city)
		slots := generateParkingSlotsForCity(city, areas, 10000)
		allData[city] = slots
		fmt.Printf("Generated %d parking slots for %s\n", len(slots), city)
	}

	return allData
}

// SaveParkingDataToFile saves parking data to a JSON file
func SaveParkingDataToFile(data map[string][]ParkingSlot, filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	return encoder.Encode(data)
}

// SaveParkingDataByCityToFiles saves each city's data to separate files
func SaveParkingDataByCityToFiles(data map[string][]ParkingSlot, directory string) error {
	// Create directory if it doesn't exist
	if err := os.MkdirAll(directory, 0755); err != nil {
		return err
	}

	for city, slots := range data {
		filename := fmt.Sprintf("%s/%s_parking_slots.json", directory, city)
		file, err := os.Create(filename)
		if err != nil {
			return err
		}

		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(slots); err != nil {
			file.Close()
			return err
		}
		file.Close()

		fmt.Printf("Saved %d slots to %s\n", len(slots), filename)
	}

	return nil
}
