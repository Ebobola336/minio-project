# Инструкция по развёртыванию

## Требования

- Ubuntu 24.04 LTS (хост)
- Docker Engine ≥ 26.0
- Docker Compose Plugin ≥ 2.28
- 8 GB RAM, 50 GB свободного места

## Шаг 1: Клонирование репозитория

```bash
git clone https://github.com/your-username/minio-project.git
cd minio-project
```

## Шаг 2: Подготовка хоста

```bash
sudo bash deploy/scripts/bootstrap.sh
```

Скрипт установит Docker, настроит ядро и создаст TLS-сертификат.

## Шаг 3: Настройка переменных окружения

```bash
cp .env.example .env
nano .env   # Заполните MINIO_ROOT_USER и другие переменные
```

## Шаг 4: Заполнение Docker Secrets

```bash
# Установите реальный пароль (минимум 8 символов)
echo "YourStrongPassword123!" > secrets/minio_root_password.txt
echo "YourGrafanaPassword!"   > secrets/grafana_admin_password.txt
chmod 600 secrets/*.txt
```

## Шаг 5: Запуск инфраструктуры

```bash
cd deploy
docker compose up -d --build
```

## Шаг 6: Валидация

```bash
# Проверка статуса контейнеров
docker compose ps

# Автоматические тесты
bash deploy/scripts/tests/test_healthcheck.sh
bash deploy/scripts/tests/test_minio.sh
```

## Шаг 7: Доступ к сервисам

| Сервис | URL | Логин |
|---|---|---|
| MinIO S3 API | https://localhost:9000 | из .env |
| MinIO Console | https://localhost:9443 | из .env |
| Grafana | http://localhost:3000 | admin / из secrets/ |
| Prometheus | http://localhost:9090 | — |

## Остановка

```bash
# Остановка без удаления данных
docker compose down

# Полная очистка (данные удаляются!)
docker compose down -v
```

## Troubleshooting

### Контейнер не запускается
```bash
docker compose logs minio1
```

### TLS-ошибка в браузере
Используйте `--insecure` или добавьте `certs/server.crt` в доверенные сертификаты.

### Кластер не формируется
Убедитесь, что все 4 ноды запущены одновременно — MinIO требует кворум.
