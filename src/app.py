from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import logging
import os
import pickle

app = FastAPI(title="MLOps API", version="1.0.0")
logger = logging.getLogger(__name__)


class FallbackModel:
    """Petit modèle de secours pour rendre l'API testable sans artefact model.pkl."""

    def predict(self, rows):
        predictions = []
        for features in rows:
            if not features:
                raise ValueError("features cannot be empty")
            predictions.append(sum(float(x) for x in features) / len(features))
        return predictions


model = FallbackModel()
model_loaded_from_file = False


class PredictionRequest(BaseModel):
    features: list[float]


class PredictionResponse(BaseModel):
    prediction: float
    confidence: float


@app.on_event("startup")
async def load_model():
    global model, model_loaded_from_file
    model_path = os.getenv("MODEL_PATH", "/app/models/model.pkl")
    if not os.path.exists(model_path):
        logger.warning("Model file not found at %s, using fallback model", model_path)
        return
    try:
        with open(model_path, "rb") as f:
            model = pickle.load(f)
        model_loaded_from_file = True
        logger.info("Model loaded from %s", model_path)
    except Exception as exc:
        logger.warning("Failed to load model %s, using fallback model: %s", model_path, exc)


@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None, "model_loaded_from_file": model_loaded_from_file}


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    if not request.features:
        raise HTTPException(status_code=422, detail="features cannot be empty")
    try:
        prediction = model.predict([request.features])[0]
        return {"prediction": float(prediction), "confidence": 0.95 if model_loaded_from_file else 0.50}
    except Exception as exc:
        logger.error("Prediction error: %s", exc)
        raise HTTPException(status_code=400, detail="Prediction failed") from exc
