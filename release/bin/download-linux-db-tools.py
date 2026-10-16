#!/usr/bin/env python3
"""下载官方 Linux x86_64 数据库工具并保留依赖目录；作者 yanch。

默认以 Ubuntu 22.04 为 PostgreSQL/MongoDB 运行基线。不会安装系统包或修改 PATH。
归档保存在 packages，manifest.json 记录来源、SHA256 与完成状态。
"""
from pathlib import Path, PurePosixPath
import argparse
import concurrent.futures
import gzip
import hashlib
import io
import json
import re
import shutil
import tarfile
import urllib.request
import zipfile


def fetch(url):
    """仅通过 HTTPS 请求官方发布源，设置超时和明确的客户端标识。"""
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "lemon-db-client-tools/1.0"}), timeout=60)


def safe_path(directory, name):
    """归档路径必须在指定目录内，拒绝绝对路径和父目录跳转。"""
    item = PurePosixPath(name)
    if item.is_absolute() or ".." in item.parts or ":" in name or "\\" in name:
        raise ValueError("不安全的归档路径: " + name)
    return directory.joinpath(*item.parts)


def unpack_tar(data, directory):
    """手动提取普通文件；链接在文件提取后复制目标，避免 Windows 丢失动态库链接。"""
    links = []
    with tarfile.open(fileobj=data, mode="r:*") as archive:
        for item in archive:
            path = safe_path(directory, item.name)
            if item.isdir(): path.mkdir(parents=True, exist_ok=True)
            elif item.isfile():
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.exists(): path.chmod(0o666)
                with archive.extractfile(item) as source, path.open("wb") as output: shutil.copyfileobj(source, output)
                path.chmod(item.mode & 0o777)
            elif item.issym() or item.islnk(): links.append((item, path))
    for item, path in links:
        # 链接只解析当前厂商目录内的目标；不跟随系统绝对链接。
        if PurePosixPath(item.linkname).is_absolute(): continue
        target = (path.parent / item.linkname if item.issym() else directory / item.linkname).resolve()
        if not target.is_relative_to(directory.resolve()): raise ValueError("归档链接越界")
        if target.is_file(): path.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(target, path)


def unpack_deb(path, directory):
    """读取标准 ar/deb 归档中的 data.tar，不调用或安装 dpkg。"""
    with path.open("rb") as stream:
        if stream.read(8) != b"!<arch>\n": raise ValueError("无效 deb 归档")
        while True:
            header = stream.read(60)
            if not header: break
            size = int(header[48:58]); name = header[:16].decode().strip().rstrip("/")
            payload = stream.read(size)
            if size % 2: stream.read(1)
            if name.startswith("data.tar"):
                if name.endswith(".zst"):
                    try:
                        import zstandard
                    except ImportError as error:
                        raise RuntimeError("Ubuntu deb 使用 zstd 压缩，请先安装 Python zstandard 模块") from error
                    with zstandard.ZstdDecompressor().stream_reader(io.BytesIO(payload)) as reader:
                        payload = reader.read()
                unpack_tar(io.BytesIO(payload), directory); return
    raise ValueError("deb 缺少 data.tar")


def install(entry, root):
    """完整下载到临时文件，核验后改名，再提取到独立厂商目录。"""
    result = dict(entry)
    try:
        name = entry["url"].rsplit("/", 1)[-1]
        archive = root / "packages" / name; archive.parent.mkdir(parents=True, exist_ok=True)
        if not archive.exists():
            temporary = archive.with_suffix(archive.suffix + ".part")
            with fetch(entry["url"]) as response, temporary.open("wb") as output: shutil.copyfileobj(response, output, 1024*1024)
            temporary.replace(archive)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if entry.get("expected_sha256") and digest != entry["expected_sha256"]: raise ValueError("官方 SHA256 不匹配")
        if entry.get("expected_sha3") and hashlib.sha3_256(archive.read_bytes()).hexdigest() != entry["expected_sha3"]: raise ValueError("官方 SHA3 不匹配")
        directory = root / entry["family"]; directory.mkdir(parents=True, exist_ok=True)
        if name.endswith(".deb"): unpack_deb(archive, directory)
        elif name.endswith(".zip"):
            with zipfile.ZipFile(archive) as z:
                links = []
                for item in z.infolist():
                    path = safe_path(directory, item.filename)
                    if item.is_dir(): path.mkdir(parents=True, exist_ok=True)
                    elif (item.external_attr >> 16) & 0o170000 == 0o120000:
                        links.append((path, z.read(item).decode()))
                    else:
                        path.parent.mkdir(parents=True, exist_ok=True)
                        if path.exists(): path.chmod(0o666)
                        with z.open(item) as source, path.open("wb") as output: shutil.copyfileobj(source, output)
                        path.chmod((item.external_attr >> 16) & 0o777 or 0o755)
                for path, link in links:
                    target = (path.parent / link).resolve()
                    if not target.is_relative_to(directory.resolve()): raise ValueError("ZIP 链接越界")
                    if not target.is_file(): raise ValueError("ZIP 链接目标缺失: " + link)
                    if path.exists(): path.chmod(0o666)
                    shutil.copy2(target, path)
        else:
            with archive.open("rb") as source: unpack_tar(source, directory)
        result.update(status="downloaded", sha256=digest, bytes=archive.stat().st_size, archive=str(archive))
        print("OK", entry["family"], name, flush=True)
    except Exception as error:
        result.update(status="failed", error=str(error)); print("FAIL",entry["family"], str(error),flush=True)
    return result


