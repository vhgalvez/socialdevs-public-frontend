# 🔐 Etapa 1: Construcción con Node.js parcheado
FROM node:18.20.4-alpine AS build-stage

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias primero (mejor caché)
COPY package*.json ./

# Usar npm ci si existe lockfile, si no usar install
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

# Copiar el resto de los archivos
COPY . .

# Variables para producción
ENV NODE_ENV=production

# Compilar la aplicación Vue
RUN npm run build

# 🧼 Limpieza opcional (reduce peso)
RUN npm cache clean --force && rm -rf /root/.npm /tmp/*

# 🚀 Etapa 2: Imagen ligera de producción
FROM nginx:stable-alpine AS production-stage

# Eliminar configuración por defecto de Nginx (silenciosamente si no existe)
RUN rm -f /etc/nginx/conf.d/default.conf

# Copiar archivos estáticos construidos
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Copiar tu configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponer puerto
EXPOSE 80

# Ejecutar Nginx
CMD ["nginx", "-g", "daemon off;"]