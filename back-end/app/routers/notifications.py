import json
import time
import httpx
import jwt  # PyJWT

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.config import settings
from app.database import get_db
from app.models import User
from app.schemas import DeviceTokenRequest

router = APIRouter()


@router.post("/device-token")
def save_device_token(
    body: DeviceTokenRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user.apns_token = body.token
    db.commit()
    return {"status": "ok"}


def _apns_jwt() -> str:
    payload = {
        "iss": settings.apns_team_id,
        "iat": int(time.time()),
    }
    return jwt.encode(
        payload,
        settings.apns_key,
        algorithm="ES256",
        headers={"kid": settings.apns_key_id},
    )


async def send_push(apns_token: str, sender: str):
    url = f"https://api.sandbox.push.apple.com/3/device/{apns_token}"
    headers = {
        "authorization": f"bearer {_apns_jwt()}",
        "apns-topic": settings.apns_bundle_id,
        "apns-push-type": "alert",
    }
    payload = {
        "aps": {
            "alert": {
                "title": "whiteRabbit",
                "body": f"New message from {sender}",
            },
            "sound": "default",
            "badge": 1,
        }
    }
    async with httpx.AsyncClient(http2=True) as client:
        resp = await client.post(url, json=payload, headers=headers)
        if resp.status_code != 200:
            print(f"[APNs] Error {resp.status_code}: {resp.text}")
