FROM nginx:alpine
MAINTAINER Arnold Miranda <aksine.am@gmail.com>

COPY public /usr/share/nginx/html/blog
COPY main /usr/share/nginx/html/main
COPY nginx.conf /etc/nginx/nginx.conf