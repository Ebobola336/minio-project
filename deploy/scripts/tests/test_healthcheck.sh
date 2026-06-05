#!/bin/bash
# @file test_healthcheck.sh
# @brief Проверка статуса healthcheck всех контейнеров инфраструктуры.
# @author Тимошенко (заполнить ФИО)
# @date 2025-05-25
# @version 1.0.0
#
# @details
# Скрипт проверяет, что все контейнеры имеют статус 'healthy'.
# Выход с кодом 1, если хотя бы один контейнер не здоров.
#
# @license GNU GPLv3

set -euo pipefail

readonly LOG_TAG="HEALTHCHECK"
readonly CONTAINERS=("minio1" "minio2" "minio3" "minio4" "nginx-proxy" "prometheus" "grafana")

TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo "[${LOG_TAG}][INFO]  $(date '+%H:%M:%S') — $1"; }
log_pass() { echo "[${LOG_TAG}][PASS]  $(date '+%H:%M:%S') — $1"; ((TESTS_PASSED++)); }
log_fail() { echo "[${LOG_TAG}][FAIL]  $(date '+%H:%M:%S') — $1" >&2; ((TESTS_FAILED++)); }

# @brief Проверка статуса healthcheck одного контейнера.
# @param 1 container_name Имя Docker-контейнера.
# @return 0 Если контейнер healthy. @return 1 Иначе.
check_container_health() {
    local container_name=$1
    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "not_found")

    case "${status}" in
        healthy)
            log_pass "Контейнер ${container_name}: ${status}"
            ;;
        not_found)
            log_fail "Контейнер ${container_name} не найден"
            ;;
        *)
            log_fail "Контейнер ${container_name}: ${status}"
            ;;
    esac
}

main() {
    log_info "=== Проверка healthcheck всех контейнеров ==="

    for container in "${CONTAINERS[@]}"; do
        check_container_health "${container}"
    done

    log_info "=== PASSED=${TESTS_PASSED}, FAILED=${TESTS_FAILED} ==="

    if [[ "${TESTS_FAILED}" -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
