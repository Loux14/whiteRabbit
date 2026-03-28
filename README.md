# whiteRabbit

Application iOS de messagerie sécurisée avec chiffrement de bout en bout post-quantique (ML-KEM + ML-DSA).

---
<img width="375" height="667" alt="accueil" src="https://github.com/user-attachments/assets/fc18ea57-fa7b-46bc-93c2-6b959409d56a" />

<img width="375" height="667" alt="chat" src="https://github.com/user-attachments/assets/3046c1d5-33d4-47a5-b5b3-faadfef88ef6" />


## Prérequis

- Python 3.13+
- Xcode 16+
- Un compte Apple Developer (gratuit ou payant)
- Un iPhone ou simulateur iOS

---

## Backend (serveur local)

### 1. Installer les dépendances

```bash
cd back-end
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Configurer les variables d'environnement
Créer un fichier .env dans back-end/ :

```
APNS_KEY_ID=XXXXXXXXXX
APNS_TEAM_ID=XXXXXXXXXX
APNS_BUNDLE_ID=com.tonbundleid.whiteRabbit
APNS_KEY=-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

Les credentials APNs s'obtiennent sur developer.apple.com :

Certificates, IDs & Profiles → Keys → créer une clé avec Apple Push Notifications (APN)
Télécharger le fichier .p8 et copier son contenu dans APNS_KEY
APNS_KEY_ID : l'identifiant de la clé (10 caractères)
APNS_TEAM_ID : ton Team ID (visible en haut à droite sur developer.apple.com)

3. Lancer le serveur
```
cd back-end
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
Le serveur tourne sur http://0.0.0.0:8000.
```

Application iOS
1. Configurer l'adresse IP du serveur
Dans PostMessage/PostMessage/Network/APIClient.swift, modifier la ligne :

```
#if targetEnvironment(simulator)
private let baseURL = "http://127.0.0.1:8000"
#else
private let baseURL = "http://192.168.x.x:8000" // ← 
#endif
```

L'iPhone et la machine qui fait tourner le serveur doivent être sur le même réseau Wi-Fi.

2. Configurer la signature Xcode

Ouvrir PostMessage/PostMessage.xcodeproj dans Xcode

Sélectionner la cible PostMessage dans le panneau de gauche

Onglet Signing & Capabilities

Cocher Automatically manage signing

Choisir ton Team (compte Apple Developer)

Modifier le Bundle Identifier : com.tonidentifiant.whiteRabbit

4. Lancer l'app
Sur simulateur : Cmd+R — se connecte automatiquement à 127.0.0.1

Sur iPhone physique : brancher l'iPhone, le sélectionner comme destination, Cmd+R

Pour déployer sur un iPhone sans compte payant, le certificat de développement expire après 7 jours. Un compte Apple Developer payant (99 $/an) lève cette limitation.

Notes

Le serveur tourne en HTTP (pas HTTPS) — utiliser uniquement sur un réseau local de confiance

Le fichier .env ne doit jamais être commité (déjà dans .gitignore)

La base de données SQLite (messagerie.db) est générée automatiquement au premier lancement
