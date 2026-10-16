# 演示与截图 / Demo and screenshots

在线演示 / Online demo: [http://test.ychos.cn:7777/](http://test.ychos.cn:7777/)

完整部署包 / Complete deployment package: [xxx.zip](./xxx.zip)，包含 JAR、SQL 初始化文件和 `bin` 目录。 / Includes the JAR, SQL initialization files, and a `bin` directory. `xxx.zip` 为占位链接，发布前替换为实际下载地址。 / Replace this placeholder with the actual download URL before publishing.

前端已打入 JAR，完成初始化和环境配置后，启动 JAR 即可使用，无需单独部署前端。 / The frontend is bundled in the JAR. After initialization and environment configuration, start the JAR; no separate frontend deployment is required.

部署后浏览器访问 / Browser URL after deployment: [http://127.0.0.1:7806/lmdb/view/index.html](http://127.0.0.1:7806/lmdb/view/index.html)。远程访问时替换为部署服务器地址。 / For remote access, use the deployment server's address.

工具面向生产环境无法直连数据库，以及企业内部统一管理数据库访问权限的场景。 / Designed for restricted production database access and centrally managed enterprise database permissions.

桌面客户端服务端地址必须包含完整 API 根路径，例如 `http://localhost:7806/lmdb`。演示时优先展示多个服务端标签，并使用专用演示账号和数据。

The desktop server profile must include the complete API base path, such as `http://localhost:7806/lmdb`. Showcase multiple server tabs using dedicated demonstration accounts and data.

截图索引、拍摄顺序和更新状态见 [docs/SCREENSHOTS.md](./docs/SCREENSHOTS.md)。

See [docs/SCREENSHOTS.md](./docs/SCREENSHOTS.md) for the inventory, capture order, and refresh status.
