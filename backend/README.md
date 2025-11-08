# Volkswagen H3 Backend

A Go backend service using Uber's H3 library for geospatial indexing in an Uber-like application.

## Features

- Convert GPS coordinates to H3 cells
- Find nearby H3 cells for driver search
- Get H3 cell boundaries for map visualization
- RESTful API with CORS support

## Prerequisites

- Go 1.21 or higher
- Internet connection for downloading dependencies

## Installation

1. Install dependencies:
```bash
go mod download
```

## Running the Server

```bash
go run main.go
```

The server will start on `http://localhost:8080`

## API Endpoints

### 1. Health Check
```
GET /health
```

### 2. Get H3 Cell for Location
```
POST /api/location/h3
Content-Type: application/json

{
  "latitude": 37.7749,
  "longitude": -122.4194,
  "resolution": 9
}
```

Response:
```json
{
  "latitude": 37.7749,
  "longitude": -122.4194,
  "h3Index": "8928308280fffff",
  "h3IndexInt": 617700169958293503,
  "resolution": 9,
  "centerLat": 37.77489,
  "centerLng": -122.41940,
  "boundary": [[37.775, -122.419], ...]
}
```

### 3. Get Nearby Cells (for finding drivers)
```
POST /api/location/nearby
Content-Type: application/json

{
  "latitude": 37.7749,
  "longitude": -122.4194,
  "resolution": 9,
  "radius": 2
}
```

Response:
```json
{
  "currentCell": "8928308280fffff",
  "nearbyCells": ["8928308280fffff", "8928308281fffff", ...],
  "totalCells": 19
}
```

### 4. Get H3 Cell Boundary
```
GET /api/h3/boundary/:h3Index
```

## H3 Resolutions

Common resolutions for Uber-like applications:
- Resolution 7: ~5.16 km edge length (city level)
- Resolution 8: ~1.84 km edge length (neighborhood)
- Resolution 9: ~0.69 km edge length (driver dispatch)
- Resolution 10: ~0.26 km edge length (precise location)

## Building for Production

```bash
go build -o backend main.go
./backend
```
