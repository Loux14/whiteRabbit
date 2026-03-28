import os
import secrets
from dataclasses import dataclass
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./messagerie.db")
SECRET_KEY = os.getenv("SECRET_KEY", secrets.token_hex(32))


@dataclass
class Settings:
    apns_key_id: str = os.getenv("APNS_KEY_ID", "")
    apns_team_id: str = os.getenv("APNS_TEAM_ID", "")
    apns_bundle_id: str = os.getenv("APNS_BUNDLE_ID", "")
    apns_key: str = os.getenv("APNS_KEY", "").replace("\\n", "\n")


settings = Settings()
