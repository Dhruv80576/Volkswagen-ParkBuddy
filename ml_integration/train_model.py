"""
Dynamic Parking Pricing Model - Training Script

This script trains multiple ML models for parking price prediction:
1. Random Forest Regressor (baseline)
2. Gradient Boosting (XGBoost)
3. Neural Network (for advanced patterns)

The model considers:
- Temporal features (hour, day, season)
- Location features (city, area type, parking type)
- Demand features (historical requests, occupancy)
- Environmental features (weather, events)
- Amenity features (EV charging, handicap)
"""

import pandas as pd
import numpy as np
import joblib
import json
from datetime import datetime
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import xgboost as xgb
import matplotlib.pyplot as plt
import seaborn as sns


class PricingModel:
    def __init__(self):
        """Initialize the pricing model."""
        self.model = None
        self.label_encoders = {}
        self.scaler = StandardScaler()
        self.feature_importance = None
        self.feature_columns = None
        self.model_metadata = {
            'trained_at': None,
            'training_samples': 0,
            'model_type': None,
            'performance_metrics': {}
        }
    
    def prepare_features(self, df, is_training=True):
        """
        Prepare features for the model.
        
        Args:
            df: DataFrame with raw features
            is_training: Whether this is training data (fit encoders) or prediction (transform only)
        """
        df = df.copy()
        
        # Categorical features to encode
        categorical_features = ['city', 'parking_type', 'season', 'time_category', 'weather', 'area']
        
        # Encode categorical features
        for feature in categorical_features:
            if feature in df.columns:
                if is_training:
                    self.label_encoders[feature] = LabelEncoder()
                    df[feature + '_encoded'] = self.label_encoders[feature].fit_transform(df[feature].astype(str))
                else:
                    # Handle unseen categories
                    le = self.label_encoders[feature]
                    df[feature + '_encoded'] = df[feature].apply(
                        lambda x: le.transform([str(x)])[0] if str(x) in le.classes_ else -1
                    )
        
        # Create time-based features
        if 'hour' in df.columns:
            # Cyclical encoding for hour (24-hour cycle)
            df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
            df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
        
        if 'day_of_week' in df.columns:
            # Cyclical encoding for day of week (7-day cycle)
            df['dow_sin'] = np.sin(2 * np.pi * df['day_of_week'] / 7)
            df['dow_cos'] = np.cos(2 * np.pi * df['day_of_week'] / 7)
        
        if 'month' in df.columns:
            # Cyclical encoding for month (12-month cycle)
            df['month_sin'] = np.sin(2 * np.pi * df['month'] / 12)
            df['month_cos'] = np.cos(2 * np.pi * df['month'] / 12)
        
        # Feature engineering: interaction terms
        if 'demand_score' in df.columns and 'occupancy_rate' in df.columns:
            df['demand_occupancy_interaction'] = df['demand_score'] * df['occupancy_rate']
        
        if 'is_weekend' in df.columns and 'hour' in df.columns:
            df['weekend_evening'] = df['is_weekend'] * (df['hour'] >= 17).astype(int) * (df['hour'] <= 22).astype(int)
        
        # Select final features for model
        feature_cols = [
            # Encoded categorical
            'city_encoded', 'parking_type_encoded', 'season_encoded', 
            'time_category_encoded', 'weather_encoded', 'area_encoded',
            
            # Temporal features
            'hour_sin', 'hour_cos', 'dow_sin', 'dow_cos', 'month_sin', 'month_cos',
            'is_weekend', 'hour', 'day_of_week', 'month',
            
            # Demand features
            'demand_score', 'occupancy_rate', 'demand_occupancy_interaction',
            
            # Base price and amenities
            'base_price', 'is_ev_charging', 'is_handicap', 'is_event',
            
            # Interaction features
            'weekend_evening'
        ]
        
        # Filter only existing columns
        feature_cols = [col for col in feature_cols if col in df.columns]
        
        if is_training:
            self.feature_columns = feature_cols
        
        return df[feature_cols]
    
    def train(self, df, model_type='xgboost', test_size=0.2):
        """
        Train the pricing model.
        
        Args:
            df: Training data DataFrame
            model_type: 'random_forest', 'gradient_boosting', or 'xgboost'
            test_size: Proportion of data to use for testing
        """
        print(f"\n{'='*60}")
        print(f"TRAINING {model_type.upper()} MODEL")
        print(f"{'='*60}\n")
        
        # Prepare features
        X = self.prepare_features(df, is_training=True)
        y = df['dynamic_price']
        
        print(f"Total samples: {len(X)}")
        print(f"Features: {len(X.columns)}")
        print(f"Feature names: {list(X.columns)}\n")
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=42
        )
        
        print(f"Training samples: {len(X_train)}")
        print(f"Testing samples: {len(X_test)}\n")
        
        # Scale features (optional, but helps some models)
        # X_train_scaled = self.scaler.fit_transform(X_train)
        # X_test_scaled = self.scaler.transform(X_test)
        
        # Train model based on type
        if model_type == 'random_forest':
            print("Training Random Forest...")
            self.model = RandomForestRegressor(
                n_estimators=200,
                max_depth=20,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42,
                n_jobs=-1,
                verbose=1
            )
            self.model.fit(X_train, y_train)
        
        elif model_type == 'gradient_boosting':
            print("Training Gradient Boosting...")
            self.model = GradientBoostingRegressor(
                n_estimators=200,
                learning_rate=0.1,
                max_depth=7,
                min_samples_split=5,
                random_state=42,
                verbose=1
            )
            self.model.fit(X_train, y_train)
        
        elif model_type == 'xgboost':
            print("Training XGBoost...")
            self.model = xgb.XGBRegressor(
                n_estimators=200,
                learning_rate=0.1,
                max_depth=7,
                min_child_weight=3,
                gamma=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                objective='reg:squarederror',
                random_state=42,
                n_jobs=-1,
                verbosity=1
            )
            self.model.fit(X_train, y_train)
        
        else:
            raise ValueError(f"Unknown model type: {model_type}")
        
        # Make predictions
        y_train_pred = self.model.predict(X_train)
        y_test_pred = self.model.predict(X_test)
        
        # Calculate metrics
        train_rmse = np.sqrt(mean_squared_error(y_train, y_train_pred))
        test_rmse = np.sqrt(mean_squared_error(y_test, y_test_pred))
        train_mae = mean_absolute_error(y_train, y_train_pred)
        test_mae = mean_absolute_error(y_test, y_test_pred)
        train_r2 = r2_score(y_train, y_train_pred)
        test_r2 = r2_score(y_test, y_test_pred)
        
        # Calculate MAPE (Mean Absolute Percentage Error)
        train_mape = np.mean(np.abs((y_train - y_train_pred) / y_train)) * 100
        test_mape = np.mean(np.abs((y_test - y_test_pred) / y_test)) * 100
        
        # Store metrics
        self.model_metadata = {
            'trained_at': datetime.now().isoformat(),
            'training_samples': len(X_train),
            'model_type': model_type,
            'performance_metrics': {
                'train_rmse': float(train_rmse),
                'test_rmse': float(test_rmse),
                'train_mae': float(train_mae),
                'test_mae': float(test_mae),
                'train_r2': float(train_r2),
                'test_r2': float(test_r2),
                'train_mape': float(train_mape),
                'test_mape': float(test_mape)
            }
        }
        
        # Print results
        print(f"\n{'='*60}")
        print("MODEL PERFORMANCE")
        print(f"{'='*60}\n")
        print(f"Training Set:")
        print(f"  RMSE: ₹{train_rmse:.2f}")
        print(f"  MAE:  ₹{train_mae:.2f}")
        print(f"  MAPE: {train_mape:.2f}%")
        print(f"  R²:   {train_r2:.4f}")
        print(f"\nTesting Set:")
        print(f"  RMSE: ₹{test_rmse:.2f}")
        print(f"  MAE:  ₹{test_mae:.2f}")
        print(f"  MAPE: {test_mape:.2f}%")
        print(f"  R²:   {test_r2:.4f}\n")
        
        # Feature importance
        if hasattr(self.model, 'feature_importances_'):
            self.feature_importance = pd.DataFrame({
                'feature': X.columns,
                'importance': self.model.feature_importances_
            }).sort_values('importance', ascending=False)
            
            print(f"{'='*60}")
            print("TOP 10 MOST IMPORTANT FEATURES")
            print(f"{'='*60}\n")
            print(self.feature_importance.head(10).to_string(index=False))
            print()
        
        # Create visualization
        self._plot_results(y_test, y_test_pred, model_type)
        
        return self.model_metadata
    
    def _plot_results(self, y_true, y_pred, model_type):
        """Create visualization of model performance."""
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        
        # 1. Actual vs Predicted
        axes[0, 0].scatter(y_true, y_pred, alpha=0.5, s=20)
        axes[0, 0].plot([y_true.min(), y_true.max()], [y_true.min(), y_true.max()], 'r--', lw=2)
        axes[0, 0].set_xlabel('Actual Price (₹)', fontsize=12)
        axes[0, 0].set_ylabel('Predicted Price (₹)', fontsize=12)
        axes[0, 0].set_title('Actual vs Predicted Prices', fontsize=14, fontweight='bold')
        axes[0, 0].grid(True, alpha=0.3)
        
        # 2. Residuals
        residuals = y_true - y_pred
        axes[0, 1].scatter(y_pred, residuals, alpha=0.5, s=20)
        axes[0, 1].axhline(y=0, color='r', linestyle='--', lw=2)
        axes[0, 1].set_xlabel('Predicted Price (₹)', fontsize=12)
        axes[0, 1].set_ylabel('Residuals (₹)', fontsize=12)
        axes[0, 1].set_title('Residual Plot', fontsize=14, fontweight='bold')
        axes[0, 1].grid(True, alpha=0.3)
        
        # 3. Distribution of predictions
        axes[1, 0].hist(y_true, bins=50, alpha=0.5, label='Actual', color='blue')
        axes[1, 0].hist(y_pred, bins=50, alpha=0.5, label='Predicted', color='red')
        axes[1, 0].set_xlabel('Price (₹)', fontsize=12)
        axes[1, 0].set_ylabel('Frequency', fontsize=12)
        axes[1, 0].set_title('Price Distribution', fontsize=14, fontweight='bold')
        axes[1, 0].legend()
        axes[1, 0].grid(True, alpha=0.3)
        
        # 4. Feature importance (top 10)
        if self.feature_importance is not None:
            top_features = self.feature_importance.head(10)
            axes[1, 1].barh(range(len(top_features)), top_features['importance'])
            axes[1, 1].set_yticks(range(len(top_features)))
            axes[1, 1].set_yticklabels(top_features['feature'])
            axes[1, 1].set_xlabel('Importance', fontsize=12)
            axes[1, 1].set_title('Top 10 Feature Importance', fontsize=14, fontweight='bold')
            axes[1, 1].grid(True, alpha=0.3, axis='x')
        
        plt.tight_layout()
        plt.savefig(f'pricing_model_{model_type}_performance.png', dpi=300, bbox_inches='tight')
        print(f"Performance plot saved: pricing_model_{model_type}_performance.png\n")
        plt.close()
    
    def predict(self, input_data):
        """
        Make price predictions for new data.
        
        Args:
            input_data: DataFrame or dict with required features
        """
        if isinstance(input_data, dict):
            input_data = pd.DataFrame([input_data])
        
        # Prepare features
        X = self.prepare_features(input_data, is_training=False)
        
        # Make prediction
        predictions = self.model.predict(X)
        
        return predictions
    
    def save_model(self, filename='parking_pricing_model.pkl'):
        """Save the trained model and preprocessing objects."""
        model_data = {
            'model': self.model,
            'label_encoders': self.label_encoders,
            'scaler': self.scaler,
            'feature_columns': self.feature_columns,
            'feature_importance': self.feature_importance,
            'metadata': self.model_metadata
        }
        
        joblib.dump(model_data, filename)
        print(f"Model saved to: {filename}")
        
        # Save metadata separately as JSON
        metadata_file = filename.replace('.pkl', '_metadata.json')
        with open(metadata_file, 'w') as f:
            json.dump(self.model_metadata, f, indent=2)
        print(f"Metadata saved to: {metadata_file}")
    
    @classmethod
    def load_model(cls, filename='parking_pricing_model.pkl'):
        """Load a trained model."""
        model_data = joblib.load(filename)
        
        instance = cls()
        instance.model = model_data['model']
        instance.label_encoders = model_data['label_encoders']
        instance.scaler = model_data['scaler']
        instance.feature_columns = model_data['feature_columns']
        instance.feature_importance = model_data.get('feature_importance')
        instance.model_metadata = model_data.get('metadata', {})
        
        print(f"Model loaded from: {filename}")
        print(f"Model type: {instance.model_metadata.get('model_type', 'unknown')}")
        print(f"Trained at: {instance.model_metadata.get('trained_at', 'unknown')}")
        
        return instance


