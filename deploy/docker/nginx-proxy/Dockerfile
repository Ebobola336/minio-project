# @file Dockerfile
# @brief Многоэтапная сборка Nginx reverse-proxy для TLS-терминации MinIO.
# @author Тимошенко (заполнить ФИО)
# @date 2025-05-25
# @version 1.0.0
# @license GNU GPLv3

# ==============================================================================
# ЭТАП 1: Финальный runtime-образ (alpine — минимальная поверхность атаки)
# ==============================================================================
FROM nginx:1.27-alpine

# Установка curl для healthcheck (с очисткой кэша apk в одной команде RUN)
RUN apk add --no-cache curl=~8

# Создание временных директорий nginx (tmpfs в Compose — read-only ФС)
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp && \
    # Nginx master запускается под root, воркеры — под nginx (это нормально для Nginx)
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid && \
    # Каталог для TLS-сертификатов (монтируется через Compose :ro)
    mkdir -p /etc/nginx/certs && \
    chown nginx:nginx /etc/nginx/certs

# Экспорт портов: S3 API и MinIO Console
EXPOSE 9000 9443

# Healthcheck: S3 liveness endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f --insecure https://localhost:9000/minio/health/live || exit 1

# Запуск в exec-формате (JSON-массив — корректная обработка сигналов Docker SIGTERM)
ENTRYPOINT ["nginx", "-g", "daemon off;"]
