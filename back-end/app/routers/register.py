import secrets

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas import RegisterRequest, RegisterResponse

router = APIRouter()


@router.post("/register", response_model=RegisterResponse, status_code=201)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.pseudo == body.pseudo).first():
        raise HTTPException(status_code=409, detail="Pseudo already taken")

    token = secrets.token_hex(32)
    user = User(pseudo=body.pseudo, auth_token=token)
    db.add(user)
    db.commit()

    return RegisterResponse(pseudo=user.pseudo, auth_token=token)