def compare_models(df):
    """Train and compare multiple model types."""
    model_types = ['random_forest', 'xgboost', 'gradient_boosting']
    results = {}
    
    for model_type in model_types:
        print(f"\n\n{'#'*70}")
        print(f"# Training {model_type.upper()}")
        print(f"{'#'*70}\n")
        
        model = PricingModel()
        metadata = model.train(df, model_type=model_type)
        model.save_model(f'parking_pricing_model_{model_type}.pkl')
        
        results[model_type] = metadata['performance_metrics']
    
    # Print comparison
    print(f"\n\n{'='*70}")
    print("MODEL COMPARISON")
    print(f"{'='*70}\n")
    
    comparison_df = pd.DataFrame(results).T
    print(comparison_df.to_string())
    print()
    
    # Find best model
    best_model = comparison_df['test_r2'].idxmax()
    print(f"Best model: {best_model.upper()} (Test R² = {comparison_df.loc[best_model, 'test_r2']:.4f})")
    
    return results


if __name__ == "__main__":
    # Load training data
    print("Loading training data...")
    df = pd.read_csv('parking_pricing_training_data.csv')
    
    print(f"Loaded {len(df)} training samples")
    print(f"\nData shape: {df.shape}")
    print(f"Columns: {list(df.columns)}\n")
    
    # Train and compare all models
    results = compare_models(df)
    
    print("\n" + "="*70)
    print("TRAINING COMPLETE!")
    print("="*70)
    print("\nGenerated files:")
    print("  - parking_pricing_model_random_forest.pkl")
    print("  - parking_pricing_model_xgboost.pkl")
    print("  - parking_pricing_model_gradient_boosting.pkl")
    print("  - pricing_model_*_performance.png (visualizations)")
    print("  - parking_pricing_model_*_metadata.json")
