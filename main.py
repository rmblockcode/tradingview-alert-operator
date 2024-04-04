import os
from fastapi import FastAPI, HTTPException, Depends, status
from pydantic import BaseModel, Field
from typing import List
from enum import Enum
from sqlalchemy import func
from sqlalchemy.orm import Session
from models import (
    TradingviewAlertSignal, Status, UserAccess, UserAccessAccount,
    TradingviewAlertGoldLondonSignal)
from database import SessionLocal
from datetime import datetime, date, timedelta


app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class SignalType(str, Enum):
    buy = "buy"
    sell = "sell"


class Trades(BaseModel):
    signal_type: str
    account_number: int
    amount_to_risk: float
    sl_pips: float | None = None
    sl_price: float | None = None
    tp_pips: float | None = None
    tp_price: float | None = None


class TradingviewAlertRequest(BaseModel):
    user_code: str
    symbol: str
    trades: List[Trades]


'''
{
    "timestamp": "{{timenow}}",
    "signal_type": "{{strategy.order.action}}",
    "prices": "{{strategy.order.alert_message}}",
    "open_position": "{{strategy.order.id}}"
}
'''
class TradingviewAlertGoldLondonRequest(BaseModel):
    signal_type: SignalType
    prices: str
    open_position: str
    timestamp: datetime

class Signal(BaseModel):
    signal_type: SignalType
    sl_points: int


@app.get("/health-checker")
async def health_checker():
    return {"message": "Server Running..."}


@app.get("/tradingview-alert/signal/{user_code}/{account_number}/")
async def get_tradingview_alert(user_code: str, account_number:str, db: Session = Depends(get_db)):
    alert = db.query(TradingviewAlertSignal).filter(
        TradingviewAlertSignal.user_access.has(user_code=user_code),
        TradingviewAlertSignal.account_number == account_number,
        TradingviewAlertSignal.alert_taken == False
    ).first()
    
    if not alert:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=False)
    
    alert.alert_taken = True
    db.commit()
    return {
        'detail': True,
        'signal_type': alert.signal_type,
        'sl_pips': alert.sl_pips,
        'sl_price': alert.sl_price,
        'tp_pips': alert.tp_pips,
        'tp_price': alert.tp_price,
        'symbol': alert.symbol,
        'amount_to_risk': alert.amount_to_risk
    }


@app.post("/tradingview-alert/signal/")
async def create_tradingview_alert(alert_data: TradingviewAlertRequest, db: Session = Depends(get_db)):
    
    user_code = alert_data.user_code
    symbol = alert_data.symbol
    trades = alert_data.trades

    user_access = db.query(UserAccess).filter(UserAccess.user_code == user_code).first()
    if not user_access:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # Verificar si el usuario está activo
    if user_access.status.status != 'active':
        raise HTTPException(status_code=400, detail="El usuario no está activo")

    for trade in trades:
        signal_type = trade.signal_type
        account_number = trade.account_number
        amount_to_risk = trade.amount_to_risk
        sl_pips = trade.sl_pips
        sl_price = trade.sl_price
        tp_pips = trade.tp_pips
        tp_price = trade.tp_price

        # First validate either sl_pips or sl_price is passed
        if (not sl_pips and not sl_price):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='Debe proveer un Stop Loss ya sea en pips o en precio'
            )
        
        if amount_to_risk <= 0:
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='Monto a arriesgar no puede ser menor o igual a cero'
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
                        detail=f'{str(e)} no es un número válido'
                    )

        alert = db.query(TradingviewAlertSignal).filter(
            TradingviewAlertSignal.user_access.has(user_code=user_code),
            TradingviewAlertSignal.account_number == account_number
        ).first()

        if alert:
            alert.symbol = symbol
            alert.account_number = account_number
            alert.signal_type = signal_type
            alert.sl_pips = sl_pips or -1
            alert.sl_price = sl_price or -1
            alert.tp_pips = tp_pips or -1
            alert.tp_price = tp_price or -1
            alert.amount_to_risk = amount_to_risk
            alert.alert_taken = False
            db.commit()

        else:
            current_datetime = datetime.now()
            new_alert = TradingviewAlertSignal(
                user_access_id=user_access.user_access_id,
                symbol=symbol,
                account_number=account_number,
                signal_type=signal_type,
                sl_pips=sl_pips or -1,
                sl_price=sl_price or -1,
                tp_pips=tp_pips or -1,
                tp_price=tp_price or -1,
                amount_to_risk=amount_to_risk,
                created_at=current_datetime,
                updated_at=current_datetime
            )
            db.add(new_alert)
            db.commit()

    return {'message': 'Datos almacenados exitosamente'}


