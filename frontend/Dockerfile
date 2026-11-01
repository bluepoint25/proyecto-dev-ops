# ─── Etapa 1: build de produccion con Vite ────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# Las variables VITE_* se incrustan en el bundle en tiempo de build
ARG VITE_API_URL=""
ARG VITE_COGNITO_DOMAIN=""
ARG VITE_COGNITO_CLIENT_ID=""
ARG VITE_REDIRECT_URI="http://localhost:5173"
RUN npm run build

# ─── Etapa 2: nginx sin privilegios sirviendo los estaticos ───────────────────
FROM nginxinc/nginx-unprivileged:1.27-alpine
ARG GIT_SHA=local
LABEL org.opencontainers.image.title="pedidos360-frontend" \
      org.opencontainers.image.source="https://github.com/bluepoint25/proyecto-dev-ops" \
      org.opencontainers.image.revision="${GIT_SHA}"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8080/ || exit 1
