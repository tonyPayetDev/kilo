FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache bash git curl
RUN npm install -g @kilocode/cli
ENV KILO_API_KEY=""

# Copier le skill dans .kilocode/skills/coolify-deploy/
COPY .kilocode/skills/coolify-deploy/SKILL.md .kilocode/skills/coolify-deploy/SKILL.md
COPY .kilocode/skills/coolify-deploy/deploy.sh .kilocode/skills/coolify-deploy/deploy.sh

COPY .kilocode/skills/frontend-design/SKILL.md .kilocode/skills/frontend-design/SKILL.md
COPY .kilocode/skills/webapp-testing/SKILL.md .kilocode/skills/webapp-testing/SKILL.md
COPY .kilocode/skills/webapp-testing/_meta.json .kilocode/skills/webapp-testing/_meta.json

# Copier la config MCP
COPY mcp.json mcp.json

# Container qui reste vivant proprement
CMD ["tail", "-f", "/dev/null"]
