import os
import pytz
import requests
from fastapi import FastAPI, HTTPException, Depends, status
from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum
from cachetools import cached, TTLCache
from sqlalchemy import func
from sqlalchemy.orm import Session
from models import (
    TradingviewAlertSignal, Status, UserAccess, UserAccessAccount,
    TradingviewAlertGoldLondonSignal, NewsEvents)
from database import SessionLocal
from datetime import datetime, date, timedelta


app = FastAPI()

cache = TTLCache(maxsize=1000, ttl=600) # 5horas
KEY_CACHE_LONDON = 'london-trade'
KEY_CACHE_TODAY_NEWS = 'today-news'

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
    symbol: str
    amount_to_risk: float
    sl_pips: Optional[float] = None
    sl_price: Optional[float] = None
    tp_pips: Optional[float] = None
    tp_price: Optional[float] = None


class TradingviewAlertRequest(BaseModel):
    user_code: str
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


@app.get("/access-validation/{user_code}/{account_number}/{bot_access}/{is_real}/")
async def user_access_validation(user_code: str, account_number: str, bot_access: str, is_real: str):
    if bot_access not in ['xauusd_bot_ny_enabled', 'xauusd_bot_london_enabled', 'tradingview_alert_bot_enabled']:
        return {"result": False}

    is_real_account = True if is_real == "Real" else False

    db = SessionLocal()
    try:
        user_access_account = db.query(UserAccessAccount).join(UserAccess).filter(
            UserAccess.user_code == user_code,
            UserAccessAccount.account_number == account_number,
            UserAccessAccount.is_real == is_real_account,
            UserAccess.status.has(status="active"),
            UserAccessAccount.status.has(status="active")
        ).one_or_none()

        if not user_access_account:
            return {"result": False}

        if bot_access == 'xauusd_bot_ny_enabled' and not user_access_account.user_access.xauusd_bot_ny_enabled:
            return {"result": False}
        
        if bot_access == 'xauusd_bot_london_enabled' and not user_access_account.user_access.xauusd_bot_london_enabled:
            return {"result": False}
        
        if bot_access == 'tradingview_alert_bot_enabled' and not user_access_account.user_access.tradingview_alert_bot_enabled:
            return {"result": False}
        
        return {"result": True}

    finally:
        db.close()


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
        symbol = trade.symbol
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
            TradingviewAlertSignal.account_number == account_number,
            TradingviewAlertSignal.symbol == symbol
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

        data = dict(
            signal_type=signal_type,
            sl_price=sl_price,
            sl_pips=sl_pips,
            tp_price=tp_price,
            price_for_be=price_for_be,
            open_timestamp=timestamp,
            close_timestamp=None,
            set_be=False,
            close_trade=False,
            created_at=func.now(),
            updated_at=func.now()
        )

        new_signal = TradingviewAlertGoldLondonSignal(**data)

        db.add(new_signal)
        db.commit()

        store_signal_to_cache(new_signal)

    elif open_position.startswith("Exit") and today_signal:
        # An position was open and now will be closed
        today_signal.close_timestamp = timestamp
        today_signal.close_trade = True
        db.commit()

        # Updating cache data
        store_signal_to_cache(today_signal)

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Ya existe operación en el día'
        )

    return {'message': 'Datos almacenados exitosamente'}


def store_signal_to_cache(today_signal: TradingviewAlertGoldLondonSignal):
    """
    Store a signal in the cache dictionary
    """
    today_signal = {
        'signal_type': today_signal.signal_type,
        'sl_price': today_signal.sl_price,
        'sl_pips': today_signal.sl_pips,
        'tp_price': today_signal.tp_price,
        'price_for_be': today_signal.price_for_be,
        'set_be': today_signal.set_be,
        'close_trade': today_signal.close_trade,
        'open_timestamp': today_signal.open_timestamp
    }

    cache[KEY_CACHE_LONDON] = today_signal


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

        # Updating cache data
        store_signal_to_cache(today_signal)

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='No se encontró operación en el día o no fue una solicitud de BE'
        )

    return {'message': 'Datos almacenados exitosamente'}


