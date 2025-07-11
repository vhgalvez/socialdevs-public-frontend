# Dockerfile para construir la app Vue y servir con Nginx

# Etapa 1: Construcción de la app Vue
FROM node:18-alpine AS build-stage

WORKDIR /app

COPY package*.json ./

# ❗ Usa npm install si no hay package-lock.json
RUN npm install

COPY . .

ENV NODE_ENV=production
RUN npm run build

# Etapa 2: Imagen liviana con Nginx
FROM nginx:stable-alpine AS production-stage

RUN rm /etc/nginx/conf.d/default.conf

COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]