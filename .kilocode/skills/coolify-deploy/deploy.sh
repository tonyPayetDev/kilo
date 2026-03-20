#!/bin/bash
# deploy.sh - Déploiement complet d'un site sur Coolify
# Variables depuis les variables d'environnement Coolify

# ============================================
# 1. VÉRIFICATION DES VARIABLES D'ENVIRONNEMENT
# ============================================

# Vérifier que toutes les variables requises sont définies
if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ ERREUR: GITHUB_TOKEN non défini"
  echo "   Définir la variable d'environnement GITHUB_TOKEN dans Coolify"
  exit 1
fi

if [ -z "$GITHUB_USER" ]; then
  echo "❌ ERREUR: GITHUB_USER non défini"
  echo "   Définir la variable d'environnement GITHUB_USER dans Coolify"
  exit 1
fi

if [ -z "$COOLIFY_SERVER_UUID" ]; then
  echo "❌ ERREUR: COOLIFY_SERVER_UUID non défini"
  echo "   Définir la variable d'environnement COOLIFY_SERVER_UUID dans Coolify"
  exit 1
fi

if [ -z "$COOLIFY_BASE_URL" ]; then
  echo "❌ ERREUR: COOLIFY_BASE_URL non défini"
  echo "   Définir la variable d'environnement COOLIFY_BASE_URL dans Coolify"
  exit 1
fi

if [ -z "$COOLIFY_ACCESS_TOKEN" ]; then
  echo "❌ ERREUR: COOLIFY_ACCESS_TOKEN non défini"
  echo "   Définir la variable d'environnement COOLIFY_ACCESS_TOKEN dans Coolify"
  exit 1
fi

# ============================================
# 2. CONFIGURATION
# ============================================

SITE_DIR="${1:-/app/mon-site}"  # Premier argument ou défaut
REPO_NAME=$(basename "$SITE_DIR")

echo ""
echo "🚀 Déploiement de $REPO_NAME"
echo "   Dossier: $SITE_DIR"
echo "   Repo: $GITHUB_USER/$REPO_NAME"
echo "   Serveur: $COOLIFY_SERVER_UUID"
echo ""

# ============================================
# 3. CONFIGURER GIT
# ============================================

echo "⚙️  Configuration git..."
git config --global user.email "deploy@coolify.local" 2>/dev/null || true
git config --global user.name "Coolify Deploy" 2>/dev/null || true
git config --global --add safe.directory "$SITE_DIR" 2>/dev/null || true

# ============================================
# 4. CRÉER LE REPO GITHUB SI INEXISTANT
# ============================================

echo "📦 Vérification du repo GitHub..."
REPO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME")

if [ "$REPO_STATUS" = "404" ]; then
  echo "   Création du repo $REPO_NAME..."
  curl -s -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"$REPO_NAME\",\"private\":false,\"auto_init\":false}"
  sleep 2
  echo "   ✅ Repo créé"
else
  echo "   ✅ Repo existe déjà"
fi

# ============================================
# 5. PUSH SUR GITHUB
# ============================================

echo "📤 Push sur GitHub..."
cd "$SITE_DIR"

if [ ! -d ".git" ]; then
  git init
  git checkout -b main 2>/dev/null || git checkout -b master
fi

# Créer Dockerfile si inexistant
if [ ! -f "Dockerfile" ]; then
  echo "   Création du Dockerfile..."
  cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY . /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
fi

git add -A
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git"
git push -u origin main --force 2>&1

# ============================================
# 6. CRÉER PROJET COOLIFY
# ============================================

echo "🔧 Configuration Coolify..."
PROJECT=$(curl -s -X POST "$COOLIFY_BASE_URL/api/v1/projects" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$REPO_NAME\",\"description\":\"Déployé via script\"}")
PROJECT_UUID=$(echo $PROJECT | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "   Projet: $PROJECT_UUID"

# ============================================
# 7. CRÉER APPLICATION
# ============================================

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
URL=$(echo $APP | grep -o '"domains":"[^"]*"' | cut -d'"' -f4 | sed 's/\\//g')

echo "   Application: $APP_UUID"

# ============================================
# 8. DÉPLOYER
# ============================================

echo "🔄 Lancement du déploiement..."
curl -s -X POST "$COOLIFY_BASE_URL/api/v1/deploy?uuid=$APP_UUID&force=true" \
  -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" > /dev/null

# ============================================
# 9. POLLING STATUT
# ============================================

echo "⏳ Attente du déploiement (max 3 min)..."
for i in {1..18}; do
  STATUS=$(curl -s "$COOLIFY_BASE_URL/api/v1/applications/$APP_UUID" \
    -H "Authorization: Bearer $COOLIFY_ACCESS_TOKEN" | grep -o '"status":"[^"]*"' | head -1)
  
  if echo "$STATUS" | grep -q "running"; then
    echo ""
    echo "✅ Déploiement réussi!"
    break
  elif echo "$STATUS" | grep -q "failed\|error"; then
    echo ""
    echo "❌ ERREUR: $STATUS"
    exit 1
  fi
  
  echo "   Tentative $i/18..."
  sleep 10
done

# ============================================
# 10. VÉRIFICATION HTTP
# ============================================

echo ""
echo "🔍 Vérification HTTP..."
for i in {1..24}; do
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL")
  if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "🎉 SITE_EN_LIGNE: $URL"
    exit 0
  fi
  sleep 5
done

echo ""
echo "⚠️  Site déployé mais non accessible immédiatement"
echo "🔗 URL: $URL"
