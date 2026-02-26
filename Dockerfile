FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache bash git curl
RUN npm install -g @kilocode/cli

ENV KILO_API_KEY=""

CMD ["sh", "-c", "sleep infinity"]
