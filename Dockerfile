FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache bash git curl
RUN npm install -g @kilocode/cli
ENV KILO_API_KEY=""

# Copier le skill dans .kilocode/skills/coolify-deploy/
COPY .kilocode/skills/coolify-deploy/SKILL.md .kilocode/skills/coolify-deploy/SKILL.md

# Copier la config MCP
COPY mcp.json mcp.json

# Container qui reste vivant proprement
CMD ["tail", "-f", "/dev/null"]
