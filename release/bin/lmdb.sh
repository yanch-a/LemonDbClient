#!/usr/bin/env bash
# =============================================================================
# lemonDbClient / lemon-main Linux 启停脚本
#
# 用法：
#   ./lmdb.sh start|stop|restart|status|console
#
# 用户只应编辑同目录 lmdb.env（从 lmdb.env.example 复制）：
#   MySQL（DB_*）、Redis（REDIS_*）、SERVER_PORT、JAVA_HOME / JAVA_OPTS
#
# 对外交付固定使用 pro 配置；不会加载 conf/*.yml，避免覆盖产品内置项。
#
# 建议部署目录：
#   /opt/lmdb/
#     ├── bin/lmdb.sh
#     ├── bin/lmdb.env
#     ├── lemon-main.jar
#     └── logs/
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 脚本在 bin/ 下时，应用根目录为上一级；否则与脚本同级
if [[ "$(basename "${SCRIPT_DIR}")" == "bin" ]]; then
  APP_HOME="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  APP_HOME="${SCRIPT_DIR}"
fi

ENV_FILE=""
if [[ -f "${SCRIPT_DIR}/lmdb.env" ]]; then
  ENV_FILE="${SCRIPT_DIR}/lmdb.env"
elif [[ -f "${APP_HOME}/lmdb.env" ]]; then
  ENV_FILE="${APP_HOME}/lmdb.env"
fi

# 仅 source，不 set -a：lmdb.env 里多写的键不会进入 Java 进程
load_env_file() {
  local f="$1"
  local tmp
  tmp="$(mktemp)"
  # 兼容 Windows 编辑器保存的 CRLF
  sed 's/\r$//' "${f}" > "${tmp}"
  # shellcheck disable=SC1090
  source "${tmp}"
  rm -f "${tmp}"
}

if [[ -n "${ENV_FILE}" ]]; then
  load_env_file "${ENV_FILE}"
fi

APP_NAME="${APP_NAME:-lemonDbClient}"
# 对外交付锁定 pro，防止切到 dev/test 用到内置调试配置
SPRING_PROFILES_ACTIVE="pro"
SERVER_PORT="${SERVER_PORT:-7806}"
CONTEXT_PATH="/lmdb"

LOG_DIR="${LOG_DIR:-${APP_HOME}/logs}"
PID_FILE="${PID_FILE:-${APP_HOME}/${APP_NAME}.pid}"
STDOUT_LOG="${STDOUT_LOG:-${LOG_DIR}/stdout.log}"

JAVA_OPTS="${JAVA_OPTS:--Xms512m -Xmx1024m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${LOG_DIR}}"

mkdir -p "${LOG_DIR}"

# ---------- 用户可配项：只把白名单导出给 JVM（供 application-pro.yml 占位符读取） ----------
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-lemon_db_client}"
DB_USERNAME="${DB_USERNAME:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
REDIS_ENABLED="${REDIS_ENABLED:-true}"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
REDIS_DATABASE="${REDIS_DATABASE:-0}"
REDIS_AUTH_DATABASE="${REDIS_AUTH_DATABASE:-1}"

export DB_HOST DB_PORT DB_NAME DB_USERNAME DB_PASSWORD
export REDIS_HOST REDIS_PORT REDIS_PASSWORD REDIS_DATABASE REDIS_AUTH_DATABASE
# Spring 松散绑定：LEMON_REDIS_ENABLED -> lemon.redis.enabled
export LEMON_REDIS_ENABLED="${REDIS_ENABLED}"

# 填写了完整 JDBC URL 时覆盖 yml 里拼接的 url
if [[ -n "${DB_URL:-}" ]]; then
  export SPRING_DATASOURCE_DRUID_MASTER_URL="${DB_URL}"
fi

resolve_java() {
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    echo "${JAVA_HOME}/bin/java"
    return
  fi
  if command -v java >/dev/null 2>&1; then
    command -v java
    return
  fi
  echo "ERROR: 未找到 java，请安装 JDK8+ 或设置 JAVA_HOME" >&2
  exit 1
}

