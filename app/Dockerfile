FROM node:16.16.0-bullseye as builder
# make the 'app' folder the current working directory
WORKDIR /app
# copy both 'package.json' and 'package-lock.json' (if available)
COPY package*.json ./
# install project dependencies
RUN npm install
# copy project files and folders to the current working directory (i.e. 'app' folder)
COPY . .
# build app for production with minification
RUN npm run build
RUN npm audit fix

# nginx state for serving content
FROM nginx:1.23.0
RUN rm /etc/nginx/conf.d/default.conf
COPY ./docker/nginx/prod.conf /etc/nginx/conf.d/
COPY ./docker/nginx/nginx.conf /etc/nginx/
COPY ./docker/nginx/*.pem /etc/nginx/certificates/
COPY ./docker/nginx/*.key /etc/nginx/certificates/
# Set working directory to nginx asset directory
WORKDIR /usr/share/nginx/html
# Remove default nginx static assets
RUN rm -rf ./*
# Copy static assets from builder stage
COPY --from=builder /app/dist .
# Containers run nginx with global directives and daemon off
EXPOSE 443
ENTRYPOINT ["nginx", "-g", "daemon off;"]