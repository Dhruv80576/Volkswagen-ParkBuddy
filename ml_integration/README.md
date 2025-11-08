# Dynamic Parking Pricing - ML Model

A machine learning-based dynamic pricing system for parking slots that predicts optimal prices based on demand, time, location, weather, and other factors.

## 🎯 Overview

This ML model provides intelligent, real-time pricing for parking slots by analyzing:
- **Temporal Factors**: Hour of day, day of week, season, peak hours
- **Location Factors**: City, area type, parking type (street, mall, commercial, airport, residential)
- **Demand Factors**: Historical requests, occupancy rate, demand score
- **Environmental Factors**: Weather conditions, special events
- **Amenities**: EV charging availability, handicap accessibility

## 📊 Model Architecture

The system uses **XGBoost Regressor** (default) with the following features:
- **200 estimators** for robust predictions
- **Gradient boosting** for handling non-linear relationships
- **Feature importance analysis** for interpretability
- **Cross-validation** for reliable performance

Alternative models available:
- Random Forest Regressor (baseline)
- Gradient Boosting Regressor (alternative)

## 🚀 Quick Start

### 1. Install Dependencies

```powershell
cd ml_pricing
pip install -r requirements.txt
```

### 2. Generate Training Data

```powershell
python data_generator.py
```

This generates synthetic historical data (~75,000+ samples) based on your parking slots.

**Output**: `parking_pricing_training_data.csv`

### 3. Train the Model

```powershell
python train_model.py
```

This trains and compares multiple models, automatically selecting the best performer.

**Outputs**:
- `parking_pricing_model_xgboost.pkl` (trained model)
- `parking_pricing_model_xgboost_metadata.json` (performance metrics)
- `pricing_model_xgboost_performance.png` (visualizations)

**Expected Performance**:
- **R² Score**: ~0.85-0.92 (excellent predictive power)
- **RMSE**: ₹2-4 (low prediction error)
- **MAPE**: 5-10% (high accuracy)

### 4. Start the Pricing API

```powershell
python pricing_api.py
```

API runs on: `http://localhost:5000`

## 🔌 API Endpoints

### 1. Health Check
```bash
GET /health
```

**Response**:
```json
{
  "status": "healthy",
  "service": "dynamic-pricing-api",
  "model_loaded": true,
  "model_type": "xgboost"
}
```

### 2. Predict Price (Single)
```bash
POST /api/predict-price
Content-Type: application/json

{
  "city": "Mumbai",
  "area": "Bandra",
  "parking_type": "commercial",
  "base_price": 25.0,
  "is_ev_charging": true,
  "is_handicap": false,
  "demand_score": 75.5,
  "occupancy_rate": 0.8,
  "weather": "clear",
  "is_event": false
}
```

**Response**:
```json
{
  "predicted_price": 45.67,
  "base_price": 25.0,
  "price_multiplier": 1.83,
  "confidence": "high",
  "timestamp": "2025-11-04T18:30:00",
  "features_used": {
    "city": "Mumbai",
    "parking_type": "commercial",
    "hour": 18,
    "demand_score": 75.5,
    "occupancy_rate": 0.8
  }
}
```

### 3. Batch Predict (Multiple Slots)
```bash
POST /api/batch-predict
Content-Type: application/json

{
  "slots": [
    {
      "slot_id": "Mumbai-Bandra-001",
      "city": "Mumbai",
      "parking_type": "commercial",
      "base_price": 25.0
    },
    {
      "slot_id": "Delhi-CP-042",
      "city": "Delhi",
      "parking_type": "commercial",
      "base_price": 30.0
    }
  ],
  "common_features": {
    "weather": "rainy",
    "is_event": true
  }
}
```

### 4. Calculate Demand Score
```bash
POST /api/calculate-demand
Content-Type: application/json

{
  "city": "Mumbai",
  "parking_type": "commercial",
  "available_slots": 50,
  "total_slots": 200,
  "recent_requests": 75
}
```

**Response**:
```json
{
  "demand_score": 78.5,
  "occupancy_rate": 0.75,
  "demand_level": "high"
}
```

### 5. Model Information
```bash
GET /api/model-info
```

## 🔗 Integration with Go Backend

### Option 1: Direct Integration

Add to your `main.go`:

```go
import (
    // ... existing imports
)

var pricingClient *PricingAPIClient

func main() {
    // Initialize pricing client
    pricingClient = NewPricingAPIClient("http://localhost:5000")
    
    // Check health
    healthy, err := pricingClient.HealthCheck()
    if err != nil {
        fmt.Printf("Warning: Pricing API not available: %v\n", err)
    } else {
        fmt.Printf("✓ Dynamic pricing enabled\n")
    }
    
    // ... rest of your code
}
```

### Option 2: Add Dynamic Pricing Endpoint

Add this endpoint to your Go backend:

