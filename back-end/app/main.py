from fastapi import FastAPI

from app.database import Base, engine
from app.routers import register, keys, messages, notifications

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Messagerie PQC", version="0.1.0")

app.include_router(register.router)
app.include_router(keys.router)
app.include_router(messages.router)
app.include_router(notifications.router)


@app.get("/health")
def health():
    return {"status": "ok"}
