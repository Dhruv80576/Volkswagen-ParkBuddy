"""
Parking Availability Prediction Model

ML model to predict parking slot availability at a specific time and location.
Uses historical patterns, time features, and location characteristics.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import joblib
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, f1_score
from sklearn.preprocessing import LabelEncoder
import json
import warnings
warnings.filterwarnings('ignore')


class AvailabilityPredictor:
    """Predicts parking slot availability based on time and location features."""
    
    def __init__(self):
        self.model = None
        self.label_encoders = {}
        self.feature_columns = []
        self.metadata = {}
    
    def generate_training_data(self, parking_slots_file='parking_slots_all.json', num_samples=50000):
        """
        Generate synthetic training data based on parking slots.
        
        Args:
            parking_slots_file: Path to parking slots JSON file
            num_samples: Number of training samples to generate
        
        Returns:
            DataFrame with training data
        """
        print(f"Generating {num_samples} training samples...")
        
        # Load parking slots
        try:
            with open(parking_slots_file, 'r') as f:
                data = json.load(f)
                if isinstance(data, dict) and 'slots' in data:
                    parking_slots = data['slots']
                else:
                    parking_slots = data
        except FileNotFoundError:
            print(f"Warning: {parking_slots_file} not found. Using default parking data.")
            parking_slots = self._get_default_parking_data()
        
        samples = []
        
        for _ in range(num_samples):
            # Select random parking slot
            slot = np.random.choice(parking_slots)
            
            # Generate random timestamp (past 6 months)
            days_ago = np.random.randint(0, 180)
            hour = np.random.randint(0, 24)
            minute = np.random.randint(0, 60)
            
            timestamp = datetime.now() - timedelta(days=days_ago, hours=hour, minutes=minute)
            
            # Extract time features
            features = self._extract_time_features(timestamp)
            
            # Add location features
            features['city'] = slot.get('city', 'Unknown')
            features['area'] = slot.get('area', 'Unknown')
            features['parking_type'] = slot.get('type', 'street')
            features['is_ev_charging'] = int(slot.get('isEVCharging', False))
            features['is_handicap'] = int(slot.get('isHandicap', False))
            
            # Add historical demand pattern (simulated)
            features['historical_occupancy'] = self._simulate_occupancy(features)
            features['nearby_slots_count'] = np.random.randint(5, 50)
            features['price_per_hour'] = slot.get('pricePerHour', 20.0)
            
            # Target: availability (1 = available, 0 = occupied)
            # Higher probability of being occupied during peak hours
            availability_prob = self._calculate_availability_probability(features)
            features['is_available'] = int(np.random.random() > availability_prob)
            
            samples.append(features)
        
        df = pd.DataFrame(samples)
        print(f"Generated {len(df)} samples")
        return df
    
    def _extract_time_features(self, timestamp):
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
            'season': self._get_season(timestamp.month),
            'time_category': self._get_time_category(timestamp.hour)
        }
    
    def _get_season(self, month):
        """Get season from month."""
        if month in [12, 1, 2]:
            return 'winter'
        elif month in [3, 4, 5]:
            return 'spring'
        elif month in [6, 7, 8]:
            return 'summer'
        else:
            return 'fall'
    
    def _get_time_category(self, hour):
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
    
    def _simulate_occupancy(self, features):
        """Simulate historical occupancy based on features."""
        base_occupancy = 0.5
        
        # Peak hours increase occupancy
        if features['is_peak_hour']:
            base_occupancy += 0.3
        
        # Business hours
        if features['is_business_hours']:
            base_occupancy += 0.15
        
        # Weekend patterns
        if features['is_weekend']:
            if features['parking_type'] == 'mall':
                base_occupancy += 0.2
            elif features['parking_type'] == 'commercial':
                base_occupancy -= 0.2
        
        # Type-specific patterns
        if features['parking_type'] == 'airport':
            base_occupancy += 0.25
        elif features['parking_type'] == 'residential':
            if features['is_night']:
                base_occupancy += 0.3
        
        return min(max(base_occupancy + np.random.normal(0, 0.1), 0), 1)
    
    def _calculate_availability_probability(self, features):
        """Calculate probability that a slot is occupied (inverse of availability)."""
        # Start with historical occupancy
        occupancy_prob = features['historical_occupancy']
        
        # Adjust based on specific conditions
        if features['is_ev_charging']:
            occupancy_prob *= 0.85  # EV slots slightly less utilized
        
        if features['is_handicap']:
            occupancy_prob *= 0.7  # Handicap slots less utilized
        
        # Random variation
        occupancy_prob += np.random.normal(0, 0.05)
        
        return min(max(occupancy_prob, 0), 1)
    
    def _get_default_parking_data(self):
        """Default parking data if file not found."""
        cities = ['Mumbai', 'Delhi', 'Bangalore', 'Chennai']
        areas = ['Downtown', 'Suburb', 'Airport', 'Mall']
        types = ['street', 'commercial', 'mall', 'airport', 'residential']
        
        slots = []
        for i in range(100):
            slots.append({
                'id': f'SLOT-{i:04d}',
                'city': np.random.choice(cities),
                'area': np.random.choice(areas),
                'type': np.random.choice(types),
                'pricePerHour': np.random.uniform(10, 50),
                'isEVCharging': np.random.random() > 0.7,
                'isHandicap': np.random.random() > 0.9
            })
        return slots
    
    def train(self, data, test_size=0.2, random_state=42):
        """
        Train the availability prediction model.
        
        Args:
            data: DataFrame with training data
            test_size: Proportion of data for testing
            random_state: Random seed
        
        Returns:
            Dictionary with performance metrics
        """
        print("Training availability prediction model...")
        
        # Prepare features
        feature_cols = [col for col in data.columns if col != 'is_available']
        X = data[feature_cols].copy()
        y = data['is_available']
        
        # Encode categorical features
        categorical_features = ['city', 'area', 'parking_type', 'season', 'time_category']
        
        for feature in categorical_features:
            if feature in X.columns:
                le = LabelEncoder()
                X[feature + '_encoded'] = le.fit_transform(X[feature].astype(str))
                self.label_encoders[feature] = le
                X = X.drop(feature, axis=1)
        
        # Create cyclical features
        X['hour_sin'] = np.sin(2 * np.pi * X['hour'] / 24)
        X['hour_cos'] = np.cos(2 * np.pi * X['hour'] / 24)
        X['dow_sin'] = np.sin(2 * np.pi * X['day_of_week'] / 7)
        X['dow_cos'] = np.cos(2 * np.pi * X['day_of_week'] / 7)
        X['month_sin'] = np.sin(2 * np.pi * X['month'] / 12)
        X['month_cos'] = np.cos(2 * np.pi * X['month'] / 12)
        
        self.feature_columns = X.columns.tolist()
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state, stratify=y
        )
        
        # Train Gradient Boosting Classifier
        print("Training Gradient Boosting Classifier...")
        self.model = GradientBoostingClassifier(
            n_estimators=200,
            learning_rate=0.1,
            max_depth=5,
            random_state=random_state,
            verbose=0
        )
        
        self.model.fit(X_train, y_train)
        
        # Evaluate
        y_pred_train = self.model.predict(X_train)
        y_pred_test = self.model.predict(X_test)
        
        train_accuracy = accuracy_score(y_train, y_pred_train)
        test_accuracy = accuracy_score(y_test, y_pred_test)
        
        train_f1 = f1_score(y_train, y_pred_train)
        test_f1 = f1_score(y_test, y_pred_test)
        
        # Cross-validation
        cv_scores = cross_val_score(self.model, X_train, y_train, cv=5, scoring='accuracy')
        
        metrics = {
            'train_accuracy': float(train_accuracy),
            'test_accuracy': float(test_accuracy),
            'train_f1': float(train_f1),
            'test_f1': float(test_f1),
            'cv_mean_accuracy': float(cv_scores.mean()),
            'cv_std_accuracy': float(cv_scores.std())
        }
        
        print(f"\n{'='*50}")
        print(f"Model Performance:")
        print(f"{'='*50}")
        print(f"Training Accuracy:   {train_accuracy:.4f}")
        print(f"Testing Accuracy:    {test_accuracy:.4f}")
        print(f"Training F1 Score:   {train_f1:.4f}")
        print(f"Testing F1 Score:    {test_f1:.4f}")
        print(f"CV Accuracy:         {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")
        print(f"{'='*50}\n")
        
        # Classification report
        print("Classification Report (Test Set):")
        print(classification_report(y_test, y_pred_test, 
                                   target_names=['Occupied', 'Available']))
        
        self.metadata = {
            'model_type': 'gradient_boosting_classifier',
            'trained_at': datetime.now().isoformat(),
            'n_samples': len(data),
            'n_features': len(self.feature_columns),
            'performance_metrics': metrics
        }
        
        return metrics
    
    def predict_availability(self, city, area, parking_type, timestamp,
                           is_ev_charging=False, is_handicap=False,
                           price_per_hour=20.0, nearby_slots_count=10):
        """
        Predict availability for a parking slot at a specific time.
        
        Args:
            city: City name
            area: Area name
            parking_type: Type of parking (street, commercial, mall, etc.)
            timestamp: DateTime object for prediction
            is_ev_charging: Whether slot has EV charging
            is_handicap: Whether slot is handicap accessible
            price_per_hour: Base price per hour
            nearby_slots_count: Number of nearby slots
        
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained. Call train() first.")
        
        # Extract time features
        features = self._extract_time_features(timestamp)
        
        # Add location features
        features['city'] = city
        features['area'] = area
        features['parking_type'] = parking_type
        features['is_ev_charging'] = int(is_ev_charging)
        features['is_handicap'] = int(is_handicap)
        features['price_per_hour'] = price_per_hour
        features['nearby_slots_count'] = nearby_slots_count
        
        # Estimate historical occupancy
        features['historical_occupancy'] = self._simulate_occupancy(features)
        
        # Prepare features for prediction
        X = pd.DataFrame([features])
        
        # Encode categorical features
        categorical_features = ['city', 'area', 'parking_type', 'season', 'time_category']
        
        for feature in categorical_features:
            if feature in X.columns:
                le = self.label_encoders[feature]
                # Handle unseen categories
                try:
                    X[feature + '_encoded'] = le.transform(X[feature].astype(str))
                except ValueError:
                    # Use most common category if unseen
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
        for col in self.feature_columns:
            if col not in X.columns:
                X[col] = 0
        
        X = X[self.feature_columns]
        
        # Predict
        prediction = self.model.predict(X)[0]
        probability = self.model.predict_proba(X)[0]
        
        return {
            'is_available': bool(prediction),
            'availability_probability': float(probability[1]),
            'occupancy_probability': float(probability[0]),
            'confidence': float(max(probability)),
            'prediction_time': timestamp.isoformat()
        }
    
    def save(self, filepath='parking_availability_model.pkl'):
        """Save the trained model."""
        model_data = {
            'model': self.model,
            'label_encoders': self.label_encoders,
            'feature_columns': self.feature_columns,
            'metadata': self.metadata
        }
        joblib.dump(model_data, filepath)
        print(f"Model saved to {filepath}")
    
    def load(self, filepath='parking_availability_model.pkl'):
        """Load a trained model."""
        model_data = joblib.load(filepath)
        self.model = model_data['model']
        self.label_encoders = model_data['label_encoders']
        self.feature_columns = model_data['feature_columns']
        self.metadata = model_data.get('metadata', {})
        print(f"Model loaded from {filepath}")


