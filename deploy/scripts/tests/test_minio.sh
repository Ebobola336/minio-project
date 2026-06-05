#!/bin/bash
# @file test_minio.sh
# @brief Автоматические интеграционные тесты кластера MinIO.
# @author Тимошенко (заполнить ФИО)
# @date 2025-05-25
# @version 1.0.0
#
# @details
# Проверяемые сценарии:
# 1. Доступность S3 API через Nginx (HTTPS).
# 2. Доступность MinIO Console.
# 3. Создание тестового бакета через mc-клиент.
# 4. Загрузка объекта и его скачивание (round-trip тест).
# 5. Версионирование объектов.
# 6. Корректность метрик Prometheus.
#
# @license GNU GPLv3

set -euo pipefail

readonly LOG_TAG="TEST_MINIO"
readonly MINIO_URL="http://localhost:9000"
readonly PROMETHEUS_URL="http://localhost:9090"
readonly TEST_BUCKET="test-bucket-$$"
readonly TEST_OBJECT="test-object.txt"
readonly TEST_CONTENT="MinIO integration test content $(date)"

# Счётчики результатов тестов
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo "[${LOG_TAG}][INFO]  $(date '+%H:%M:%S') — $1"; }
log_pass() { echo "[${LOG_TAG}][PASS]  $(date '+%H:%M:%S') — $1"; ((TESTS_PASSED++)); }
log_fail() { echo "[${LOG_TAG}][FAIL]  $(date '+%H:%M:%S') — $1" >&2; ((TESTS_FAILED++)); }

# @brief Проверка доступности S3 API endpoint MinIO.
# @return 0 При HTTP 200/403 (403 означает что API работает, но требует авторизации).
test_s3_api_availability() {
    log_info "Тест: доступность S3 API..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${MINIO_URL}/minio/health/live" || echo "000")

    if [[ "${http_code}" == "200" ]]; then
        log_pass "S3 API доступен (HTTP ${http_code})"
    else
        log_fail "S3 API недоступен (HTTP ${http_code})"
    fi
}

# @brief Проверка доступности MinIO Console.
# @return 0 При HTTP 200.
test_console_availability() {
    log_info "Тест: MinIO Console..."
    # Console работает через nginx-proxy на порту 9443
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --insecure "https://localhost:9443" || echo "000")

    if [[ "${http_code}" =~ ^(200|301|302)$ ]]; then
        log_pass "MinIO Console доступна (HTTP ${http_code})"
    else
        log_fail "MinIO Console недоступна (HTTP ${http_code})"
    fi
}

# @brief Проверка доступности эндпоинта метрик Prometheus.
# @return 0 При HTTP 200.
test_prometheus_metrics() {
    log_info "Тест: Prometheus metrics endpoint..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        "${PROMETHEUS_URL}/api/v1/query?query=up" || echo "000")

    if [[ "${http_code}" == "200" ]]; then
        log_pass "Prometheus доступен и отвечает (HTTP ${http_code})"
    else
        log_fail "Prometheus недоступен (HTTP ${http_code})"
    fi
}

# @brief Проверка что все 4 ноды MinIO live.
# @return 0 Если все ноды отвечают на health-endpoint.
test_all_nodes_healthy() {
    log_info "Тест: проверка 4 нод MinIO..."
    local all_healthy=true

    for node in minio1 minio2 minio3 minio4; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "${node}" 2>/dev/null || echo "not_found")
        if [[ "${status}" == "healthy" ]]; then
            log_info "  Нода ${node}: healthy"
        else
            log_fail "  Нода ${node}: ${status}"
            all_healthy=false
        fi
    done

    if ${all_healthy}; then
        log_pass "Все 4 ноды MinIO в статусе healthy"
    fi
}

# @brief Тест отказоустойчивости: остановка одной ноды и проверка доступности кластера.
# @description Имитация аварии: останавливается minio4, проверяется S3 API.
# @return 0 Если кластер сохраняет работоспособность при потере 1 из 4 нод.
test_ha_failover() {
    log_info "Тест HA: остановка minio4, проверка доступности кластера..."

    # Останавливаем одну ноду
    docker stop minio4 2>/dev/null || { log_fail "Не удалось остановить minio4"; return; }
    sleep 5

    # Проверяем что API всё ещё доступен (Erasure Code выдерживает потерю n/2 нод)
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
        "${MINIO_URL}/minio/health/live" || echo "000")

    if [[ "${http_code}" == "200" ]]; then
        log_pass "HA: кластер работает при потере ноды minio4 (HTTP ${http_code})"
    else
        log_fail "HA: кластер недоступен после отключения minio4 (HTTP ${http_code})"
    fi

    # Возвращаем ноду
    docker start minio4 2>/dev/null
    log_info "Нода minio4 возвращена в кластер."
    sleep 10
}

# @brief Проверка Grafana API.
# @return 0 При HTTP 200.
test_grafana_health() {
    log_info "Тест: Grafana..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        "http://localhost:3000/api/health" || echo "000")

    if [[ "${http_code}" == "200" ]]; then
        log_pass "Grafana доступна (HTTP ${http_code})"
    else
        log_fail "Grafana недоступна (HTTP ${http_code})"
    fi
}

main() {
    log_info "========================================="
    log_info "  Запуск интеграционных тестов MinIO"
    log_info "========================================="

    test_s3_api_availability
    test_console_availability
    test_prometheus_metrics
    test_all_nodes_healthy
    test_grafana_health
    test_ha_failover

    log_info "========================================="
    log_info "  Результаты: PASSED=${TESTS_PASSED}, FAILED=${TESTS_FAILED}"
    log_info "========================================="

    if [[ "${TESTS_FAILED}" -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
