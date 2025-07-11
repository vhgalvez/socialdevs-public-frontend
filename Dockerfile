
# Dockerfile para construir la app Vue y servir con Nginx
# Etapa 1: Construcción de la app Vue
FROM node:18-alpine AS build-stage

WORKDIR /app

# Copiar solo los archivos necesarios primero (mejor caché)
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Asegura variables necesarias para producción (si aplica)
ENV NODE_ENV=production

RUN npm run build

# Etapa 2: Imagen liviana con Nginx
FROM nginx:stable-alpine AS production-stage

# Elimina archivos temporales del default.conf si existen
RUN rm /etc/nginx/conf.d/default.conf

# Copia archivos de construcción
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponer puerto estándar HTTP
EXPOSE 80

# Entrypoint
CMD ["nginx", "-g", "daemon off;"]