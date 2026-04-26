from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import numpy as np

app = FastAPI(title="FINIXTRA Enterprise AI Engine")

class FraudRequest(BaseModel):
    user_id: str
    amount: float
    device_risk: float
    geo_risk: float
    velocity_risk: float

@app.post("/fraud/risk-score")
def calculate_risk(req: FraudRequest):
    amount_spike = min(req.amount / 10000.0, 1.0) * 0.3 
    
    risk_score = (
        (req.device_risk * 0.3) +
        (req.geo_risk * 0.3) +
        (req.velocity_risk * 0.2) +
        amount_spike
    )
    
    risk_score = round(min(risk_score, 1.0), 3)
    
    action = "ALLOW"
    if risk_score > 0.7:
        action = "BLOCK"
    elif risk_score >= 0.3:
        action = "CHALLENGE_OTP"
        
    return {
        "risk_score": risk_score,
        "action": action,
        "factors": {
            "device": req.device_risk,
            "geo": req.geo_risk,
            "velocity": req.velocity_risk,
            "amount_spike": amount_spike
        }
    }

class PredictionRequest(BaseModel):
    historical_spending: list[float]

@app.post("/analytics/predict-spending")
def predict_spending(req: PredictionRequest):
    if not req.historical_spending:
        return {"predicted_next_month": 0.0}
    
    avg = np.mean(req.historical_spending)
    trend = avg * 1.05
    
    return {
        "predicted_next_month": round(trend, 2),
        "model": "Time-Series Forecasting Engine"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
