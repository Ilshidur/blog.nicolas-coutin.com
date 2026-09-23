FROM node:22-bookworm-slim AS build
WORKDIR /app
ENV CI=true
ENV GATSBY_TELEMETRY_DISABLED=1

COPY package.json package-lock.json ./
RUN npm ci

COPY . ./
RUN npm run build


FROM nginxinc/nginx-unprivileged:1.28-alpine-slim

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/public /usr/share/nginx/html

EXPOSE 8080
