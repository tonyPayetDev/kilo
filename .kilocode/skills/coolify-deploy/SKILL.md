---
name: deploy-to-coolify
description: >
  Déploie un dossier de site web (statique ou Dockerfile) sur Coolify via GitHub.
  Utilise ce skill dès qu'un utilisateur mentionne : déployer un site, mettre en ligne,
  push sur Coolify, déploiement automatique, publier un site statique, ou toute demande
  de déploiement d'un dossier vers un serveur Coolify. Fonctionne pour tout site HTML/CSS/JS
  ou tout projet avec un Dockerfile.
---

# Deploy to Coolify

Déploie un dossier local sur Coolify en passant par un repo GitHub.

## ⚙️ Variables d'environnement requises

Créer un fichier `/app/.env` avec ces variables :

```bash
# GitHub
GITHUB_TOKEN=ghp_xxxx...                    # Classic PAT avec scope 'repo'
GITHUB_USER=votre_username

# Coolify
COOLIFY_BASE_URL=http://IP:8000             # URL de votre instance Coolify
COOLIFY_ACCESS_TOKEN=xx|xxxx...             # Token API Coolify (Settings → API)
COOLIFY_SERVER_UUID=c4c0wo4...              # UUID du serveur (Settings → Servers)
```

> 💡 **Où trouver ces valeurs ?**
> - **GitHub token** : https://github.com/settings/tokens → "Generate new token (classic)" → scope `repo`
> - **Coolify Access Token** : Interface Coolify → Settings → API → Create New Token
> - **Coolify Server UUID** : Interface Coolify → Settings → Servers → cliquer sur le serveur → UUID dans l'URL
>
> ⚠️ **Important : Utiliser un token CLASSIC GitHub, pas fine-grained !**
> Les fine-grained tokens ne permettent pas de créer des repositories via l'API.

---

## Étapes d'exécution

### 1. Identifier le dossier source

- Résoudre le chemin absolu depuis l'argument fourni
- Le **nom du repo GitHub** = nom du dossier (sans trailing slash, en minuscules, sans espaces)
- Exemple : `/work/mon-super-site` → repo `mon-super-site`

### 2. Vérifier les prérequis

```bash
# Vérifier que git et curl sont disponibles
command -v git >/dev/null 2>&1 || { echo "ERREUR: git non installé"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERREUR: curl non installé"; exit 1; }
```

### 3. Vérifier / créer le Dockerfile

Si le dossier ne contient **pas** de `Dockerfile`, en créer un minimal nginx (adapté aux sites statiques HTML/CSS/JS) :

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

> ⚠️ Si le projet a déjà son propre `Dockerfile`, ne pas l'écraser.

### 4. Initialiser git et pousser sur GitHub

```bash
# Variables (remplacer par les valeurs de l'utilisateur)
GITHUB_TOKEN="<GITHUB_TOKEN>"
GITHUB_USER="<GITHUB_USER>"
REPO_NAME="<nom-du-dossier>"
SITE_DIR="<SITE_DIR>"

# Configurer git si nécessaire
git config --global user.email "deploy@coolify.local" 2>/dev/null
git config --global user.name "Coolify Deploy" 2>/dev/null
git config --global --add safe.directory "$SITE_DIR"

# Créer le repo GitHub si inexistant
REPO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME")

if [ "$REPO_STATUS" = "404" ]; then
  echo "Création du repo GitHub $REPO_NAME..."
  curl -s -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"$REPO_NAME\",\"private\":false,\"auto_init\":false}"
  sleep 2
fi

# Init git si besoin
cd "$SITE_DIR"
if [ ! -d ".git" ]; then
  git init
  git checkout -b main 2>/dev/null || git checkout -b master
fi

# Commit et push
git add -A
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true

REMOTE_URL="https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push -u origin "$BRANCH" --force 2>&1
```

> ℹ️ `--force` est utilisé pour éviter les conflits d'historique sur les déploiements successifs.

### 5. Configurer l'application Coolify via API

**Créer un projet (si besoin) :**
```bash
PROJECT=$(curl -s -X POST "$COOLIFY_BASE_URL/api/v1/projects" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"mon-projet","description":"Description"}')
PROJECT_UUID=$(echo $PROJECT | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)
```

**Créer l'application :**
```bash
APP=$(curl -s -X POST "$COOLIFY_BASE_URL/api/v1/applications/public" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_uuid\": \"$PROJECT_UUID\",
    \"server_uuid\": \"$COOLIFY_SERVER_UUID\",
    \"environment_name\": \"production\",
    \"git_repository\": \"https://github.com/$GITHUB_USER/$REPO_NAME\",
    \"git_branch\": \"main\",
    \"build_pack\": \"dockerfile\",
    \"ports_exposes\": \"80\",
    \"name\": \"$REPO_NAME\"
  }")
APP_UUID=$(echo $APP | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)
URL=$(echo $APP | grep -o '"domains":"[^"]*"' | cut -d'"' -f4)
```

### 6. Déclencher le déploiement

```bash
curl -s -X POST "$COOLIFY_BASE_URL/api/v1/deploy?uuid=$APP_UUID&force=true" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN"
```

Attendre 5 secondes avant de commencer le polling.

### 7. Polling statut — toutes les 10s, max 3 min (18 tentatives)

```bash
for i in {1..18}; do
  STATUS=$(curl -s "$COOLIFY_BASE_URL/api/v1/applications/$APP_UUID" \
    -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" | grep -o '"status":"[^"]*"')
  
  if echo "$STATUS" | grep -q "running"; then
    echo "✅ Déploiement réussi"
    break
  elif echo "$STATUS" | grep -q "failed\|error"; then
    echo "❌ ERREUR: $STATUS"
    exit 1
  fi
  
  echo "Tentative $i/18 - Status: $STATUS"
  sleep 10
done
```

