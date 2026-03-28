import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    pseudo = Column(String, unique=True, nullable=False, index=True)
    auth_token = Column(String, nullable=False, unique=True)
    apns_token = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    keys = relationship("KeyBundle", back_populates="user", uselist=False)
    onetime_prekeys = relationship("OnetimePrekey", back_populates="user")
    pq_onetime_prekeys = relationship("PQOnetimePrekey", back_populates="user")


class KeyBundle(Base):
    __tablename__ = "keys"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    identity_key = Column(Text, nullable=False)
    pq_identity_key = Column(Text, nullable=False)
    signed_prekey = Column(Text, nullable=False)
    signed_prekey_signature = Column(Text, nullable=False)
    signed_prekey_pq_signature = Column(Text, nullable=False)
    pq_signed_prekey = Column(Text, nullable=False)
    pq_signed_prekey_signature = Column(Text, nullable=False)
    pq_signed_prekey_pq_signature = Column(Text, nullable=False)

    user = relationship("User", back_populates="keys")


class OnetimePrekey(Base):
    __tablename__ = "onetime_prekeys"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    key_id = Column(String, nullable=False)
    key = Column(Text, nullable=False)

    user = relationship("User", back_populates="onetime_prekeys")


class PQOnetimePrekey(Base):
    __tablename__ = "pq_onetime_prekeys"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    key_id = Column(String, nullable=False)
    key = Column(Text, nullable=False)

    user = relationship("User", back_populates="pq_onetime_prekeys")


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = {"sqlite_autoincrement": True}

    id = Column(Integer, primary_key=True)
    sender_pseudo = Column(String, nullable=False, index=True)
    recipient_pseudo = Column(String, nullable=False, index=True)
    ephemeral_key = Column(Text, nullable=True)
    kem_ciphertext = Column(Text, nullable=True)
    used_onetime_key_id = Column(String, nullable=True)
    ciphertext = Column(Text, nullable=False)
    nonce = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
