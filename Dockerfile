# 🔐 Etapa 1: Construcción con Node.js parcheado
FROM node:18.20.4-alpine AS build-stage

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias primero (mejor caché)
COPY package*.json ./

# Instalar TODAS las dependencias (incluyendo devDependencies como vite)
RUN if [ -f package-lock.json ]; then \
      npm ci; \
    else \
      npm install; \
    fi

# Copiar el resto de los archivos
COPY . .

# Variables de entorno para producción
ENV NODE_ENV=production

# Compilar la aplicación Vue
RUN npm run build

# 🧼 Limpieza opcional (reduce tamaño final de la imagen)
RUN rm -rf node_modules && npm cache clean --force && rm -rf /root/.npm /tmp/*

# 🚀 Etapa 2: Imagen ligera de producción
FROM nginx:stable-alpine AS production-stage

# Eliminar configuración por defecto de Nginx (silenciosamente si no existe)
RUN rm -f /etc/nginx/conf.d/default.conf

# Copiar los archivos estáticos generados
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Copiar tu configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Puerto estándar
EXPOSE 80

# Ejecutar Nginx
CMD ["nginx", "-g", "daemon off;"]