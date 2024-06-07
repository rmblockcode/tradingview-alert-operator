from fastapi import APIRouter
from fastapi import FastAPI, HTTPException, Depends, status, Body
from pydantic import BaseModel
from sqlalchemy.orm import Session

from datetime import datetime

from database import get_db
from models import (
    TradingviewAlertSignal, UserAccess
)


router = APIRouter(
    prefix='/tradingview-alert/v2'
)

class TradingviewAlertRequest(BaseModel):
    trade: str

@router.post("/signal/")
async def create_tradingview_alert(data: str = Body(...), db: Session = Depends(get_db)):

    """
        user_code,account_number,signal_type,symbol,amount_risk=Value,sl_pips=Value,sl_price=Value,tp_pips=Value,tp_price=Value,be_trig=Value,trail_trig=Value,trail_dist=Value,trail_step=Value
    """
    print(data)
    notifications = data.strip().split('\n')
    
    for notification in notifications:
        parts = notification.split(',')
        print(parts)
        if len(parts) < 4:
            raise HTTPException(status_code=400, detail="Formato de notificación inválido")
    
        user_code = parts[0].strip()
        account_number = int(parts[1]).strip()
        signal_type = parts[2].strip()
        symbol = parts[3]

        user_access = db.query(UserAccess).filter(UserAccess.user_code == user_code).first()
        if not user_access:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
        # Verificar si el usuario está activo
        if user_access.status.status != 'active':
            raise HTTPException(status_code=400, detail="El usuario no está activo")

        # Valores opcionales
        amount_to_risk = 0
        sl_pips = -1
        sl_price = -1
        tp_pips = -1
        tp_price = -1
        be_trigger_price = -1
        trailing_trigger_price = -1
        trailing_distance_pips = -1
        trailing_step = -1

        for part in parts[4:]:
            if 'amount_risk=' in part:
                amount_to_risk = float(part.split('=')[1].strip())
            elif 'sl_pips=' in part:
                sl_pips = float(part.split('=')[1].strip())
            elif 'sl_price=' in part:
                sl_price = float(part.split('=')[1].strip())
            elif 'tp_pips=' in part:
                tp_pips = float(part.split('=')[1].strip())
            elif 'tp_price=' in part:
                tp_price = float(part.split('=')[1].strip())
            elif 'be_trig=' in part:
                be_trigger_price = float(part.split('=')[1].strip())
            elif 'trail_trig=' in part:
                trailing_trigger_price = float(part.split('=')[1].strip())
            elif 'trail_dist=' in part:
                trailing_distance_pips = float(part.split('=')[1].strip())
            elif 'trail_step=' in part:
                trailing_step = float(part.split('=')[1].strip())
            

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
        for field in [sl_pips, sl_price, tp_pips, tp_price, be_trigger_price]:
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
            alert.be_trigger_price = be_trigger_price or -1
            alert.trailing_trigger_price = trailing_trigger_price or -1
            alert.trailing_distance_pips = trailing_distance_pips or -1
            alert.trailing_step = trailing_step or -1
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
                be_trigger_price=be_trigger_price or -1,
                trailing_trigger_price=trailing_trigger_price or -1,
                trailing_distance_pips=trailing_distance_pips or -1,
                trailing_step = trailing_step or -1,
                amount_to_risk=amount_to_risk,
                created_at=current_datetime,
                updated_at=current_datetime
            )
            db.add(new_alert)
            db.commit()

    return {'message': 'Datos almacenados exitosamente'}
