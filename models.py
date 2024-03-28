from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean, Float
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func

from database import Base


class Status(Base):
    __tablename__ = 'status'

    STATUS_CHOICES = [
        ('active', 'Activo'),
        ('in_review', 'En Revisión'),
        ('deactivated', 'Desactivado'),
        ('rejected', 'Rechazado'),
        ('cancelled', 'Cancelado'),
    ]

    status = Column(String(15), primary_key=True)

    def __repr__(self):
        return self.status


class UserAccess(Base):
    __tablename__ = 'access_management_useraccess'

    user_access_id = Column(Integer, primary_key=True)
    user_fullname = Column(String(100), nullable=False)
    user_code = Column(String(25), unique=True, nullable=False)
    user_email = Column(String(100), unique=True, nullable=True)
    discord_username = Column(String(30), unique=True, nullable=True)
    max_accounts_available = Column(Integer, default=1)
    status_id = Column(Integer, ForeignKey('status.status_id'), nullable=True, default=None)
    status = relationship('Status')
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<UserAccess(user_fullname={self.user_fullname}, user_code={self.user_code})>"


class UserAccessAccount(Base):
    __tablename__ = 'user_access_account'

    user_access_account = Column(Integer, primary_key=True)
    account_number = Column(Integer)
    user_access_id = Column(Integer, ForeignKey('user_access.user_access_id'))
    user_access = relationship("UserAccess")
    status_id = Column(Integer, ForeignKey('status.status_id'), nullable=True, default=None)
    status = relationship("Status")
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class TradingviewAlertSignal(Base):
    __tablename__ = "tradingview_alert_tradingviewalertsignal"

    id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    user_access_id = Column(Integer, ForeignKey('access_management_useraccess.user_access_id'), nullable=False)
    trx_id = Column(String, unique=True)
    signal_type = Column(String(4), nullable=True)
    symbol = Column(String(20))
    account_number = Column(Integer)
    sl_pips = Column(Float, nullable=True)
    sl_price = Column(Float, nullable=True)
    tp_pips = Column(Float, nullable=True)
    tp_price = Column(Float, nullable=True)
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
