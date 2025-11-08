"""
Availability Prediction API

Flask API to serve availability predictions along with pricing.
Integrates with the existing pricing API.
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import joblib
import os
import traceback


app = Flask(__name__)
CORS(app)

# Load models
AVAILABILITY_MODEL_PATH = 'parking_availability_model.pkl'
availability_model = None


def load_availability_model():
    """Load the availability prediction model."""
    global availability_model
    
    if not os.path.exists(AVAILABILITY_MODEL_PATH):
        print(f"ERROR: Availability model not found: {AVAILABILITY_MODEL_PATH}")
        print("Please train the model first by running: python availability_model.py")
        return False
    
    try:
        model_data = joblib.load(AVAILABILITY_MODEL_PATH)
        availability_model = {
            'predictor': model_data['model'],
            'label_encoders': model_data['label_encoders'],
            'feature_columns': model_data['feature_columns'],
            'metadata': model_data.get('metadata', {})
        }
        
        print(f"✓ Availability model loaded successfully")
        print(f"✓ Test Accuracy: {availability_model['metadata'].get('performance_metrics', {}).get('test_accuracy', 'unknown')}")
        
        return True
    except Exception as e:
        print(f"ERROR loading availability model: {e}")
        traceback.print_exc()
        return False


def extract_time_features(timestamp):
    """Extract time-based features from timestamp."""
    return {
        'hour': timestamp.hour,
        'day_of_week': timestamp.weekday(),
        'day_of_month': timestamp.day,
        'month': timestamp.month,
        'is_weekend': int(timestamp.weekday() >= 5),
        'is_peak_morning': int(7 <= timestamp.hour <= 10),
        'is_peak_evening': int(17 <= timestamp.hour <= 20),
        'is_peak_hour': int((7 <= timestamp.hour <= 10) or (17 <= timestamp.hour <= 20)),
        'is_business_hours': int(9 <= timestamp.hour <= 18),
        'is_night': int(timestamp.hour >= 22 or timestamp.hour <= 5),
        'season': get_season(timestamp.month),
        'time_category': get_time_category(timestamp.hour)
    }


def get_season(month):
    """Get season from month."""
    if month in [12, 1, 2]:
        return 'winter'
    elif month in [3, 4, 5]:
        return 'spring'
    elif month in [6, 7, 8]:
        return 'summer'
    else:
        return 'fall'


def get_time_category(hour):
    """Categorize time of day."""
    if 0 <= hour < 6:
        return 'late_night'
    elif 6 <= hour < 12:
        return 'morning'
    elif 12 <= hour < 17:
        return 'afternoon'
    elif 17 <= hour < 21:
        return 'evening'
    else:
        return 'night'


def simulate_occupancy(features):
    """Simulate historical occupancy based on features."""
    base_occupancy = 0.5
    
    if features['is_peak_hour']:
        base_occupancy += 0.3
    
    if features['is_business_hours']:
        base_occupancy += 0.15
    
    if features['is_weekend']:
        if features['parking_type'] == 'mall':
            base_occupancy += 0.2
        elif features['parking_type'] == 'commercial':
            base_occupancy -= 0.2
    
    if features['parking_type'] == 'airport':
        base_occupancy += 0.25
    elif features['parking_type'] == 'residential':
        if features['is_night']:
            base_occupancy += 0.3
    
    return min(max(base_occupancy + np.random.normal(0, 0.05), 0), 1)


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'service': 'availability-prediction-api',
        'availability_model_loaded': availability_model is not None
    })


@app.route('/api/predict-availability', methods=['POST'])
def predict_availability():
    """
    Predict parking availability at a specific time.
    
    Request body:
    {
        "city": "Mumbai",
        "area": "Bandra",
        "parking_type": "commercial",
        "timestamp": "2025-11-07T14:30:00",  // Optional, defaults to now
        "is_ev_charging": true,
        "is_handicap": false,
        "price_per_hour": 25.0,
        "nearby_slots_count": 15
    }
    """
    try:
        if availability_model is None:
            return jsonify({
                'error': 'Availability model not loaded',
                'message': 'Please train the model first'
            }), 503
        
        data = request.get_json()
        
        # Parse timestamp
        if 'timestamp' in data and data['timestamp']:
            timestamp = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
        else:
            timestamp = datetime.now()
        
        # Extract time features
        features = extract_time_features(timestamp)
        
        # Add location features
        features['city'] = data.get('city', 'Unknown')
        features['area'] = data.get('area', 'Unknown')
        features['parking_type'] = data.get('parking_type', 'street')
        features['is_ev_charging'] = int(data.get('is_ev_charging', False))
        features['is_handicap'] = int(data.get('is_handicap', False))
        features['price_per_hour'] = float(data.get('price_per_hour', 20.0))
        features['nearby_slots_count'] = int(data.get('nearby_slots_count', 10))
        features['historical_occupancy'] = simulate_occupancy(features)
        
        # Prepare DataFrame
        X = pd.DataFrame([features])
        
        # Encode categorical features
        categorical_features = ['city', 'area', 'parking_type', 'season', 'time_category']
        
        for feature in categorical_features:
            if feature in X.columns:
                le = availability_model['label_encoders'][feature]
                try:
                    X[feature + '_encoded'] = le.transform(X[feature].astype(str))
                except ValueError:
                    X[feature + '_encoded'] = 0
                X = X.drop(feature, axis=1)
        
        # Create cyclical features
        X['hour_sin'] = np.sin(2 * np.pi * X['hour'] / 24)
        X['hour_cos'] = np.cos(2 * np.pi * X['hour'] / 24)
        X['dow_sin'] = np.sin(2 * np.pi * X['day_of_week'] / 7)
        X['dow_cos'] = np.cos(2 * np.pi * X['day_of_week'] / 7)
        X['month_sin'] = np.sin(2 * np.pi * X['month'] / 12)
        X['month_cos'] = np.cos(2 * np.pi * X['month'] / 12)
        
        # Ensure same features as training
        for col in availability_model['feature_columns']:
            if col not in X.columns:
                X[col] = 0
        
        X = X[availability_model['feature_columns']]
        
        # Predict
        prediction = availability_model['predictor'].predict(X)[0]
        probability = availability_model['predictor'].predict_proba(X)[0]
        
        return jsonify({
            'success': True,
            'is_available': bool(prediction),
            'availability_probability': float(probability[1]),
            'occupancy_probability': float(probability[0]),
            'confidence': float(max(probability)),
            'prediction_time': timestamp.isoformat(),
            'features_used': {
                'city': data.get('city'),
                'area': data.get('area'),
                'parking_type': data.get('parking_type'),
                'hour': timestamp.hour,
                'day_of_week': timestamp.strftime('%A'),
                'is_weekend': bool(features['is_weekend']),
                'is_peak_hour': bool(features['is_peak_hour'])
            }
        })
        
    except Exception as e:
        print(f"Error in availability prediction: {e}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/batch-predict-availability', methods=['POST'])
def batch_predict_availability():
    """
    Predict availability for multiple slots/times.
    
    Request body:
    {
        "predictions": [
            {
                "city": "Mumbai",
                "area": "Bandra",
                "parking_type": "commercial",
                "timestamp": "2025-11-07T14:30:00",
                ...
            },
            ...
        ]
    }
    """
    try:
        if availability_model is None:
            return jsonify({
                'error': 'Availability model not loaded'
            }), 503
        
        data = request.get_json()
        predictions_request = data.get('predictions', [])
        
        if not predictions_request:
            return jsonify({
                'error': 'No predictions requested'
            }), 400
        
        results = []
        
        for req in predictions_request:
            # Parse timestamp
            if 'timestamp' in req and req['timestamp']:
                timestamp = datetime.fromisoformat(req['timestamp'].replace('Z', '+00:00'))
            else:
                timestamp = datetime.now()
            
            # Extract time features
            features = extract_time_features(timestamp)
            
            # Add location features
            features['city'] = req.get('city', 'Unknown')
            features['area'] = req.get('area', 'Unknown')
            features['parking_type'] = req.get('parking_type', 'street')
            features['is_ev_charging'] = int(req.get('is_ev_charging', False))
            features['is_handicap'] = int(req.get('is_handicap', False))
            features['price_per_hour'] = float(req.get('price_per_hour', 20.0))
            features['nearby_slots_count'] = int(req.get('nearby_slots_count', 10))
            features['historical_occupancy'] = simulate_occupancy(features)
            
            # Prepare DataFrame
            X = pd.DataFrame([features])
            
            # Encode categorical features
            categorical_features = ['city', 'area', 'parking_type', 'season', 'time_category']
            
            for feature in categorical_features:
                if feature in X.columns:
                    le = availability_model['label_encoders'][feature]
                    try:
                        X[feature + '_encoded'] = le.transform(X[feature].astype(str))
                    except ValueError:
                        X[feature + '_encoded'] = 0
                    X = X.drop(feature, axis=1)
            
            # Create cyclical features
            X['hour_sin'] = np.sin(2 * np.pi * X['hour'] / 24)
            X['hour_cos'] = np.cos(2 * np.pi * X['hour'] / 24)
            X['dow_sin'] = np.sin(2 * np.pi * X['day_of_week'] / 7)
            X['dow_cos'] = np.cos(2 * np.pi * X['day_of_week'] / 7)
            X['month_sin'] = np.sin(2 * np.pi * X['month'] / 12)
            X['month_cos'] = np.cos(2 * np.pi * X['month'] / 12)
            
            # Ensure same features as training
            for col in availability_model['feature_columns']:
                if col not in X.columns:
                    X[col] = 0
            
            X = X[availability_model['feature_columns']]
            
            # Predict
            prediction = availability_model['predictor'].predict(X)[0]
            probability = availability_model['predictor'].predict_proba(X)[0]
            
            results.append({
                'slot_id': req.get('slot_id'),
                'is_available': bool(prediction),
                'availability_probability': float(probability[1]),
                'confidence': float(max(probability))
            })
        
        return jsonify({
            'success': True,
            'predictions': results,
            'count': len(results)
        })
        
    except Exception as e:
        print(f"Error in batch availability prediction: {e}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    print("="*60)
    print("Parking Availability Prediction API")
    print("="*60)
    
    # Load model
    if load_availability_model():
        print("\n✓ Starting API server on http://localhost:5001")
        app.run(host='0.0.0.0', port=5001, debug=True)
    else:
        print("\n✗ Failed to load model. Please train the model first.")
        print("Run: python availability_model.py")
