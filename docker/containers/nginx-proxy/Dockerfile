FROM nginx:1.27-alpine

COPY docker/containers/nginx-proxy/templates/ /etc/nginx/templates/
COPY docker/containers/nginx-proxy/proxy.inc /etc/nginx/proxy.inc

EXPOSE 80
