# Dockerfile para construir la app Vue y servir con Nginx

# Etapa 1: Construcción de la app Vue
FROM node:18-alpine AS build-stage

WORKDIR /app

# Copiar archivos de dependencias primero para aprovechar la caché
COPY package*.json ./

# Instalar todas las dependencias (incluye vite si está como devDependency)
RUN npm ci

# Copiar el resto del código fuente
COPY . .

# Establecer entorno de producción
ENV NODE_ENV=production

# Construir la aplicación
RUN npm run build

# Etapa 2: Imagen liviana con Nginx para servir los archivos
FROM nginx:stable-alpine AS production-stage

# Eliminar la configuración por defecto de Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copiar artefactos generados y configuración personalizada
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponer puerto HTTP estándar
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]