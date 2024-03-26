from fastapi import FastAPI, HTTPException, Depends, status
from pydantic import BaseModel
from enum import Enum
from sqlalchemy.orm import Session
from models import TradingviewAlertSignal, Status
from database import SessionLocal

app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class SignalType(str, Enum):
    BUY = "BUY"
    SELL = "SELL"


class TradingviewAlertRequest(BaseModel):
    user_code: str
    signal_type: str
    sl_points: int


class Signal(BaseModel):
    signal_type: SignalType
    sl_points: int


@app.get("/health-checker")
async def health_checker():
    return {"message": "Server Running..."}


@app.get("/tradingview-alert/signal/{user_code}/")
async def get_tradingview_alert(user_code: str, db: Session = Depends(get_db)):
    alert = db.query(TradingviewAlertSignal).filter(
        TradingviewAlertSignal.user_access.has(user_code=user_code)
    ).first()
    
    if not alert:
        raise HTTPException(status_code=404, detail="Código de usuario no es válido o no existe alerta")
    
    return {
        'signal_type': alert.signal_type,
        'sl_points': alert.sl_points
    }


@app.post("/tradingview-alert/signal/")
async def create_tradingview_alert(alert_data: TradingviewAlertRequest, db: Session = Depends(get_db)):
    user_code = alert_data.user_code
    signal_type = alert_data.signal_type
    sl_points = alert_data.sl_points

    if not all([user_code, signal_type, sl_points]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Parámetros faltantes'
        )

    # Validate user_code exists
    active_status = db.query(Status).filter_by(status='active').first()
    if not active_status:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='No se pudo encontrar un estado activo'
        )

    alert = db.query(TradingviewAlertSignal).filter(
        TradingviewAlertSignal.user_access.has(user_code=user_code),
        TradingviewAlertSignal.status == active_status
    ).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='El código de usuario no es válido'
        )

    alert.signal_type = signal_type
    alert.sl_points = sl_points
    db.commit()

    return {'message': 'Datos almacenados exitosamente'}