FROM openresty/openresty:alpine-fat

COPY lib/resty /etc/nginx/lua/resty
COPY nginx.conf /usr/local/openresty/nginx/conf/

EXPOSE 80 81 8080

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/openresty/bin/openresty"]
