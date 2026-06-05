#!/bin/bash
# @file bootstrap.sh
# @brief Скрипт первичной подготовки чистой ОС Linux перед развёртыванием MinIO.
# @author Тимошенко (заполнить ФИО)
# @date 2025-05-25
# @version 1.0.0
#
# @details
# Выполняемые этапы:
# 1. Проверка прав root и версии Ubuntu.
# 2. Обновление пакетов, установка Docker Engine + Compose Plugin.
# 3. Применение параметров hardening ядра.
# 4. Создание каталога secrets/ с файлами-шаблонами.
# 5. Генерация самоподписанного TLS-сертификата для Nginx.
#
# @license GNU GPLv3 <https://gnu.org>

set -euo pipefail

readonly SCRIPT_NAME="bootstrap.sh"
readonly LOG_TAG="BOOTSTRAP"

log_info() {
    echo "[${LOG_TAG}][INFO]  $(date '+%Y-%m-%d %H:%M:%S') — $1"
}

log_error() {
    echo "[${LOG_TAG}][ERROR] $(date '+%Y-%m-%d %H:%M:%S') — $1" >&2
    exit 1
}

# @brief Проверка прав суперпользователя.
# @return 0 Если скрипт запущен с правами root.
# @return 1 Если не root — завершение с ошибкой.
check_root_privileges() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Запустите с правами root: sudo bash ${SCRIPT_NAME}"
    fi
    log_info "Права root подтверждены."
}

# @brief Проверка версии ОС (только Ubuntu LTS).
# @return 0 При совместимом дистрибутиве.
check_os_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "/etc/os-release не найден."
    fi
    # shellcheck source=/dev/null
    source /etc/os-release
    local os_id
    os_id=$(echo "${ID:-}" | tr '[:upper:]' '[:lower:]')
    if [[ "${os_id}" != "ubuntu" ]]; then
        log_error "Поддерживается только Ubuntu. Обнаружен: ${os_id}"
    fi
    log_info "ОС: ${PRETTY_NAME}"
}

# @brief Обновление индекса пакетов apt.
# @return 0 При успехе. @return 1 При недоступности сети.
update_system_repositories() {
    log_info "Обновление apt..."
    if ! apt-get update -y; then
        log_error "Не удалось обновить индекс пакетов."
    fi
}

# @brief Установка Docker Engine из официального репозитория.
# @return 0 При успешной установке.
install_docker() {
    log_info "Установка зависимостей..."
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release openssl

    log_info "Добавление GPG-ключа Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y --no-install-recommends \
        docker-ce docker-compose-plugin

    log_info "Docker: $(docker --version)"
    log_info "Docker Compose: $(docker compose version)"
}

# @brief Применение hardening-параметров ядра из config/sysctl.d/.
# @return 0 При успехе или если файл не найден.
apply_kernel_hardening() {
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"
    local sysctl_src="${script_dir}/../../config/sysctl.d/99-hardening.conf"

    if [[ ! -f "${sysctl_src}" ]]; then
        log_info "Файл sysctl hardening не найден, пропуск."
        return 0
    fi
    cp "${sysctl_src}" /etc/sysctl.d/99-hardening.conf
    sysctl --system
    log_info "Параметры ядра применены."
}

# @brief Создание каталога secrets/ и файлов-шаблонов Docker Secrets.
# @return 0 При успехе.
prepare_secrets_directory() {
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"
    local secrets_dir="${script_dir}/../../secrets"

    mkdir -p "${secrets_dir}"

    if [[ ! -f "${secrets_dir}/minio_root_password.txt" ]]; then
        echo "CHANGE_ME_STRONG_PASSWORD_HERE" > "${secrets_dir}/minio_root_password.txt"
        chmod 600 "${secrets_dir}/minio_root_password.txt"
        log_info "ВНИМАНИЕ: Заполните secrets/minio_root_password.txt реальным паролем!"
    fi

    if [[ ! -f "${secrets_dir}/grafana_admin_password.txt" ]]; then
        echo "CHANGE_ME_GRAFANA_PASSWORD_HERE" > "${secrets_dir}/grafana_admin_password.txt"
        chmod 600 "${secrets_dir}/grafana_admin_password.txt"
        log_info "ВНИМАНИЕ: Заполните secrets/grafana_admin_password.txt реальным паролем!"
    fi
}

# @brief Генерация самоподписанного TLS-сертификата (RSA-4096) для Nginx.
# @return 0 Если сертификаты уже существуют или успешно созданы.
generate_self_signed_cert() {
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"
    local certs_dir="${script_dir}/../../certs"

    if [[ -f "${certs_dir}/server.crt" && -f "${certs_dir}/server.key" ]]; then
        log_info "TLS-сертификаты уже существуют."
        return 0
    fi

    mkdir -p "${certs_dir}"
    log_info "Генерация TLS-сертификата (RSA-4096, 365 дней)..."
    openssl req -x509 \
        -newkey rsa:4096 \
        -keyout "${certs_dir}/server.key" \
        -out "${certs_dir}/server.crt" \
        -days 365 \
        -nodes \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=University/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
    chmod 600 "${certs_dir}/server.key"
    chmod 644 "${certs_dir}/server.crt"
    log_info "TLS-сертификат создан: ${certs_dir}"
}

main() {
    log_info "=== Запуск ${SCRIPT_NAME} ==="
    check_root_privileges
    check_os_version
    update_system_repositories
    install_docker
    apply_kernel_hardening
    prepare_secrets_directory
    generate_self_signed_cert
    log_info "=== Инициализация завершена. ==="
    log_info "Следующий шаг: cp .env.example .env && nano .env"
    log_info "Затем: cd deploy && docker compose up -d --build"
}

main "$@"
