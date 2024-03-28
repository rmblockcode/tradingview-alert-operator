from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func

from database import Base


class UserAccess(Base):
    __tablename__ = 'access_management_useraccess'

    user_access_id = Column(Integer, primary_key=True)
    user_fullname = Column(String(100), nullable=False)
    user_code = Column(String(25), unique=True, nullable=False)
    user_email = Column(String(100), unique=True, nullable=True)
    discord_username = Column(String(30), unique=True, nullable=True)
    max_accounts_available = Column(Integer, default=1)
    # status_id = Column(Integer, ForeignKey('status.status_id'), nullable=True, default=None)
    # status = relationship('Status')
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<UserAccess(user_fullname={self.user_fullname}, user_code={self.user_code})>"


class TradingviewAlertSignal(Base):
    __tablename__ = "tradingview_alert_tradingviewalertsignal"

    id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    user_access_id = Column(Integer, ForeignKey('access_management_useraccess.user_access_id'), nullable=False)
    trx_id = Column(String, unique=True)
    signal_type = Column(String(4), nullable=True)
    sl_points = Column(Integer, nullable=True)
    status_id = Column(Integer, ForeignKey('access_management_status.id'), nullable=False)

    user_access = relationship("UserAccess", backref="tradingview_alerts")
    alert_taken = Column(Boolean, default=False)
    status = relationship("Status")

class Status(Base):
    __tablename__ = "access_management_status"

    id = Column(Integer, primary_key=True)
    status = Column(String(15), nullable=False, unique=True)

    def __str__(self):
        return self.status
