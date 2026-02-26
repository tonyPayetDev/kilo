FROM node:20-alpine

WORKDIR /app

# Installer bash, git et curl
RUN apk add --no-cache bash git curl

# Installer Kilo CLI officiel
RUN npm install -g @kilocode/cli

# Copier le script d’entrée si nécessaire
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Variables d'environnement
ENV KILO_API_KEY=""

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["sh"]