```go
// Get dynamic price for a slot
r.GET("/api/parking/dynamic-price/:slotId", func(c *gin.Context) {
    slotId := c.Param("slotId")
    
    // Find slot
    slot := bipartiteGraph.FindSlotByID(slotId)
    if slot == nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Slot not found"})
        return
    }
    
    // Calculate demand
    demandReq := DemandCalculationRequest{
        City:           slot.City,
        ParkingType:    slot.Type,
        AvailableSlots: bipartiteGraph.GetAvailableSlotsCount(),
        TotalSlots:     bipartiteGraph.GetTotalSlotsCount(),
        RecentRequests: getRecentRequestCount(), // Implement this
    }
    
    demandResp, _ := pricingClient.CalculateDemand(demandReq)
    
    // Get dynamic price
    price, err := pricingClient.GetDynamicPriceForSlot(
        slot, 
        demandResp.DemandScore, 
        demandResp.OccupancyRate,
    )
    
    if err != nil {
        c.JSON(http.StatusOK, gin.H{
            "slot_id": slotId,
            "base_price": slot.PricePerHr,
            "dynamic_price": slot.PricePerHr, // Fallback
            "status": "using_base_price"
        })
        return
    }
    
    c.JSON(http.StatusOK, gin.H{
        "slot_id": slotId,
        "base_price": slot.PricePerHr,
        "dynamic_price": price,
        "demand_score": demandResp.DemandScore,
        "status": "dynamic_pricing_enabled"
    })
})
```

### Option 3: Auto-Update Prices Periodically

```go
// Background goroutine to update prices every 15 minutes
go func() {
    ticker := time.NewTicker(15 * time.Minute)
    defer ticker.Stop()
    
    for range ticker.C {
        updateAllDynamicPrices()
    }
}()

func updateAllDynamicPrices() {
    // Get demand metrics
    demandReq := DemandCalculationRequest{
        City:           "Mumbai", // Or iterate per city
        ParkingType:    "commercial",
        AvailableSlots: bipartiteGraph.GetAvailableSlotsCount(),
        TotalSlots:     bipartiteGraph.GetTotalSlotsCount(),
        RecentRequests: getRecentRequestCount(),
    }
    
    demandResp, err := pricingClient.CalculateDemand(demandReq)
    if err != nil {
        return
    }
    
    // Update prices for all available slots
    for _, slot := range bipartiteGraph.GetAvailableSlots() {
        price, err := pricingClient.GetDynamicPriceForSlot(
            slot,
            demandResp.DemandScore,
            demandResp.OccupancyRate,
        )
        if err == nil {
            slot.PricePerHr = price // Update in-memory price
        }
    }
}
```

## 📱 Frontend Integration (Flutter)

Update your Flutter app to display dynamic pricing:

```dart
// In your parking search results
class ParkingSlotCard extends StatelessWidget {
  final ParkingSlot slot;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // ... existing slot info
          
          // Price display with dynamic indicator
          Row(
            children: [
              if (slot.dynamicPrice != null && 
                  slot.dynamicPrice != slot.basePrice) ...[
                Text(
                  '₹${slot.basePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '₹${slot.dynamicPrice.toStringAsFixed(2)}/hr',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getPriceColor(slot),
                  ),
                ),
                Icon(
                  Icons.trending_up,
                  size: 16,
                  color: Colors.orange,
                ),
              ] else
                Text('₹${slot.basePrice.toStringAsFixed(2)}/hr'),
            ],
          ),
          
          // Demand indicator
          if (slot.demandLevel != null)
            Chip(
              label: Text('${slot.demandLevel} demand'),
              backgroundColor: _getDemandColor(slot.demandLevel),
            ),
        ],
      ),
    );
  }
  
  Color _getPriceColor(ParkingSlot slot) {
    double multiplier = slot.dynamicPrice! / slot.basePrice;
    if (multiplier > 1.5) return Colors.red;
    if (multiplier > 1.2) return Colors.orange;
    if (multiplier < 0.8) return Colors.green;
    return Colors.black;
  }
}
```

## 📈 Model Performance

### Training Results (Expected)

| Metric | Value |
|--------|-------|
| Test R² | 0.88-0.92 |
| Test RMSE | ₹2.5-4.0 |
| Test MAE | ₹1.8-3.2 |
| Test MAPE | 5-10% |

### Feature Importance (Top 10)

1. **demand_score** (25-30%) - Most influential
2. **occupancy_rate** (15-20%)
3. **base_price** (12-15%)
4. **demand_occupancy_interaction** (8-10%)
5. **hour_sin/cos** (6-8%)
6. **parking_type_encoded** (5-7%)
7. **city_encoded** (4-6%)
8. **is_event** (3-5%)
9. **weather_encoded** (2-4%)
10. **is_ev_charging** (2-3%)

## 🔧 Customization

### Adjust Price Ranges

Edit `data_generator.py`:

