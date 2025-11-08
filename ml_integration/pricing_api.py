"""
Dynamic Pricing Prediction API

Flask API to serve the ML model for real-time price predictions.
This API integrates with the Go backend.
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import numpy as np
from datetime import datetime
import joblib
import os
import traceback


app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Load the trained model
MODEL_PATH = 'parking_pricing_model_xgboost.pkl'  # Using XGBoost as default
model = None
model_metadata = None


def load_model():
    """Load the trained model at startup."""
    global model, model_metadata
    
    if not os.path.exists(MODEL_PATH):
        print(f"ERROR: Model file not found: {MODEL_PATH}")
        print("Please train the model first by running: python train_model.py")
        return False
    
    try:
        model_data = joblib.load(MODEL_PATH)
        model = {
            'predictor': model_data['model'],
            'label_encoders': model_data['label_encoders'],
            'scaler': model_data['scaler'],
            'feature_columns': model_data['feature_columns'],
            'metadata': model_data.get('metadata', {})
        }
        model_metadata = model.get('metadata', {})
        
        print(f"✓ Model loaded successfully: {MODEL_PATH}")
        print(f"✓ Model type: {model_metadata.get('model_type', 'unknown')}")
        print(f"✓ Trained at: {model_metadata.get('trained_at', 'unknown')}")
        print(f"✓ Test R²: {model_metadata.get('performance_metrics', {}).get('test_r2', 'unknown')}")
        
        return True
    except Exception as e:
        print(f"ERROR loading model: {e}")
        traceback.print_exc()
        return False


def prepare_features(data, is_training=False):
    """
    Prepare features for prediction (same as training).
    
    Args:
        data: Dictionary or DataFrame with input features
        is_training: Always False for API predictions
    """
    if isinstance(data, dict):
        df = pd.DataFrame([data])
    else:
        df = data.copy()
    
    # Encode categorical features
    categorical_features = ['city', 'parking_type', 'season', 'time_category', 'weather', 'area']
    
    for feature in categorical_features:
        if feature in df.columns:
            le = model['label_encoders'][feature]
            # Handle unseen categories
            df[feature + '_encoded'] = df[feature].apply(
                lambda x: le.transform([str(x)])[0] if str(x) in le.classes_ else -1
            )
    
    # Create time-based cyclical features
    if 'hour' in df.columns:
        df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
        df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
    
    if 'day_of_week' in df.columns:
        df['dow_sin'] = np.sin(2 * np.pi * df['day_of_week'] / 7)
        df['dow_cos'] = np.cos(2 * np.pi * df['day_of_week'] / 7)
    
    if 'month' in df.columns:
        df['month_sin'] = np.sin(2 * np.pi * df['month'] / 12)
        df['month_cos'] = np.cos(2 * np.pi * df['month'] / 12)
    
    # Feature engineering
    if 'demand_score' in df.columns and 'occupancy_rate' in df.columns:
        df['demand_occupancy_interaction'] = df['demand_score'] * df['occupancy_rate']
    
    if 'is_weekend' in df.columns and 'hour' in df.columns:
        df['weekend_evening'] = df['is_weekend'] * (df['hour'] >= 17).astype(int) * (df['hour'] <= 22).astype(int)
    
    # Select only the features used in training
    feature_cols = model['feature_columns']
    
    # Ensure all required features exist
    for col in feature_cols:
        if col not in df.columns:
            df[col] = 0  # Default value for missing features
    
    return df[feature_cols]


def get_current_features(data):
    """
    Extract and compute current features from input data.
    Auto-fills time-based features if not provided.
    """
    now = datetime.now()
    
    # Default values
    defaults = {
        'hour': now.hour,
        'day_of_week': now.weekday(),
        'month': now.month,
        'is_weekend': 1 if now.weekday() >= 5 else 0,
        'season': get_season(now.month),
        'weather': 'clear',
        'is_event': 0,
        'demand_score': 50,  # Will be updated by backend
        'occupancy_rate': 0.5,  # Will be updated by backend
        'is_ev_charging': 0,
        'is_handicap': 0,
        'base_price': 20
    }
    
    # Merge with provided data
    features = {**defaults, **data}
    
    # Calculate time category
    hour = features['hour']
    if 6 <= hour < 12:
        features['time_category'] = 'morning'
    elif 12 <= hour < 17:
        features['time_category'] = 'afternoon'
    elif 17 <= hour < 21:
        features['time_category'] = 'evening'
    else:
        features['time_category'] = 'night'
    
    return features


def get_season(month):
    """Determine season from month."""
    if month in [12, 1, 2]:
        return 'winter'
    elif month in [3, 4, 5]:
        return 'spring'
    elif month in [6, 7, 8]:
        return 'monsoon'
    elif month in [9, 10, 11]:
        return 'autumn'
    return 'summer'


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    if model is None:
        return jsonify({
            'status': 'unhealthy',
            'message': 'Model not loaded'
        }), 503
    
    return jsonify({
        'status': 'healthy',
        'service': 'dynamic-pricing-api',
        'model_loaded': True,
        'model_type': model_metadata.get('model_type', 'unknown')
    })


@app.route('/api/predict-price', methods=['POST'])
def predict_price():
    """
    Predict dynamic price for a parking slot.
    
    Request body:
    {
        "city": "Mumbai",
        "area": "Bandra",
        "parking_type": "commercial",
        "base_price": 25.0,
        "is_ev_charging": true,
        "is_handicap": false,
        "demand_score": 75.5,  // optional, default 50
        "occupancy_rate": 0.8,  // optional, default 0.5
        "weather": "clear",  // optional
        "is_event": false,  // optional
        "hour": 18,  // optional, uses current time
        "day_of_week": 4,  // optional, uses current day
        "month": 11  // optional, uses current month
    }
    
    Response:
    {
        "predicted_price": 45.67,
        "base_price": 25.0,
        "price_multiplier": 1.83,
        "confidence": "high",
        "factors": {
            "demand_impact": 0.4,
            "time_impact": 0.3,
            ...
        }
    }
    """
    try:
        if model is None:
            return jsonify({'error': 'Model not loaded'}), 503
        
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Required fields
        required_fields = ['city', 'parking_type', 'base_price']
        missing_fields = [f for f in required_fields if f not in data]
        
        if missing_fields:
            return jsonify({
                'error': f'Missing required fields: {", ".join(missing_fields)}'
            }), 400
        
        # Get complete features with defaults
        features = get_current_features(data)
        
        # Prepare features for model
        X = prepare_features(features)
        
        # Make prediction
        predicted_price = model['predictor'].predict(X)[0]
        
        # Calculate multiplier
        base_price = features['base_price']
        price_multiplier = predicted_price / base_price if base_price > 0 else 1.0
        
        # Determine confidence (based on typical price ranges)
        if 0.5 <= price_multiplier <= 2.5:
            confidence = 'high'
        elif 0.3 <= price_multiplier <= 3.0:
            confidence = 'medium'
        else:
            confidence = 'low'
        
        # Response
        response = {
            'predicted_price': round(predicted_price, 2),
            'base_price': round(base_price, 2),
            'price_multiplier': round(price_multiplier, 2),
            'confidence': confidence,
            'timestamp': datetime.now().isoformat(),
            'features_used': {
                'city': features['city'],
                'parking_type': features['parking_type'],
                'hour': features['hour'],
                'day_of_week': features['day_of_week'],
                'season': features['season'],
                'demand_score': features['demand_score'],
                'occupancy_rate': features['occupancy_rate'],
                'weather': features['weather'],
                'is_event': features['is_event']
            }
        }
        
        return jsonify(response)
    
    except Exception as e:
        print(f"Error in prediction: {e}")
        traceback.print_exc()
        return jsonify({
            'error': 'Prediction failed',
            'message': str(e)
        }), 500


@app.route('/api/batch-predict', methods=['POST'])
def batch_predict():
    """
    Predict prices for multiple parking slots.
    
    Request body:
    {
        "slots": [
            {
                "slot_id": "Mumbai-Bandra-001",
                "city": "Mumbai",
                "parking_type": "commercial",
                "base_price": 25.0,
                ...
            },
            ...
        ],
        "common_features": {  // optional, applied to all slots
            "weather": "rainy",
            "is_event": true
        }
    }
    """
    try:
        if model is None:
            return jsonify({'error': 'Model not loaded'}), 503
        
        data = request.get_json()
        
        if not data or 'slots' not in data:
            return jsonify({'error': 'No slots provided'}), 400
        
        slots = data['slots']
        common_features = data.get('common_features', {})
        
        predictions = []
        
        for slot in slots:
            # Merge slot data with common features
            slot_features = {**slot, **common_features}
            
            # Get complete features
            features = get_current_features(slot_features)
            
            # Prepare and predict
            X = prepare_features(features)
            predicted_price = model['predictor'].predict(X)[0]
            
            base_price = features['base_price']
            price_multiplier = predicted_price / base_price if base_price > 0 else 1.0
            
            predictions.append({
                'slot_id': slot.get('slot_id', 'unknown'),
                'predicted_price': round(predicted_price, 2),
                'base_price': round(base_price, 2),
                'price_multiplier': round(price_multiplier, 2)
            })
        
        return jsonify({
            'predictions': predictions,
            'total_slots': len(predictions),
            'timestamp': datetime.now().isoformat()
        })
    
    except Exception as e:
        print(f"Error in batch prediction: {e}")
        traceback.print_exc()
        return jsonify({
            'error': 'Batch prediction failed',
            'message': str(e)
        }), 500


@app.route('/api/model-info', methods=['GET'])
def model_info():
    """Get information about the loaded model."""
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 503
    
    return jsonify({
        'model_type': model_metadata.get('model_type', 'unknown'),
        'trained_at': model_metadata.get('trained_at', 'unknown'),
        'training_samples': model_metadata.get('training_samples', 0),
        'performance_metrics': model_metadata.get('performance_metrics', {}),
        'features': model['feature_columns']
    })


@app.route('/api/calculate-demand', methods=['POST'])
def calculate_demand():
    """
    Helper endpoint to calculate demand score based on current conditions.
    This can be called by the Go backend before requesting a price prediction.
    
    Request:
    {
        "city": "Mumbai",
        "parking_type": "commercial",
        "available_slots": 50,
        "total_slots": 200,
        "recent_requests": 75,  // requests in last hour
        "hour": 18,
        "day_of_week": 4
    }
    """
    try:
        data = request.get_json()
        
        # Base demand from occupancy
        available = data.get('available_slots', 100)
        total = data.get('total_slots', 200)
        occupancy_rate = 1 - (available / total) if total > 0 else 0.5
        
        # Demand from recent requests
        recent_requests = data.get('recent_requests', 0)
        
        # Calculate base demand score
        demand_score = (occupancy_rate * 60) + (min(recent_requests, 50) * 0.8)
        
        # Adjust for time and location
        hour = data.get('hour', datetime.now().hour)
        city = data.get('city', 'Mumbai')
        parking_type = data.get('parking_type', 'street')
        
        # Peak hour multiplier
        if 7 <= hour < 10 or 17 <= hour < 20:
            demand_score *= 1.3
        elif 12 <= hour < 14:
            demand_score *= 1.1
        
        # City multiplier
        city_multipliers = {
            'Mumbai': 1.2,
            'Delhi': 1.15,
            'Bangalore': 1.1,
            'Chennai': 1.0,
            'Trichy': 0.9
        }
        demand_score *= city_multipliers.get(city, 1.0)
        
        # Parking type multiplier
        type_multipliers = {
            'airport': 1.3,
            'commercial': 1.2,
            'mall': 1.2,
            'street': 1.0,
            'residential': 0.8
        }
        demand_score *= type_multipliers.get(parking_type, 1.0)
        
        # Clamp between 0 and 100
        demand_score = min(max(demand_score, 0), 100)
        
        return jsonify({
            'demand_score': round(demand_score, 2),
            'occupancy_rate': round(occupancy_rate, 2),
            'demand_level': 'high' if demand_score > 70 else 'medium' if demand_score > 40 else 'low'
        })
    
    except Exception as e:
        print(f"Error calculating demand: {e}")
        return jsonify({
            'error': 'Demand calculation failed',
            'message': str(e)
        }), 500


if __name__ == '__main__':
    print("="*70)
    print("DYNAMIC PARKING PRICING API")
    print("="*70)
    print()
    
    # Load model at startup
    if not load_model():
        print("\n❌ Failed to load model. Exiting...")
        exit(1)
    
    print("\n" + "="*70)
    print("Starting Flask server on http://localhost:5000")
    print("="*70)
    print("\nAvailable endpoints:")
    print("  GET  /health                  - Health check")
    print("  POST /api/predict-price       - Single price prediction")
    print("  POST /api/batch-predict       - Batch price predictions")
    print("  POST /api/calculate-demand    - Calculate demand score")
    print("  GET  /api/model-info          - Model information")
    print("\n")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