def main():
    """Train and save the availability prediction model."""
    print("="*60)
    print("Parking Availability Prediction Model - Training")
    print("="*60)
    
    predictor = AvailabilityPredictor()
    
    # Generate training data
    data = predictor.generate_training_data(num_samples=50000)
    
    # Save training data
    data.to_csv('parking_availability_training_data.csv', index=False)
    print(f"Training data saved to parking_availability_training_data.csv")
    
    # Train model
    metrics = predictor.train(data)
    
    # Save model
    predictor.save()
    
    # Save metadata
    with open('parking_availability_model_metadata.json', 'w') as f:
        json.dump(predictor.metadata, f, indent=2)
    print(f"Metadata saved to parking_availability_model_metadata.json")
    
    # Test prediction
    print("\n" + "="*60)
    print("Testing Prediction")
    print("="*60)
    
    test_time = datetime.now() + timedelta(hours=2)
    result = predictor.predict_availability(
        city='Mumbai',
        area='Bandra',
        parking_type='commercial',
        timestamp=test_time,
        is_ev_charging=True,
        is_handicap=False
    )
    
    print(f"\nPrediction for {test_time.strftime('%Y-%m-%d %H:%M')}:")
    print(f"  Is Available: {result['is_available']}")
    print(f"  Availability Probability: {result['availability_probability']:.2%}")
    print(f"  Confidence: {result['confidence']:.2%}")
    
    print("\n✓ Model training complete!")


if __name__ == '__main__':
    main()