@app.post("/tradingview-alert-gold-london/signal/")
async def create_tradingview_alert_gold_london(
    alert_data: TradingviewAlertGoldLondonRequest,
    db: Session = Depends(get_db)):
    
    signal_type = alert_data.signal_type
    prices = alert_data.prices
    open_position = alert_data.open_position
    timestamp = alert_data.timestamp

    today = date.today()

    today_signal = db.query(TradingviewAlertGoldLondonSignal).filter(
        func.date(TradingviewAlertGoldLondonSignal.created_at) == today
    ).first()

    if not open_position.startswith("Exit") and not today_signal: 
        # If it's a new position in the current day

        prices = prices.split('-')
        tp_price = prices[0]
        sl_price = prices[1]
        price_for_be = prices[2]
        sl_pips = float(prices[3]) / 10

        new_signal = TradingviewAlertGoldLondonSignal(
            signal_type=signal_type,
            sl_price=sl_price,
            sl_pips=sl_pips,
            tp_price=tp_price,
            price_for_be=price_for_be,
            open_timestamp=timestamp,
            close_timestamp=None,
            created_at=func.now(),
            updated_at=func.now()
        )
        db.add(new_signal)
        db.commit()

    elif open_position.startswith("Exit") and today_signal:
        # An position was open and now will be closed
        today_signal.close_timestamp = timestamp
        today_signal.close_trade = True
        db.commit()

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Ya existe operación en el día'
        )

    return {'message': 'Datos almacenados exitosamente'}

@app.post("/tradingview-alert-gold-london/signal/set-be/")
async def set_be_tradingview_alert_gold_london(
    alert_data: TradingviewAlertGoldLondonRequest,
    db: Session = Depends(get_db)):
    
    signal_type = alert_data.signal_type
    prices = alert_data.prices
    open_position = alert_data.open_position
    timestamp = alert_data.timestamp

    today = date.today()

    today_signal = db.query(TradingviewAlertGoldLondonSignal).filter(
        func.date(TradingviewAlertGoldLondonSignal.created_at) == today
    ).first()

    if open_position.startswith("BE-Exit") and today_signal:
        # Set breakeven to this position
        today_signal.set_be = True
        db.commit()

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='No se encontró operación en el día o no fue una solicitud de BE'
        )

    return {'message': 'Datos almacenados exitosamente'}


@app.get("/tradingview-alert-gold-london/signal/{user_code}/{account_number}/")
async def get_tradingview_alert(user_code: str, account_number:str, db: Session = Depends(get_db)):

    # Validate user exists and is active
    user_validation = db.query(UserAccessAccount).\
        join(UserAccess).\
        join(Status).\
        filter(UserAccess.user_code == user_code).\
        filter(Status.status == 'active').\
        filter(UserAccess.xauusd_bot_london_enabled == True).\
        filter(UserAccessAccount.account_number == account_number).\
        filter(UserAccessAccount.status_id == Status.id).\
        first()
    
    if not user_validation:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Usuario o no existe, o no le pertenece esta cuenta o no está activo")
    
    today = date.today()
    delay_minutes = int(os.environ.get('DELAY_MINUTES'))

    today_signal = db.query(TradingviewAlertGoldLondonSignal).filter(
        func.date(TradingviewAlertGoldLondonSignal.created_at) == today
    ).first()

    if today_signal:
        limit_time = today_signal.open_timestamp + timedelta(minutes=delay_minutes)
        limit_time = limit_time.replace(tzinfo=None)
        if datetime.now()  > limit_time and not today_signal.close_trade:
            print(
            f'Ya han pasado {delay_minutes} minutes '
            f'después de la señal. Cliente: {user_code}')
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=False)

        return {
            'detail': True,
            'signal_type': today_signal.signal_type,
            'sl_price': today_signal.sl_price,
            'sl_pips': today_signal.sl_pips,
            'tp_price': today_signal.tp_price,
            'price_for_be': today_signal.price_for_be,
            'set_be': today_signal.set_be,
            'close_trade': today_signal.close_trade,
        }
    else:
        print(
            f'No hay operación en el día')
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=False)