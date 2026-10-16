#!/usr/bin/env bash
# 部署已下载的 Linux x86_64 工具；保留厂商目录，避免不同版本 libpq/OpenSSL 混用。作者：yanch
# 用法：bash install-linux-db-tools.sh /tmp/dbClient-linux /data/apps/lemonDb/dbClient
set -euo pipefail
source_dir="${1:?请指定下载目录}"
target_dir="${2:-/data/apps/lemonDb/dbClient}"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo '该包仅适用于 Linux x86_64'; exit 2; }
source_dir="$(cd "$source_dir" && pwd -P)"
mkdir -p "$target_dir"
target_dir="$(cd "$target_dir" && pwd -P)"
[[ "$source_dir" != "$target_dir" ]] || { echo '源目录和部署目录不能相同'; exit 2; }
# 下载目录基线为 Ubuntu 22.04，其它发行版必须通过启动检查再配置使用。
for family in mysql postgresql mongodb oracle sqlserver; do
  [[ -d "$source_dir/$family" ]] || continue
  mkdir -p "$target_dir/$family"
  cp -a "$source_dir/$family/." "$target_dir/$family/"
done
# SQLite 官方最新版要求 glibc 2.38，安装 Ubuntu 官方兼容版本，排除暂存的高版本文件。
for part in bin lib; do
  [[ -d "$source_dir/sqlite/$part" ]] || continue
  mkdir -p "$target_dir/sqlite/$part"
  cp -a "$source_dir/sqlite/$part/." "$target_dir/sqlite/$part/"
done
# Windows 拷贝不能可靠保留 Unix 权限；只为 ELF 可执行文件和脚本增加执行位。
while IFS= read -r -d '' file; do
  magic="$(head -c 4 "$file" || true)"
  if [[ "$magic" == $'\177ELF' || "$magic" == '#!'* ]]; then chmod a+rx "$file"; fi
done < <(find "$target_dir" -type f -print0)
if [[ -f "$source_dir/verify-database-tools.sh" ]]; then
  cp "$source_dir/verify-database-tools.sh" "$target_dir/verify-database-tools.sh"
  bash "$target_dir/verify-database-tools.sh" "$target_dir"
fi
printf '工具目录：%s\n配置 LEMON_DB_TOOL_ROOT 或管理员保存目录后生效。\n' "$target_dir"
