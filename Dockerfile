# Build stage: install dependencies so the final image can stay small.
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Runtime stage: copy only what is needed to run the app.
FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
