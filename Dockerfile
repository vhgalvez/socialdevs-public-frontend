# Dockerfile para construir la app Vue y servir con Nginx

# Etapa 1: Construcción de la app Vue
FROM node:18-alpine AS build-stage

WORKDIR /app

# Copiar primero dependencias para aprovechar la caché
COPY package*.json ./

# Instala dependencias de producción
RUN npm install --omit=dev

# Copiar el resto del código
COPY . .

# Establecer entorno para producción
ENV NODE_ENV=production

# Compilar la app Vue
RUN npm run build

# Etapa 2: Imagen liviana con Nginx
FROM nginx:stable-alpine AS production-stage

# Eliminar configuración por defecto
RUN rm /etc/nginx/conf.d/default.conf

# Copiar artefactos y configuración personalizada
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]