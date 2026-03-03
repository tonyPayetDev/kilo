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

## ⚙️ Configuration requise (à demander au dev si absente)

Avant de commencer, vérifier que ces variables sont disponibles. Si elles ne le sont pas,
demander à l'utilisateur de les fournir :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `GITHUB_TOKEN` | Personal Access Token GitHub (classic PAT, scope `repo`) | `ghp_xxxx...` |
| `GITHUB_USER` | Nom d'utilisateur GitHub | `monPseudo` |
| `COOLIFY_SERVER_UUID` | UUID du serveur Coolify cible | `w8gwk4...` |
| `COOLIFY_PROJECT_UUID` | UUID du projet Coolify (optionnel) | `m8soco...` |
| `SITE_DIR` | Chemin absolu du dossier à déployer | `/work/mon-site` |

> 💡 **Où trouver ces valeurs ?**
> - GitHub token : https://github.com/settings/tokens → "Generate new token (classic)" → scope `repo`
> - Server/Project UUIDs : Interface Coolify → Settings → l'UUID est dans l'URL ou les infos du serveur/projet

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

### 5. Configurer l'application Coolify via MCP

**Rechercher si une application existe déjà** avec `mcp__coolify__list_applications`, chercher `git_repository` contenant `$REPO_NAME`.

**Si l'application EXISTE déjà** :
- Mettre à jour `git_repository` via `mcp__coolify__application` action `update`

**Si l'application N'EXISTE PAS** :
- Identifier le `project_uuid` :
  - Chercher dans `mcp__coolify__projects` un projet dont le nom correspond
  - Si `COOLIFY_PROJECT_UUID` a été fourni par l'utilisateur, l'utiliser directement
  - Sinon, créer un nouveau projet
- Créer l'application :

```json
{
  "action": "create_public",
  "name": "<nom-du-repo>",
  "git_repository": "https://github.com/<GITHUB_USER>/<nom-du-repo>",
  "git_branch": "<branche>",
  "build_pack": "dockerfile",
  "ports_exposes": "80",
  "server_uuid": "<COOLIFY_SERVER_UUID>",
  "project_uuid": "<project_uuid>",
  "environment_name": "production"
}
```

### 6. Déclencher le déploiement

```
mcp__coolify__deploy(tag_or_uuid=<app_uuid>, force=true)
```

Noter le `deployment_uuid` retourné. Attendre 2-3 secondes avant de commencer le polling.

### 7. Polling statut — toutes les 10s, max 3 min (18 tentatives)

Appeler `mcp__coolify__get_application(uuid=<app_uuid>)` et vérifier `status`.

| Statut | Action |
|--------|--------|
| contient `"running"` | ✅ Passer à l'étape 8 |
| contient `"failed"` ou `"error"` | ❌ Afficher les logs via `mcp__coolify__application_logs`, retourner `ERREUR_DEPLOY: status=<status>` |
| 18 tentatives dépassées | ❌ Retourner `ERREUR_TIMEOUT: déploiement dépasse 3 minutes` |

Entre chaque tentative : `Bash("sleep 10")`.

### 8. Récupérer l'URL du site

- L'URL = champ `fqdn` de l'application Coolify
- Si `fqdn` commence par `http://` ou `https://` → utiliser tel quel
- Si `fqdn` est null ou vide → utiliser `http://<app_uuid>.<IP_SERVEUR>.sslip.io`
- Sinon → préfixer avec `http://`

### 9. Vérification HTTP — toutes les 5s, max 2 min (24 tentatives)

```bash
curl -s -o /dev/null -w '%{http_code}' --max-time 5 '<url>'
```

| Code HTTP | Action |
|-----------|--------|
| `200` | ✅ Succès, passer à l'étape 10 |
| 24 tentatives dépassées | ❌ Retourner `ERREUR_HTTP: site ne répond pas en 2 minutes` |

Entre chaque tentative : `Bash("sleep 5")`.

### 10. Résultat final

```
SITE_EN_LIGNE: <url>
```

---

## 🔧 Dépannage

| Problème | Solution |
|----------|----------|
| `git push` échoue avec 403 | Vérifier que le token a le scope `repo` |
| Coolify status `failed` | Consulter les logs avec `mcp__coolify__deployment` action `get` |
| `fqdn` null dans Coolify | Utiliser le format sslip.io avec l'IP du serveur |
| Site répond 502/504 | Le container démarre encore, attendre 30s et réessayer |

---

## 📝 Notes techniques

- Le Dockerfile nginx minimal convient pour **tout site statique** (HTML/CSS/JS/assets)
- Pour un site avec backend (Node, PHP, etc.), un `Dockerfile` doit être présent dans le dossier
- `build_pack: dockerfile` est le mode recommandé pour un contrôle maximal
- Les repos GitHub créés sont publics par défaut ; changer `"private": false` en `true` si nécessaire
