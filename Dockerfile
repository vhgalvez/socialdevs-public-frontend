# Dockerfile para construir la app Vue y servir con Nginx

# Etapa 1: Construcción de la app Vue
FROM node:18-alpine AS build-stage

WORKDIR /app

# Copiar solo los archivos necesarios primero (mejor caché)
COPY package*.json ./

# Usa `npm ci` si hay lockfile, de lo contrario usa `npm install`
RUN if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; \
    then npm ci --omit=dev; \
    else npm install --omit=dev; \
    fi

# Copiar el resto de los archivos
COPY . .

# Asegura variables necesarias para producción
ENV NODE_ENV=production

# Compilar la app
RUN npm run build

# Etapa 2: Imagen liviana con Nginx para servir los archivos
FROM nginx:stable-alpine AS production-stage

# Elimina la config por defecto
RUN rm /etc/nginx/conf.d/default.conf

# Copiar artefactos compilados
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Puerto HTTP
EXPOSE 80

# Entrypoint de Nginx
CMD ["nginx", "-g", "daemon off;"]