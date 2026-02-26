# Base image
FROM node:20-alpine

# Create app directory
WORKDIR /app

# Installer dépendances si nécessaire
RUN apk add --no-cache bash git curl

# Installer le CLI Kilo (hypothétique)
# Remplace cette ligne si l'installation diffère
RUN npm install -g kilo-cli

# Copier un script d’entrée si besoin
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Variables d’environnement (définies en compose)
ENV KILO_API_KEY=""

# Définit le point d’entrée
ENTRYPOINT ["/app/entrypoint.sh"]

# Command par défaut (ouvre un shell)
CMD ["sh"]
