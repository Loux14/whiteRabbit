import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.database import get_db
from app.models import User, KeyBundle, OnetimePrekey, PQOnetimePrekey
from app.schemas import KeyBundleUpload, KeyBundleResponse, SignedKey

router = APIRouter()


@router.post("/keys", status_code=200)
def upload_keys(
    body: KeyBundleUpload,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Upsert key bundle
    bundle = db.query(KeyBundle).filter(KeyBundle.user_id == user.id).first()
    if bundle:
        bundle.identity_key = body.identity_key
        bundle.pq_identity_key = body.pq_identity_key
        bundle.signed_prekey = body.signed_prekey.key
        bundle.signed_prekey_signature = body.signed_prekey.signature
        bundle.signed_prekey_pq_signature = body.signed_prekey.pq_signature
        bundle.pq_signed_prekey = body.pq_signed_prekey.key
        bundle.pq_signed_prekey_signature = body.pq_signed_prekey.signature
        bundle.pq_signed_prekey_pq_signature = body.pq_signed_prekey.pq_signature
    else:
        bundle = KeyBundle(
            user_id=user.id,
            identity_key=body.identity_key,
            pq_identity_key=body.pq_identity_key,
            signed_prekey=body.signed_prekey.key,
            signed_prekey_signature=body.signed_prekey.signature,
            signed_prekey_pq_signature=body.signed_prekey.pq_signature,
            pq_signed_prekey=body.pq_signed_prekey.key,
            pq_signed_prekey_signature=body.pq_signed_prekey.signature,
            pq_signed_prekey_pq_signature=body.pq_signed_prekey.pq_signature,
        )
        db.add(bundle)

    # Append one-time prekeys (additive)
    for key_data in body.onetime_prekeys:
        opk = OnetimePrekey(user_id=user.id, key_id=str(uuid.uuid4()), key=key_data)
        db.add(opk)

    for key_data in body.pq_onetime_prekeys:
        pqopk = PQOnetimePrekey(user_id=user.id, key_id=str(uuid.uuid4()), key=key_data)
        db.add(pqopk)

    db.commit()
    return {"status": "ok"}


@router.get("/keys/{pseudo}", response_model=KeyBundleResponse)
def get_keys(pseudo: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.pseudo == pseudo).first()
    if not user or not user.keys:
        raise HTTPException(status_code=404, detail="User not found")

    bundle = user.keys

    # Pop one OPK (consumed on use)
    opk = db.query(OnetimePrekey).filter(OnetimePrekey.user_id == user.id).first()
    opk_value = None
    if opk:
        opk_value = opk.key
        db.delete(opk)

    # Pop one PQ OPK (consumed on use)
    pqopk = db.query(PQOnetimePrekey).filter(PQOnetimePrekey.user_id == user.id).first()
    pqopk_value = None
    if pqopk:
        pqopk_value = pqopk.key
        db.delete(pqopk)

    db.commit()

    return KeyBundleResponse(
        pseudo=pseudo,
        identity_key=bundle.identity_key,
        pq_identity_key=bundle.pq_identity_key,
        signed_prekey=SignedKey(
            key=bundle.signed_prekey,
            signature=bundle.signed_prekey_signature,
            pq_signature=bundle.signed_prekey_pq_signature,
        ),
        onetime_prekey=opk_value,
        pq_signed_prekey=SignedKey(
            key=bundle.pq_signed_prekey,
            signature=bundle.pq_signed_prekey_signature,
            pq_signature=bundle.pq_signed_prekey_pq_signature,
        ),
        pq_onetime_prekey=pqopk_value,
    )
