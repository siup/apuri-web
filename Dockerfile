FROM nginx:alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY protected/ /usr/share/nginx/html/protected/

EXPOSE 80
