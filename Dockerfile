FROM openresty/openresty:alpine-fat

LABEL org.opencontainers.image.title="lua-resty-ngxstats"
LABEL org.opencontainers.image.description="OpenResty/NGINX metrics collection and Prometheus exporter"
LABEL org.opencontainers.image.version="1.1.0"
LABEL org.opencontainers.image.source="https://github.com/abtreece/lua-resty-ngxstats"
LABEL org.opencontainers.image.licenses="MIT"

COPY lib/resty /etc/nginx/lua/resty
COPY nginx.conf /usr/local/openresty/nginx/conf/

EXPOSE 80 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/status || exit 1

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
