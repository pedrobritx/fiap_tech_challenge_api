# ---------- builder ----------
  FROM node:20-alpine AS builder
  WORKDIR /app
  
  COPY package*.json ./
  RUN npm ci --legacy-peer-deps && npm cache clean --force
  
  COPY . .
  RUN npm run build
  RUN npx typeorm-ts-node-commonjs migration:run -d dist/db/data-source-cli.js
  
  # ---------- runtime ----------
  FROM node:20-alpine
  WORKDIR /app
  
  RUN apk add --no-cache dumb-init
  
  # Só deps de produção
  COPY package*.json ./
  RUN npm ci --only=production --legacy-peer-deps && npm cache clean --force
  
  COPY --from=builder /app/dist ./dist
  
  USER node  # opcional: criar usuário não-root
  
  EXPOSE 3000
  HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1))"
  
  ENTRYPOINT ["dumb-init", "--"]
  CMD ["node", "dist/main.js"]