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

## ⚙️ Configuration automatique des variables

**Le skill charge automatiquement les variables depuis `/app/fichier.txt`** si elles ne sont pas déjà définies :

```bash
# Charger automatiquement depuis /app/fichier.txt
if [ -f "/app/fichier.txt" ]; then
  # Extraire le token GitHub (première ligne)
  export GITHUB_TOKEN=$(head -1 /app/fichier.txt)
  # Extraire le UUID Coolify (ligne avec uuid:)
  export COOLIFY_SERVER_UUID=$(grep "uuid:" /app/fichier.txt | cut -d: -f2 | tr -d ' ')
fi

# Valeurs par défaut
export GITHUB_USER="${GITHUB_USER:-tonyPayetDev}"
export COOLIFY_BASE_URL="${COOLIFY_BASE_URL:-http://158.220.127.234:8000}"
export COOLIFY_ACCESS_TOKEN="${COOLIFY_ACCESS_TOKEN:-32|EHh0msiQ6mFH6RdD3w7PRNMswA07HD3WXN7nZiW940ba2077}"
```

**Si le fichier n'existe pas**, créer `/app/fichier.txt` :
```
ghp_votre_token_github
uuid: c4c0wo4cw8cswkwsooswcc8g
```

> 💡 **Où trouver ces valeurs ?**
> - **GitHub token** : https://github.com/settings/tokens → "Generate new token (classic)" → scope `repo`
> - **Coolify Server UUID** : Interface Coolify → Settings → Servers → UUID dans l'URL
>
> ⚠️ **Important : Utiliser un token CLASSIC GitHub, pas fine-grained !**

---

## Utilisation rapide

```bash
# Déployer un site (les variables sont chargées automatiquement)
/app/.kilocode/skills/coolify-deploy/deploy.sh /app/mon-site
```

---

## Étapes d'exécution détaillées

### 1. Identifier le dossier source

- Résoudre le chemin absolu depuis l'argument fourni
- Le **nom du repo GitHub** = nom du dossier (sans trailing slash, en minuscules, sans espaces)
- Exemple : `/work/mon-super-site` → repo `mon-super-site`

### 2. Vérifier les prérequis

```bash
# Charger les variables automatiquement
if [ -f "/app/fichier.txt" ]; then
  export GITHUB_TOKEN=$(head -1 /app/fichier.txt)
  export COOLIFY_SERVER_UUID=$(grep "uuid:" /app/fichier.txt | cut -d: -f2 | tr -d ' ')
fi
export GITHUB_USER="${GITHUB_USER:-tonyPayetDev}"
export COOLIFY_BASE_URL="${COOLIFY_BASE_URL:-http://158.220.127.234:8000}"
export COOLIFY_ACCESS_TOKEN="${COOLIFY_ACCESS_TOKEN:-32|EHh0msiQ6mFH6RdD3w7PRNMswA07HD3WXN7nZiW940ba2077}"

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
# Configuration
SITE_DIR="/app/mon-site"  # Modifier selon le dossier
REPO_NAME=$(basename "$SITE_DIR")

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