def main():
    """固定官方版本，PG 包从签名仓库索引取得官方摘要，记录失败而不伪装下载成功。"""
    parser = argparse.ArgumentParser(); parser.add_argument("--directory", required=True); args = parser.parse_args()
    root = Path(args.directory).resolve(); root.mkdir(parents=True, exist_ok=True)
    entries = [
        dict(family="mysql",url="https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-linux-glibc2.28-x86_64-minimal.tar.xz"),
        # SQLite 最新预编译包要求 glibc 2.38，不能冒充 Ubuntu 22.04 可用工具。
        # 该包保留在 packages；可执行工具用下方 Ubuntu 官方仓库的兼容版本。
        dict(family="mongodb",url="https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.19.1.tgz"),
        dict(family="mongodb",url="https://downloads.mongodb.com/compass/mongosh-2.13.0-linux-x64.tgz"),
        dict(family="sqlserver",url="https://github.com/microsoft/go-sqlcmd/releases/download/v1.10.0/sqlcmd-linux-amd64.tar.bz2"),
    ]
    for kind in ("basic", "sqlplus", "tools"):
        entries.append(dict(family="oracle",url="https://download.oracle.com/otn_software/linux/instantclient/1932000/instantclient-"+kind+"-linux.x64-19.32.0.0.0dbru.zip"))
    with fetch("https://apt.postgresql.org/pub/repos/apt/dists/jammy-pgdg/main/binary-amd64/Packages.gz") as response:
        index = gzip.decompress(response.read()).decode()
    for package in ("postgresql-client-17", "libpq5"):
        sections = [s for s in index.split("\n\n") if s.startswith("Package: " + package + "\n")]
        # 索引按版本列出，最后一项是当前 22.04 的最新发布。
        section = sections[-1]; fields = dict(re.findall(r"^([A-Za-z0-9-]+): (.*)$",section,re.M))
        entries.append(dict(family="postgresql",url="https://apt.postgresql.org/pub/repos/apt/"+fields["Filename"],expected_sha256=fields["SHA256"],version=fields["Version"],system_dependencies=fields.get("Depends","")))
    with fetch("https://archive.ubuntu.com/ubuntu/dists/jammy-updates/main/binary-amd64/Packages.gz") as response:
        index = gzip.decompress(response.read()).decode()
    for package in ("sqlite3", "libsqlite3-0"):
        section = [s for s in index.split("\n\n") if s.startswith("Package: " + package + "\n")][-1]
        fields = dict(re.findall(r"^([A-Za-z0-9-]+): (.*)$",section,re.M))
        entries.append(dict(family="sqlite",url="https://archive.ubuntu.com/ubuntu/"+fields["Filename"],expected_sha256=fields["SHA256"],version=fields["Version"],system_dependencies=fields.get("Depends","")))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(lambda entry: install(entry,root),entries))
    (root / "manifest.json").write_text(json.dumps(dict(author="yanch",platform="Linux x86_64 / Ubuntu 22.04 baseline",runtime_verified=False,packages=results),ensure_ascii=False,indent=2),encoding="utf8")
    # PG 官方包把可执行文件放在 usr/lib/postgresql/17/bin；复制到对应厂商 bin 便于发现。
    pg = root / "postgresql"; binaries = pg / "usr/lib/postgresql/17/bin"; libs = pg / "usr/lib/x86_64-linux-gnu"
    if binaries.exists(): shutil.copytree(binaries,pg / "bin",dirs_exist_ok=True)
    if libs.exists(): shutil.copytree(libs,pg / "lib",dirs_exist_ok=True)
    sqlite = root / "sqlite"
    if (sqlite / "usr/bin").exists(): shutil.copytree(sqlite / "usr/bin", sqlite / "bin", dirs_exist_ok=True)
    if (sqlite / "usr/lib/x86_64-linux-gnu").exists(): shutil.copytree(sqlite / "usr/lib/x86_64-linux-gnu",sqlite / "lib",dirs_exist_ok=True)
    if any(r["status"] != "downloaded" for r in results): raise SystemExit(1)


if __name__ == "__main__": main()
