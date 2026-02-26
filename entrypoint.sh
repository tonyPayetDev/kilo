#!/bin/sh

# Vérifier que la clé est présente
if [ -z "$KILO_API_KEY" ]; then
  echo "⚠️  KILO_API_KEY non définie !"
  echo "Définis-la via Coolify ou Docker Compose."
  exec "$@"
else
  echo "🧠 Clé API trouvée, initialisation de Kilo..."
  # Exemple d’auth : si le CLI accepte un login via variable
  kilo login --api-key $KILO_API_KEY
  echo "➡️  CLI Kilo prêt !"
  
  # Si tu veux exécuter une commande par défaut,
  # remplace ci‑dessous
  exec "$@"
fi
