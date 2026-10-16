# Lemon 数据库官方客户端目录

服务端会从 `LEMON_DB_TOOL_ROOT`（默认 `/data/apps/lemonDb/dbClient`）探测并执行数据库官方命令行工具。
也可以在客户端顶栏的“客户端工具”中由系统管理员上传单个可执行文件或 ZIP 包；ZIP 会解压到对应数据库类型和工具名目录。

## 支持的逻辑工具

- MySQL 族：`mysql`、`mysqldump`
- PostgreSQL / Kingbase / GaussDB / HighGo 族：`psql`、`pg_dump`、`pg_restore`，以及对应的 `ksql/sys_dump/sys_restore`、`gsql/gs_dump/gs_restore`
- Oracle 族：`sqlplus`、`expdp`、`impdp`
- 达梦：`disql`、`dexp`、`dimp`
- SQL Server：`sqlcmd`、`bcp`
- SQLite：`sqlite3`
- MongoDB：`mongosh`、`mongodump`、`mongorestore`、`mongoimport`

工具不是随源码分发的第三方二进制。请从数据库厂商或发行版获取与服务器操作系统、CPU 架构匹配的版本，再上传并点击“测试”。

## 目录示例

```text
/data/apps/lemonDb/dbClient/
  MY_SQL/mysql/mysql.exe
  MY_SQL/mysqldump/mysqldump.exe
  POSTGRE_SQL/psql/psql.exe
  POSTGRE_SQL/pg_dump/pg_dump.exe
  MONGODB/mongodump/mongodump.exe
```

Linux/macOS 上传后需要保证文件是可执行的；服务端对上传文件会尝试补齐 POSIX 执行权限。生产环境建议将目录设置为应用专用目录，并关闭 `LEMON_DB_TOOL_ALLOW_PATH_LOOKUP`，避免误调用系统 PATH 中的同名程序。

客户端也支持直接放在基础目录根下，或放在 `common`、`bin` 子目录中；按数据库类型分目录时，页面会显示更清晰的可用状态。
