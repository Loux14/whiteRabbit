# whiteRabbit

Application iOS de messagerie sécurisée avec chiffrement de bout en bout post-quantique (ML-KEM + ML-DSA).

---

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
