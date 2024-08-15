FROM nginx:alpine
MAINTAINER Arnold Miranda <aksine.am@gmail.com>

COPY public /usr/share/nginx/html/blog
COPY www /usr/share/nginx/html/www
COPY nginx.conf /etc/nginx/nginx.conf