#!/usr/bin/env bash
# 官方数据库工具启动检查；不连接数据库、不执行导入导出。作者：yanch
# 用法：bash bin/verify-database-tools.sh /data/apps/lemonDb/dbClient
set -u
root="${1:-/data/apps/lemonDb/dbClient}"
if [[ "$(uname -s)" != Linux ]]; then
  printf '此检查必须在实际运行后端的 Linux 主机执行。\n' >&2
  exit 2
fi
if [[ ! -d "$root" ]]; then printf '工具目录不存在：%s\n' "$root" >&2; exit 2; fi
if ! command -v timeout >/dev/null; then printf '需要 coreutils timeout 防止版本探测挂起。\n' >&2; exit 2; fi
root="$(cd "$root" && pwd -P)"
log="$(mktemp)"
trap 'rm -f -- "$log"' EXIT
missing=0
failed=0
printf 'Linux 主机：%s，工具目录：%s\n' "$(uname -m)" "$root"

# 和后端一样按真实客户端名查找，不能把 Windows .exe 当作 Linux 工具。
resolve_tool() {
  local tool="$1" candidate
  for candidate in "$root/bin/$tool" "$root/$tool"; do
    if [[ -f "$candidate" ]]; then printf '%s' "$candidate"; return; fi
  done
  candidate="$(find "$root" -maxdepth 8 -type f -name "$tool" -print -quit)"
  if [[ -n "$candidate" ]]; then printf '%s' "$candidate"; return; fi
  command -v "$tool" 2>/dev/null || true
}

# 模拟 ProcessBuilder 的动态库环境，不依赖登录 shell 是否 source 了厂商 env.sh。
check_tool() {
  local tool="$1" flag="$2" exe dir base libs="" result
  exe="$(resolve_tool "$tool")"
  if [[ -z "$exe" ]]; then printf 'MISSING %-14s\n' "$tool"; missing=$((missing+1)); return; fi
  if [[ ! -x "$exe" ]]; then printf 'FAIL    %-14s 缺少执行权限：%s\n' "$tool" "$exe"; failed=$((failed+1)); return; fi
  dir="$(cd "$(dirname "$exe")" && pwd -P)"
  libs="$dir"
  for base in "$root/lib" "$root/lib64" "$dir/../lib" "$dir/../lib64"; do
    if [[ -d "$base" ]]; then
      while IFS= read -r candidate; do libs="$libs:$candidate"; done < <(find "$base" -maxdepth 3 -type d)
    fi
  done
  LD_LIBRARY_PATH="$libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" PATH="$dir:$PATH" timeout 15 "$exe" "$flag" </dev/null >"$log" 2>&1
  result=$?
  if [[ "$result" -eq 0 ]]; then
    printf 'OK      %-14s %s\n' "$tool" "$exe"
    head -n 2 "$log"
  else
    printf 'FAIL    %-14s 退出码=%s，路径=%s\n' "$tool" "$result" "$exe"
    tail -n 8 "$log"
    if command -v file >/dev/null; then file "$exe"; fi
    failed=$((failed+1))
  fi
}

check_tool mysql --version
check_tool mysqldump --version
check_tool psql --version
check_tool pg_dump --version
check_tool pg_restore --version
check_tool sqlite3 -version
check_tool mongosh --version
check_tool mongodump --version
check_tool mongorestore --version
check_tool mongoimport --version
check_tool sqlcmd '-?'
check_tool bcp -v
check_tool sqlplus -V
check_tool expdp HELP=YES
check_tool impdp HELP=YES
check_tool disql -V
check_tool dexp HELP
check_tool dimp HELP
check_tool ksql --version
check_tool sys_dump --version
check_tool sys_restore --version
check_tool gsql --version
check_tool gs_dump --version
check_tool gs_restore --version
printf '\n缺少工具=%s，启动失败=%s。H2 使用 Java JDBC，无需 h2.jar。\n' "$missing" "$failed"
printf 'OK 只证明进程可启动；实库权限、网络、服务端版本和往返恢复需另行验证。\n'
if [[ "$failed" -gt 0 ]]; then exit 1; fi
