# MinIO Object Storage — Курсовой проект №18

> **Курс:** Администрирование ОС Linux  
> **Тема:** Развёртывание и настройка распределённого хранилища объектов (MinIO)  
> **Вариант:** 18  
> **Автор:** Тимошенко (заполнить ФИО полностью)

---

## Описание

Проект реализует S3-совместимое объектное хранилище **MinIO** в режиме распределённого Erasure Code кластера из 4 нод, развёрнутое через Docker Compose. Инфраструктура включает TLS reverse-proxy (Nginx), мониторинг (Prometheus + Grafana) и IAM-управление через политики MinIO.

| Компонент | Технология | Версия |
|---|---|---|
| Объектное хранилище | MinIO (4 ноды) | RELEASE.2024-11-07 |
| Reverse-proxy / TLS | Nginx | 1.27-alpine |
| Мониторинг | Prometheus | v2.54.1 |
| Визуализация | Grafana | 11.3.0 |

---

## Быстрый старт

```bash
# 1. Подготовка хоста (Docker, зависимости, TLS-сертификаты)
sudo bash deploy/scripts/bootstrap.sh

# 2. Переменные окружения
cp .env.example .env && nano .env

# 3. Запуск
cd deploy && docker compose up -d --build

# 4. Проверка
docker compose ps
```

## Доступные сервисы

| Сервис | URL |
|---|---|
| MinIO S3 API | https://localhost:9000 |
| MinIO Console | https://localhost:9443 |
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |

## Тестирование

```bash
bash deploy/scripts/tests/test_minio.sh
bash deploy/scripts/tests/test_healthcheck.sh
bash deploy/scripts/tests/test_ha.sh
```

## Структура репозитория

```
.
├── .github/workflows/      # CI/CD конвейеры
├── config/nginx/           # Конфигурация Nginx
├── config/sysctl.d/        # Hardening ядра
├── config/prometheus/      # Конфигурация Prometheus
├── config/grafana/         # Дашборды Grafana (IaC)
├── deploy/docker/          # Dockerfile-сборки
├── deploy/scripts/         # Скрипты автоматизации
├── deploy/docker-compose.yml
├── docs/                   # Техническая документация
├── thesis/                 # Отчёт (PDF)
├── .env.example
├── .gitignore
├── LICENSE.txt
└── README.md
```

## Матрица ролей

| Роль | Задачи |
|---|---|
| DevOps / IaC Engineer | Docker Compose, Dockerfile, bootstrap.sh |
| System Administrator | Конфигурация MinIO, Nginx, IAM-политики |
| Observability Engineer | Prometheus, Grafana, TLS, линтеры, CI/CD |

## Лицензирование

- Инфраструктурный код — **GNU GPLv3**
- Технический отчёт и схемы — **CC BY-SA 4.0**
