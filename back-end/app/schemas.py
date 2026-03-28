from pydantic import BaseModel


# --- Register ---

class RegisterRequest(BaseModel):
    pseudo: str


class RegisterResponse(BaseModel):
    pseudo: str
    auth_token: str


# --- Keys ---

class SignedKey(BaseModel):
    key: str
    signature: str    # Ed25519
    pq_signature: str # ML-DSA-65


class KeyBundleUpload(BaseModel):
    identity_key: str
    pq_identity_key: str
    signed_prekey: SignedKey
    onetime_prekeys: list[str]
    pq_signed_prekey: SignedKey
    pq_onetime_prekeys: list[str]


class KeyBundleResponse(BaseModel):
    pseudo: str
    identity_key: str
    pq_identity_key: str
    signed_prekey: SignedKey
    onetime_prekey: str | None = None
    pq_signed_prekey: SignedKey
    pq_onetime_prekey: str | None = None


# --- Device token ---

class DeviceTokenRequest(BaseModel):
    token: str


# --- Messages ---

class SendMessageRequest(BaseModel):
    to: str
    ephemeral_key: str | None = None
    kem_ciphertext: str | None = None
    used_onetime_key_id: str | None = None
    ciphertext: str
    nonce: str


class SendMessageResponse(BaseModel):
    message_id: int
    timestamp: str


class MessageOut(BaseModel):
    id: int
    sender: str
    ephemeral_key: str | None = None
    kem_ciphertext: str | None = None
    used_onetime_key_id: str | None = None
    ciphertext: str
    nonce: str
    timestamp: str


class MessagesResponse(BaseModel):
    messages: list[MessageOut]