| Statut | Action |
|--------|--------|
| `"running"` | ✅ Passer à l'étape 8 |
| `"failed"` ou `"error"` | ❌ Erreur, afficher les logs |
| 18 tentatives | ❌ Timeout (3 min dépassées) |

### 8. Récupérer l'URL du site

L'URL a été récupérée à l'étape 5 (champ `domains`). Si besoin de la re-récupérer :

```bash
URL=$(curl -s "$COOLIFY_BASE_URL/api/v1/applications/$APP_UUID" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" | grep -o '"domains":"[^"]*"' | cut -d'"' -f4)
```

Format : `http://<app_uuid>.<IP_SERVEUR>.sslip.io`

### 9. Vérification HTTP — toutes les 5s, max 2 min (24 tentatives)

```bash
for i in {1..24}; do
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL")
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Site accessible (HTTP 200)"
    break
  fi
  
  echo "Tentative $i/24 - HTTP $HTTP_CODE"
  sleep 5
done
```

| Code HTTP | Action |
|-----------|--------|
| `200` | ✅ Succès |
| `502/504` | Container en démarrage, attendre 30s |
| Autres | Continuer le polling |

### 10. Résultat final

```
SITE_EN_LIGNE: $URL
```

Exemple de sortie : `SITE_EN_LIGNE: http://c8og44sow8ogso8o8wo4w0kc.158.220.127.234.sslip.io`

---

## 🔧 Dépannage

| Problème | Solution |
|----------|----------|
| `git push` échoue avec 403 | Vérifier que le token a le scope `repo` |
| `Resource not accessible by personal access token` | Le token est fine-grained. Créer un **Classic token** avec scope `repo` |
| Coolify status `failed` | Consulter les logs avec `mcp__coolify__deployment` action `get` |
| `fqdn` null dans Coolify | Utiliser le format sslip.io avec l'IP du serveur |
| Site répond 502/504 | Le container démarre encore, attendre 30s et réessayer |

---

## 📝 Notes techniques

- Le Dockerfile nginx minimal convient pour **tout site statique** (HTML/CSS/JS/assets)
- Pour un site avec backend (Node, PHP, etc.), un `Dockerfile` doit être présent dans le dossier
- `build_pack: dockerfile` est le mode recommandé pour un contrôle maximal
- Les repos GitHub créés sont publics par défaut ; changer `"private": false` en `true` si nécessaire

---

## 📜 Script Complet (déploiement en une commande)

```bash
#!/bin/bash
# deploy.sh - Déploiement complet d'un site sur Coolify

# Charger les variables d'environnement
export $(grep -v '^#' /app/.env | xargs)

# Configuration
SITE_DIR="${1:-/app/mon-site}"  # Premier argument ou défaut
REPO_NAME=$(basename "$SITE_DIR")
GITHUB_USER="${GITHUB_USER:-tonyPayetDev}"

echo "🚀 Déploiement de $REPO_NAME"

# 1. Configurer git
git config --global user.email "deploy@coolify.local" 2>/dev/null || true
git config --global user.name "Coolify Deploy" 2>/dev/null || true

# 2. Créer le repo GitHub si inexistant
REPO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME")

if [ "$REPO_STATUS" = "404" ]; then
  echo "📦 Création du repo GitHub..."
  curl -s -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"$REPO_NAME\",\"private\":false,\"auto_init\":false}"
  sleep 2
fi

# 3. Push sur GitHub
cd "$SITE_DIR"
if [ ! -d ".git" ]; then
  git init
  git checkout -b main 2>/dev/null || git checkout -b master
fi

git add -A
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git"
git push -u origin main --force 2>&1

# 4. Créer projet Coolify
PROJECT=$(curl -s -X POST "$COOLIFY_BASE_URL/api/v1/projects" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$REPO_NAME\",\"description\":\"Déployé via script\"}")
PROJECT_UUID=$(echo $PROJECT | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)

# 5. Créer application
APP=$(curl -s -X POST "$COOLIFY_BASE_URL/api/v1/applications/public" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_uuid\": \"$PROJECT_UUID\",
    \"server_uuid\": \"$COOLIFY_SERVER_UUID\",
    \"environment_name\": \"production\",
    \"git_repository\": \"https://github.com/$GITHUB_USER/$REPO_NAME\",
    \"git_branch\": \"main\",
    \"build_pack\": \"dockerfile\",
    \"ports_exposes\": \"80\",
    \"name\": \"$REPO_NAME\"
  }")
APP_UUID=$(echo $APP | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)
URL=$(echo $APP | grep -o '"domains":"[^"]*"' | cut -d'"' -f4)

# 6. Déployer
echo "🔄 Déploiement en cours..."
curl -s -X POST "$COOLIFY_BASE_URL/api/v1/deploy?uuid=$APP_UUID&force=true" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" > /dev/null

# 7. Polling
for i in {1..18}; do
  STATUS=$(curl -s "$COOLIFY_BASE_URL/api/v1/applications/$APP_UUID" \
    -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" | grep -o '"status":"[^"]*"' | head -1)
  
  if echo "$STATUS" | grep -q "running"; then
    echo "✅ Déploiement réussi"
    break
  fi
  
  echo "  Tentative $i/18..."
  sleep 10
done

# 8. Vérification HTTP
for i in {1..24}; do
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL")
  if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "🎉 SITE_EN_LIGNE: $URL"
    exit 0
  fi
  sleep 5
done

echo "⚠️ Site déployé mais non accessible immédiatement"
echo "🔗 URL: $URL"
```

**Utilisation :**
```bash
chmod +x deploy.sh
./deploy.sh /app/mon-site
```
