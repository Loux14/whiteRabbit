# Backend - Messagerie PQC

Serveur zero-knowledge pour la messagerie post-quantique. FastAPI + SQLite.

## Prérequis

- Python 3.13

## Installation

```bash
cd back-end
python3.13 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

## Lancement

```bash
source venv/bin/activate
uvicorn app.main:app --reload
```

Le serveur tourne sur `http://127.0.0.1:8000`.

- Documentation Swagger : http://127.0.0.1:8000/docs
- Health check : http://127.0.0.1:8000/health

## Endpoints

Tous les endpoints authentifiés nécessitent le header `Authorization: Bearer <token>`.

### POST /register

Créer un compte avec un pseudonyme.

```bash
curl -X POST http://127.0.0.1:8000/register \
  -H "Content-Type: application/json" \
  -d '{"pseudo": "alice"}'
```

Réponse :
```json
{"pseudo": "alice", "auth_token": "abc123..."}
```

### POST /keys

Publier ses clés publiques (classiques + post-quantiques).

```bash
curl -X POST http://127.0.0.1:8000/keys \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "identity_key": "base64...",
    "signed_prekey": {"key": "base64...", "signature": "base64..."},
    "onetime_prekeys": ["base64..."],
    "pq_signed_prekey": {"key": "base64...", "signature": "base64..."},
    "pq_onetime_prekeys": ["base64..."]
  }'
```

### GET /keys/{pseudo}

Récupérer le key bundle d'un utilisateur. Consomme une OPK et une PQ-OPK (usage unique).

```bash
curl http://127.0.0.1:8000/keys/bob
```

### POST /messages

Envoyer un message chiffré.

```bash
curl -X POST http://127.0.0.1:8000/messages \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "bob",
    "ephemeral_key": "base64...",
    "kem_ciphertext": "base64...",
    "ciphertext": "base64...",
    "nonce": "base64..."
  }'
```

### GET /messages

Récupérer ses messages en attente.

```bash
curl http://127.0.0.1:8000/messages \
  -H "Authorization: Bearer <token>"
```

### DELETE /messages/{id}

Supprimer un message après lecture.

```bash
curl -X DELETE http://127.0.0.1:8000/messages/1 \
  -H "Authorization: Bearer <token>"
```

## Structure

```
back-end/
├── .env.example        # Template variables d'environnement
├── requirements.txt    # Dépendances Python
└── app/
    ├── main.py         # Point d'entrée FastAPI
    ├── config.py       # Configuration (.env)
    ├── database.py     # SQLAlchemy engine + session
    ├── models.py       # Tables: users, keys, onetime_prekeys, messages
    ├── schemas.py      # DTOs Pydantic (request/response)
    ├── auth.py         # Auth Bearer token
    └── routers/
        ├── register.py # POST /register
        ├── keys.py     # POST /keys, GET /keys/{pseudo}
        └── messages.py # POST, GET, DELETE /messages
```
