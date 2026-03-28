import asyncio

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.database import get_db
from app.models import User, Message
from app.routers.notifications import send_push
from app.schemas import SendMessageRequest, SendMessageResponse, MessageOut, MessagesResponse

router = APIRouter()


@router.post("/messages", response_model=SendMessageResponse, status_code=201)
async def send_message(
    body: SendMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    recipient = db.query(User).filter(User.pseudo == body.to).first()
    if not recipient:
        raise HTTPException(status_code=404, detail="Recipient not found")

    msg = Message(
        sender_pseudo=user.pseudo,
        recipient_pseudo=body.to,
        ephemeral_key=body.ephemeral_key,
        kem_ciphertext=body.kem_ciphertext,
        used_onetime_key_id=body.used_onetime_key_id,
        ciphertext=body.ciphertext,
        nonce=body.nonce,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    if recipient.apns_token:
        asyncio.create_task(send_push(recipient.apns_token, user.pseudo))

    return SendMessageResponse(
        message_id=msg.id,
        timestamp=msg.timestamp.isoformat() + "Z",
    )


@router.get("/messages", response_model=MessagesResponse)
def get_messages(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msgs = (
        db.query(Message)
        .filter(Message.recipient_pseudo == user.pseudo)
        .order_by(Message.timestamp)
        .all()
    )

    return MessagesResponse(
        messages=[
            MessageOut(
                id=m.id,
                sender=m.sender_pseudo,
                ephemeral_key=m.ephemeral_key,
                kem_ciphertext=m.kem_ciphertext,
                used_onetime_key_id=m.used_onetime_key_id,
                ciphertext=m.ciphertext,
                nonce=m.nonce,
                timestamp=m.timestamp.isoformat() + "Z",
            )
            for m in msgs
        ]
    )


@router.delete("/messages/{message_id}")
def delete_message(
    message_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(
        Message.id == message_id,
        Message.recipient_pseudo == user.pseudo,
    ).first()

    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")

    db.delete(msg)
    db.commit()
    return {"status": "deleted"}
