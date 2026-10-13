# PhotoCraft Docker

[PhotoCraft](https://github.com/storytold/photocraft) 是浏览器图片编辑器。本仓库将官方 Web Release 打包为 Docker 镜像，通过 Docker Hub 提供，支持 amd64 和 arm64。

## Docker Run

```bash
docker run -d \
  --name photocraft \
  --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  szcq/photocraft:latest
```

## Docker Compose

创建 `docker-compose.yaml`：

```yaml
services:
  photocraft:
    image: szcq/photocraft:latest
    container_name: photocraft
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
```

启动：

```bash
docker compose up -d
```

## 访问与使用

服务器本机访问 `http://localhost:8080`。远程使用时，为域名配置 HTTPS 反向代理，上游地址为 `http://127.0.0.1:8080`。

无需映射数据目录。图片在浏览器中处理，保存和导出会下载到你的设备，请在关闭或刷新页面前保存。

## 更新

Docker Compose：

```bash
docker compose pull
docker compose up -d
```

Docker Run：

```bash
docker pull szcq/photocraft:latest
docker stop photocraft
docker rm photocraft
```

然后重新执行上面的 `docker run` 命令。

`latest` 指向最后一次成功发布的版本。需要固定版本时，将镜像标签改为具体版本号，例如 `szcq/photocraft:0.8.2`。