```python
# Line ~180: Adjust multipliers
self.type_multipliers = {
    'airport': 2.5,      # Change to 3.0 for higher airport prices
    'commercial': 1.5,   # Adjust as needed
    'mall': 1.8,
    'street': 1.0,
    'residential': 0.8
}

# Line ~270: Adjust max price cap
dynamic_price = min(dynamic_price, base_price * 3.0)  # Max 300% of base
```

### Retrain with More Data

```powershell
# Generate more samples
python data_generator.py  # Edit days=365 to days=730 for 2 years

# Retrain
python train_model.py
```

### Add New Features

Edit `train_model.py` to add custom features:

```python
# In prepare_features() method, add:
if 'proximity_to_metro' in df.columns:
    df['metro_nearby'] = (df['proximity_to_metro'] < 500).astype(int)

# Add to feature_cols:
feature_cols.append('metro_nearby')
```

## 🧪 Testing

### Test the API

```powershell
# Test prediction
curl -X POST http://localhost:5000/api/predict-price `
  -H "Content-Type: application/json" `
  -d '{\"city\":\"Mumbai\",\"parking_type\":\"commercial\",\"base_price\":25.0,\"demand_score\":75,\"occupancy_rate\":0.8}'

# Test demand calculation
curl -X POST http://localhost:5000/api/calculate-demand `
  -H "Content-Type: application/json" `
  -d '{\"city\":\"Mumbai\",\"parking_type\":\"commercial\",\"available_slots\":50,\"total_slots\":200,\"recent_requests\":75}'
```

### Test Go Integration

Create `backend/test_pricing.go`:

```go
package main

import (
    "fmt"
)

func main() {
    exampleUsage()
}
```

Run: `go run pricing_client.go test_pricing.go`

## 📊 Monitoring & Analytics

### Track Pricing Performance

Log predictions for analysis:

```python
# Add to pricing_api.py
import logging

logging.basicConfig(
    filename='pricing_predictions.log',
    level=logging.INFO,
    format='%(asctime)s,%(message)s'
)

# In predict_price():
logging.info(f"{features['city']},{features['parking_type']},{base_price},{predicted_price},{features['demand_score']}")
```

### Analyze Pricing Trends

```python
import pandas as pd

# Load logs
df = pd.read_csv('pricing_predictions.log', 
                 names=['timestamp', 'city', 'type', 'base', 'predicted', 'demand'])

# Analyze
print(df.groupby('city')['predicted'].mean())
print(df.groupby(['city', 'type'])['predicted'].describe())
```

## 🔄 Model Updates

### Periodic Retraining

1. **Collect actual booking data** with realized prices
2. **Append to training data**:
   ```python
   new_data = pd.read_csv('actual_bookings.csv')
   old_data = pd.read_csv('parking_pricing_training_data.csv')
   combined = pd.concat([old_data, new_data])
   combined.to_csv('parking_pricing_training_data.csv', index=False)
   ```
3. **Retrain**: `python train_model.py`
4. **Deploy**: Replace the `.pkl` file and restart API

### A/B Testing

Run two models simultaneously:
```python
model_a = PricingModel.load_model('model_v1.pkl')
model_b = PricingModel.load_model('model_v2.pkl')

# Route 50% to each
import random
if random.random() < 0.5:
    prediction = model_a.predict(data)
else:
    prediction = model_b.predict(data)
```

## 🚨 Troubleshooting

### Model Not Loading
```
ERROR: Model file not found
```
**Solution**: Run `python train_model.py` first

### Low Accuracy
**Solutions**:
- Generate more training data: Edit `days=365` to `days=730`
- Add more features: Edit `prepare_features()` in `train_model.py`
- Try different model: Use `'gradient_boosting'` instead of `'xgboost'`

### API Connection Failed
```
Connection refused on port 5000
```
**Solutions**:
- Ensure Flask is running: `python pricing_api.py`
- Check firewall settings
- Update Go client URL if API is on different host

## 📚 Next Steps

1. **Deploy to Production**: Use Gunicorn/uWSGI for Flask
   ```bash
   pip install gunicorn
   gunicorn -w 4 -b 0.0.0.0:5000 pricing_api:app
   ```

2. **Add Caching**: Use Redis to cache predictions
   ```python
   import redis
   cache = redis.Redis(host='localhost', port=6379)
   ```

3. **Scale with Docker**:
   ```dockerfile
   FROM python:3.9
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . .
   CMD ["python", "pricing_api.py"]
   ```

4. **Monitor Performance**: Add Prometheus metrics
   ```python
   from prometheus_client import Counter, Histogram
   prediction_counter = Counter('predictions_total', 'Total predictions')
   ```

## 📞 Support

For issues or questions:
- Check logs: `pricing_predictions.log`
- Review model performance: Check `.png` files
- Test API health: `curl http://localhost:5000/health`

---

**Created for Volkswagen Hackathon Parking System**
