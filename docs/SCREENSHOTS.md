# 截图整理 / Screenshot inventory

拍摄日期 / Captured: **2026-10-12**

所有中英文图片均来自实际运行的 Lemon DB Client 桌面客户端，分别通过界面语言切换拍摄。未使用设计稿、AI 生成截图或翻译覆盖图。对应文件位于 `images/zh/` 和 `images/en/`。

All Chinese and English images are real captures of the running desktop client, taken after switching the UI language. No mockups, generated screenshots, or translation overlays were used.

## 功能截图 / Feature screenshots

| 场景 / Scene | 中文 / Chinese | English |
| --- | --- | --- |
| 服务端选择与配置 / Server profiles | [中文](./images/zh/09-server-selector.png) | [English](./images/en/09-server-selector.png) |
| SQL 编辑与 6 行示例结果 / SQL editor and six sample rows | [中文](./images/zh/01-sql-client-results.png) | [English](./images/en/01-sql-client-results.png) |
| 数据库下的已保存查询 / Database-scoped saved query | [中文](./images/zh/02-saved-queries-under-db.png) | [English](./images/en/02-saved-queries-under-db.png) |
| 保存查询 / Save query dialog | [中文](./images/zh/03-save-query-dialog.png) | [English](./images/en/03-save-query-dialog.png) |
| AI 生成 SQL / AI-generated SQL | [中文](./images/zh/04-ai-assistant.png) | [English](./images/en/04-ai-assistant.png) |
| AI 表结构说明 / AI schema documentation | [中文](./images/zh/05-ai-schema-docs.png) | [English](./images/en/05-ai-schema-docs.png) |
| ETL 流水线与只读预览 / ETL pipeline and read-only preview | [中文](./images/zh/11-etl-pipeline.png) | [English](./images/en/11-etl-pipeline.png) |
| Redis 键、类型、TTL 与值 / Redis key, type, TTL, and value | [中文](./images/zh/06-redis-console.png) | [English](./images/en/06-redis-console.png) |
| SQL 图表配置与预览 / SQL chart configuration and preview | [中文](./images/zh/07-bi-dashboard.png) | [English](./images/en/07-bi-dashboard.png) |
| SQL 工单审核台 / SQL work order review console | [中文](./images/zh/08-sql-work-order.png) | [English](./images/en/08-sql-work-order.png) |

`00-workbench-home.png` 保留为工作台概览入口，与 SQL / 查询保存场景共用展示内容。

`00-workbench-home.png` is retained as a workbench overview image and shares the SQL / saved-query scene.

## 展示数据与边界 / Demonstration data and scope

- SQL、ETL 和图表使用常量 SELECT / UNION ALL 生成的月度销售示例；未修改业务表数据。ETL 只执行查询预览，未运行写入流水线，示例 SQL 在拍摄后恢复为原内容。 / SQL, ETL, and charts use a constant SELECT / UNION ALL sales example. No business-table rows were changed. ETL ran only a query preview; its write pipeline was not executed, and the temporary SQL was restored after capture.
- 保存了一条 `Demo - Monthly revenue` 查询与同名图表资产，便于复拍；在演示库生成了 `lm_attachment` 的结构说明。 / A named sample query and chart asset were saved for repeat captures, and schema documentation was generated for `lm_attachment` in the demonstration database.
- Redis 使用 DB 1 的 `demo:lemondb:sales:20261012` 示例键，创建时设置 3600 秒 TTL；公开截图只显示 `demo:*`，不展示登录令牌或密码键。 / Redis uses a demonstration key in DB 1 with an initial 3600-second TTL. Public captures are filtered to `demo:*` and do not show credential or login-token keys.
- `07-bi-dashboard.png` 展示图表编辑器的 SQL 与实时预览，未将新演示大屏发布。 / `07-bi-dashboard.png` shows the chart editor and live preview; no new demonstration dashboard was published.
- 英文界面中的用户自定义连接名、业务说明与库表名保留原文。当前安装版本中少量按钮、状态和提示仍显示中文，截图保留实际状态。 / User-defined names, business descriptions, and database identifiers keep their original language. Some controls, statuses, and hints in the installed version remain Chinese; the captures preserve the real UI.

## 多服务端标签实拍 / Multiple connected server tabs

多服务端并行连接、独立会话和标签切换已依据 Electron 实现核对。本次可用配置只有“本地服务”，因此没有制作同时连接多个真实服务端的截图。

Simultaneous server connections, independent sessions, and tab switching were verified against the Electron implementation. Only the local server profile was available during capture, so no image is presented as proof of multiple real servers connected simultaneously.

下一张建议补充 `10-multi-server-tabs.png`：配置并登录第二个可用服务端，在同一窗口保留两个标签和当前 SQL 结果页，中英文分别拍摄。

The next suggested capture is `10-multi-server-tabs.png`: connect and sign in to a second available server, then capture both tabs above the active SQL results in each language.

根级 `images/*.png` 和 `UI截图/` 属于历史素材；新版 README 只引用本次拍摄的 `images/zh/` 与 `images/en/`。

Root-level `images/*.png` and `UI截图/` are historical assets. The refreshed READMEs reference only the newly captured language-specific sets.
