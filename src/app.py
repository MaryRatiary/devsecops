from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pickle
import logging
import os

app = FastAPI(title="MLOps API", version="1.0.0")
logger = logging.getLogger(__name__)

model = None

class PredictionRequest(BaseModel):
    features: list

class PredictionResponse(BaseModel):
    prediction: float
    confidence: float

@app.on_event("startup")
async def load_model():
    global model
    model_path = os.getenv("MODEL_PATH", "/app/models/model.pkl")
    try:
        with open(model_path, "rb") as f:
            model = pickle.load(f)
        logger.info(f"Model loaded from {model_path}")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None}

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    try:
        prediction = model.predict([request.features])[0]
        return {"prediction": float(prediction), "confidence": 0.95}
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=400, detail="Prediction failed")
