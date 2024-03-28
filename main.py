from fastapi import FastAPI, HTTPException, Depends, status
from pydantic import BaseModel, Field
from typing import Optional
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
    symbol: str
    account_number: int
    sl_pips: Optional[float]
    sl_price: Optional[float]
    tp_pips: Optional[float]
    tp_price: Optional[float]


class Signal(BaseModel):
    signal_type: SignalType
    sl_points: int


@app.get("/health-checker")
async def health_checker():
    return {"message": "Server Running..."}


@app.get("/tradingview-alert/signal/{user_code}/")
async def get_tradingview_alert(user_code: str, db: Session = Depends(get_db)):
    alert = db.query(TradingviewAlertSignal).filter(
        TradingviewAlertSignal.user_access.has(user_code=user_code),
        TradingviewAlertSignal.alert_taken == False
    ).first()
    
    if not alert:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=False)
    
    alert.alert_taken = True
    db.commit()
    return {
        'detail': True,
        'signal_type': alert.signal_type,
        'sl_points': alert.sl_points
    }


@app.post("/tradingview-alert/signal/")
async def create_tradingview_alert(alert_data: TradingviewAlertRequest, db: Session = Depends(get_db)):
    user_code = alert_data.user_code
    signal_type = alert_data.signal_type
    symbol = alert_data.symbol
    account_number = alert_data.account_number
    sl_pips = alert_data.sl_pips
    sl_price = alert_data.sl_price
    tp_pips = alert_data.sl_pips
    tp_price = alert_data.sl_price

    # First validate either sl_pips or sl_price is passed
    if (not sl_pips and not sl_price):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Debe proveer un Stop Loss ya sea en pips o en precio'
        )
    
    # Validate that sl_pips, sl_price, tp_pips and tp_price are number
    # and not negative
    for field in [sl_pips, sl_price, tp_pips, tp_price]:
        if field:
            try:
                value = float(field)
                if value < 0:
                    raise ValueError('No se permiten valores negativos')
            except ValueError as e:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"{str(e)} no es un número válido"
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
    alert.sl_pips = sl_pips
    alert.alert_taken = False
    db.commit()

    return {'message': 'Datos almacenados exitosamente'}
