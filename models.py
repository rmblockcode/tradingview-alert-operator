from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean, Float
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func

from database import Base


class Status(Base):
    __tablename__ = "access_management_status"

    id = Column(Integer, primary_key=True)
    status = Column(String(15), nullable=False, unique=True)

    def __str__(self):
        return self.status


class UserAccess(Base):
    __tablename__ = 'access_management_useraccess'

    user_access_id = Column(Integer, primary_key=True)
    user_fullname = Column(String(100), nullable=False)
    user_code = Column(String(25), unique=True, nullable=False)
    user_email = Column(String(100), unique=True, nullable=True)
    discord_username = Column(String(30), unique=True, nullable=True)
    max_accounts_available = Column(Integer, default=1)
    status_id = Column(Integer, ForeignKey('access_management_status.id'), nullable=True, default=None)
    status = relationship('Status')
    xauusd_bot_ny_enabled = Column(Boolean, default=False)
    xauusd_bot_london_enabled = Column(Boolean, default=False)
    tradingview_alert_bot_enabled = Column(Boolean, default=False)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<UserAccess(user_fullname={self.user_fullname}, user_code={self.user_code})>"


class UserAccessAccount(Base):
    __tablename__ = 'access_management_useraccessaccount'

    user_access_account = Column(Integer, primary_key=True)
    account_number = Column(String)
    is_real = Column(Boolean, default=False)
    user_access_id = Column(Integer, ForeignKey('access_management_useraccess.user_access_id'))
    user_access = relationship("UserAccess")
    status_id = Column(Integer, ForeignKey('access_management_status.id'), nullable=True, default=None)
    status = relationship("Status")
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class TradingviewAlertSignal(Base):
    __tablename__ = "tradingview_alert_tradingviewalertsignal"

    id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    user_access_id = Column(Integer, ForeignKey('access_management_useraccess.user_access_id'), nullable=False)
    user_access = relationship("UserAccess", backref="tradingview_alerts")
    signal_type = Column(String(4), nullable=True)
    symbol = Column(String(20))
    account_number = Column(Integer)
    sl_pips = Column(Float, nullable=True)
    sl_price = Column(Float, nullable=True)
    tp_pips = Column(Float, nullable=True)
    tp_price = Column(Float, nullable=True)
    amount_to_risk = Column(Float)
    alert_taken = Column(Boolean, default=False)


class TradingviewAlertGoldLondonSignal(Base):
    __tablename__ = 'tradingview_alert_tradingviewalertgoldlondonsignal'

    id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    signal_type = Column(String(4))
    sl_price = Column(Float)
    sl_pips = Column(Float)
    tp_price = Column(Float)
    price_for_be = Column(Float)
    set_be = Column(Boolean, default=False)
    close_trade = Column(Boolean, default=False)
    open_timestamp = Column(DateTime)
    close_timestamp = Column(DateTime, nullable=True)


class NewsEvents(Base):
    __tablename__ = 'news_events_newsevents'

    id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())
    title = Column(String(255))
    country = Column(String(3))
    date = Column(DateTime)
    impact = Column(String(10))
    forecast = Column(String(50))
    previous = Column(String(50))