resolve_jar() {
  if [[ -n "${APP_JAR:-}" ]]; then
    if [[ "${APP_JAR}" = /* ]]; then
      echo "${APP_JAR}"
    else
      echo "${APP_HOME}/${APP_JAR}"
    fi
    return
  fi
  local candidates=(
    "${APP_HOME}/lemon-main.jar"
    "${APP_HOME}/lemon-main-1.0.0.jar"
    "${APP_HOME}/lemon-main/target/lemon-main.jar"
    "${APP_HOME}/lemon-main/target/lemon-main-1.0.0.jar"
  )
  local f
  for f in "${candidates[@]}"; do
    if [[ -f "${f}" ]]; then
      echo "${f}"
      return
    fi
  done
  local found
  found="$(find "${APP_HOME}" -maxdepth 3 -type f \( -name 'lemon-main.jar' -o -name 'lemon-main-*.jar' \) ! -name '*.original' 2>/dev/null | head -n 1 || true)"
  if [[ -n "${found}" ]]; then
    echo "${found}"
    return
  fi
  echo "ERROR: 未找到 lemon-main*.jar，请放到 ${APP_HOME} 或设置 APP_JAR" >&2
  exit 1
}

require_env_file() {
  if [[ -z "${ENV_FILE}" ]]; then
    echo "ERROR: 未找到 lmdb.env" >&2
    echo "请复制 ${SCRIPT_DIR}/lmdb.env.example 为 lmdb.env，填写 MySQL / Redis 后再启动。" >&2
    exit 1
  fi
}

validate_user_config() {
  if [[ -z "${DB_NAME}" || -z "${DB_USERNAME}" ]]; then
    echo "ERROR: 请在 lmdb.env 中填写 DB_NAME、DB_USERNAME" >&2
    exit 1
  fi
  if [[ "${REDIS_ENABLED}" == "true" ]]; then
    if [[ -z "${REDIS_HOST}" ]]; then
      echo "ERROR: REDIS_ENABLED=true 时请在 lmdb.env 中填写 REDIS_HOST" >&2
      exit 1
    fi
    if [[ "${REDIS_DATABASE}" == "${REDIS_AUTH_DATABASE}" ]]; then
      echo "ERROR: REDIS_DATABASE 与 REDIS_AUTH_DATABASE 不能相同" >&2
      exit 1
    fi
  fi
}

print_start_info() {
  local java_bin="$1"
  local jar_file="$2"
  echo "启动 ${APP_NAME} ..."
  echo "  JAVA     : ${java_bin}"
  echo "  JAR      : ${jar_file}"
  echo "  ENV      : ${ENV_FILE}"
  echo "  PORT     : ${SERVER_PORT}"
  echo "  MYSQL    : ${DB_USERNAME}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
  if [[ "${REDIS_ENABLED}" == "true" ]]; then
    echo "  REDIS    : ${REDIS_HOST}:${REDIS_PORT} (cache db=${REDIS_DATABASE}, auth db=${REDIS_AUTH_DATABASE})"
  else
    echo "  REDIS    : 已关闭（进程内缓存）"
  fi
  echo "  URL      : http://127.0.0.1:${SERVER_PORT}${CONTEXT_PATH}/view/"
}

is_running() {
  if [[ ! -f "${PID_FILE}" ]]; then
    return 1
  fi
  local pid
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -z "${pid}" ]]; then
    return 1
  fi
  if kill -0 "${pid}" 2>/dev/null; then
    return 0
  fi
  return 1
}

java_cmd_args() {
  # 对外不加载 conf/，避免用户用 application.yml 覆盖授权、加密等内置项
  echo \
    -Dfile.encoding=UTF-8 \
    -Duser.timezone=Asia/Shanghai \
    -Dserver.port="${SERVER_PORT}" \
    -Dspring.profiles.active="${SPRING_PROFILES_ACTIVE}"
}

do_start() {
  require_env_file
  validate_user_config

  if is_running; then
    echo "${APP_NAME} 已在运行 (pid=$(cat "${PID_FILE}"))"
    return 0
  fi

  local java_bin jar_file
  java_bin="$(resolve_java)"
  jar_file="$(resolve_jar)"

  if [[ ! -f "${jar_file}" ]]; then
    echo "ERROR: jar 不存在: ${jar_file}" >&2
    exit 1
  fi

  print_start_info "${java_bin}" "${jar_file}"

  # shellcheck disable=SC2086
  nohup "${java_bin}" \
    ${JAVA_OPTS} \
    $(java_cmd_args) \
    -jar "${jar_file}" \
    >> "${STDOUT_LOG}" 2>&1 &

  local pid=$!
  echo "${pid}" > "${PID_FILE}"
  sleep 2

  if is_running; then
    echo "启动成功 pid=${pid}"
    echo "日志: ${STDOUT_LOG}"
  else
    echo "启动可能失败，请查看日志: ${STDOUT_LOG}" >&2
    exit 1
  fi
}

do_stop() {
  if ! is_running; then
    echo "${APP_NAME} 未运行"
    rm -f "${PID_FILE}"
    return 0
  fi

  local pid
  pid="$(cat "${PID_FILE}")"
  echo "停止 ${APP_NAME} (pid=${pid}) ..."
  kill "${pid}" 2>/dev/null || true

  local i
  for i in $(seq 1 30); do
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -f "${PID_FILE}"
      echo "已停止"
      return 0
    fi
    sleep 1
  done

  echo "优雅停机超时，强制 kill -9"
  kill -9 "${pid}" 2>/dev/null || true
  rm -f "${PID_FILE}"
  echo "已强制停止"
}

do_status() {
  if is_running; then
    local pid
    pid="$(cat "${PID_FILE}")"
    echo "${APP_NAME} 运行中 pid=${pid}"
    echo "  访问: http://127.0.0.1:${SERVER_PORT}${CONTEXT_PATH}/view/"
  else
    echo "${APP_NAME} 未运行"
    return 1
  fi
}

do_console() {
  require_env_file
  validate_user_config
  local java_bin jar_file
  java_bin="$(resolve_java)"
  jar_file="$(resolve_jar)"
  print_start_info "${java_bin}" "${jar_file}"
  echo "前台启动（Ctrl+C 退出）..."
  # shellcheck disable=SC2086
  exec "${java_bin}" \
    ${JAVA_OPTS} \
    $(java_cmd_args) \
    -jar "${jar_file}"
}

usage() {
  cat <<EOF
用法: $0 {start|stop|restart|status|console}

  start    后台启动
  stop     停止
  restart  重启
  status   查看状态
  console  前台启动（调试）

用户配置：复制 lmdb.env.example 为 lmdb.env，只填写 MySQL / Redis / 端口 / JVM。
说明见 doc/Linux部署说明.md
EOF
}

cmd="${1:-}"
case "${cmd}" in
  start)   do_start ;;
  stop)    do_stop ;;
  restart) do_stop; do_start ;;
  status)  do_status ;;
  console) do_console ;;
  *)       usage; exit 1 ;;
esac