@app.get("/tradingview-alert-gold-london/signal/{user_code}/{account_number}/")
async def get_tradingview_alert_gold_london(user_code: str, account_number:str, db: Session = Depends(get_db)):

    # Validate user exists and is active
    # user_validation = db.query(UserAccessAccount).\
    #     join(UserAccess).\
    #     join(Status).\
    #     filter(UserAccess.user_code == user_code).\
    #     filter(Status.status == 'active').\
    #     filter(UserAccess.xauusd_bot_london_enabled == True).\
    #     filter(UserAccessAccount.account_number == account_number).\
    #     filter(UserAccessAccount.status_id == Status.id).\
    #     first()
    
    # if not user_validation:
    #     raise HTTPException(
    #         status_code=status.HTTP_400_BAD_REQUEST,
    #         detail="Usuario o no existe, o no le pertenece esta cuenta o no está activo")
    
    today = date.today()
    delay_minutes = int(os.environ.get('DELAY_MINUTES'))

    today_signal = cache.get(KEY_CACHE_LONDON)

    if not today_signal:
        print('SIN CACHE')
        # Try looking into the database
        today_signal = db.query(TradingviewAlertGoldLondonSignal).filter(
            func.date(TradingviewAlertGoldLondonSignal.created_at) == today
        ).first()

        if not today_signal:
            print(
                f'No hay operación en el día')
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=False)

        store_signal_to_cache(today_signal)

        today_signal = {
            'signal_type': today_signal.signal_type,
            'sl_price': today_signal.sl_price,
            'sl_pips': today_signal.sl_pips,
            'tp_price': today_signal.tp_price,
            'price_for_be': today_signal.price_for_be,
            'set_be': today_signal.set_be,
            'close_trade': today_signal.close_trade,
            'open_timestamp': today_signal.open_timestamp
        }
    else:
        print('CON CACHE')
        print(today_signal)

    limit_time = today_signal.get('open_timestamp') + timedelta(minutes=delay_minutes)
    limit_time = limit_time.replace(tzinfo=None)

    detail = True

    if datetime.now()  > limit_time:
        print(
        f'Ya han pasado {delay_minutes} minutes '
        f'después de la señal. Cliente: {user_code}')
        detail = False

    return {'detail': detail, **today_signal}


@app.post("/store_news_events/")
async def store_news_events(db: Session = Depends(get_db)):
    # Consulta la URL para obtener los eventos
    url = os.environ.get('NEWS_EVENTS_URL')
    response = requests.get(url)
    events = response.json()

    countries_news = os.environ.get('COUNTRIES_NEWS').split(',')
    impact_news = os.environ.get('IMPACT_NEWS').split(',')

    # Almacena los eventos con impacto "High" en la base de datos
    for event in events:
        if event.get('country') in countries_news and event.get("impact") in impact_news:
            title = event.get('title')
            # Verifica si ya existe una noticia con el mismo título
            existing_news = db.query(NewsEvents).filter_by(title=title).first()
            if existing_news:
                continue  # Si la noticia ya existe, pasa a la siguiente
            country = event.get('country')
            date = datetime.fromisoformat(event.get('date').replace('Z', '+00:00'))
            impact = event.get('impact')
            forecast = event.get('forecast')
            previous = event.get('previous')

            from pprint import pprint
            pprint(event)

            new_event = NewsEvents(
                title=title,
                country=country,
                date=date,
                impact=impact,
                forecast=forecast,
                previous=previous
            )
            db.add(new_event)

        db.commit()

    return {'message': 'Events stored successfully'}


@app.get("/today-news/")
def get_today_news(db: Session = Depends(get_db)):
    """
        Obtiene las noticias del día actual. La fecha es transformada para que solo
        envie la hora de la noticia
    """
    ny_timezone = pytz.timezone("America/New_York")
    today = datetime.now(ny_timezone).date()

    key_cache = f'{KEY_CACHE_TODAY_NEWS}-{today}'

    today_news = cache.get(key_cache)

    if today_news:
        return today_news

    news = db.query(NewsEvents).filter(
        NewsEvents.country == 'USD',
        func.date(NewsEvents.date) == today).all()

    # Si no se encontraron noticias para la fecha especificada, devuelve un error 404
    if not news:
        response = {'result': False, 'news': []}
        cache[key_cache] = response
        return response
    
    for item in news:
        item.date = item.date.astimezone(ny_timezone).strftime("%H:%M:%S")

    response = {'result': True, 'news': news}
    cache[key_cache] = response
    # Devuelve las noticias encontradas
    return response