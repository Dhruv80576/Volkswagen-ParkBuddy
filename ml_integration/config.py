# Dynamic Pricing Configuration

# Model Settings
MODEL_TYPE = "xgboost"  # Options: xgboost, random_forest, gradient_boosting
MODEL_PATH = f"parking_pricing_model_{MODEL_TYPE}.pkl"

# API Settings
API_HOST = "0.0.0.0"
API_PORT = 5000
API_DEBUG = True

# Training Data Settings
TRAINING_DAYS = 365  # Days of historical data to generate
SAMPLES_PER_SLOT = 15  # Samples per parking slot
MAX_SLOTS_PER_CITY = 100  # Max slots to use per city (for manageable data size)

# Price Bounds
MIN_PRICE_MULTIPLIER = 0.5  # Minimum 50% of base price
MAX_PRICE_MULTIPLIER = 3.0  # Maximum 300% of base price

# Feature Engineering
USE_CYCLICAL_TIME_FEATURES = True  # Use sin/cos encoding for time
USE_INTERACTION_FEATURES = True  # Use feature interactions

# Model Hyperparameters (XGBoost)
XGBOOST_PARAMS = {
    'n_estimators': 200,
    'learning_rate': 0.1,
    'max_depth': 7,
    'min_child_weight': 3,
    'gamma': 0.1,
    'subsample': 0.8,
    'colsample_bytree': 0.8,
    'random_state': 42,
    'n_jobs': -1
}

# Random Forest Params
RANDOM_FOREST_PARAMS = {
    'n_estimators': 200,
    'max_depth': 20,
    'min_samples_split': 5,
    'min_samples_leaf': 2,
    'random_state': 42,
    'n_jobs': -1
}

# Gradient Boosting Params
GRADIENT_BOOSTING_PARAMS = {
    'n_estimators': 200,
    'learning_rate': 0.1,
    'max_depth': 7,
    'min_samples_split': 5,
    'random_state': 42
}

# Pricing Multipliers (used in data generation)
TYPE_MULTIPLIERS = {
    'airport': 2.5,
    'commercial': 1.5,
    'mall': 1.8,
    'street': 1.0,
    'residential': 0.8
}

PEAK_HOURS = {
    'morning': (7, 10, 1.4),
    'lunch': (12, 14, 1.2),
    'evening': (17, 20, 1.6),
    'night': (20, 23, 1.3),
    'late_night': (23, 6, 0.7)
}

DAY_OF_WEEK_MULTIPLIERS = {
    0: 1.2,  # Monday
    1: 1.2,  # Tuesday
    2: 1.2,  # Wednesday
    3: 1.2,  # Thursday
    4: 1.5,  # Friday
    5: 1.3,  # Saturday
    6: 0.9   # Sunday
}

SEASON_MULTIPLIERS = {
    'winter': 1.1,
    'spring': 1.0,
    'summer': 1.2,
    'monsoon': 0.9,
    'autumn': 1.0
}

WEATHER_MULTIPLIERS = {
    'clear': 1.0,
    'cloudy': 1.0,
    'rainy': 1.3,
    'stormy': 1.5,
    'foggy': 1.1
}

# Demand Calculation Settings
CITY_DEMAND_BASE = {
    'Mumbai': 75,
    'Delhi': 70,
    'Bangalore': 68,
    'Chennai': 60,
    'Trichy': 45
}

# Logging
ENABLE_PREDICTION_LOGGING = True
LOG_FILE = 'pricing_predictions.log'

# Cache Settings (future enhancement)
ENABLE_CACHE = False
CACHE_TTL = 300  # 5 minutes

# Performance Thresholds
MIN_ACCEPTABLE_R2 = 0.80
MAX_ACCEPTABLE_MAPE = 15.0

# Alerts
ENABLE_PERFORMANCE_ALERTS = True
ALERT_THRESHOLD_R2 = 0.75
