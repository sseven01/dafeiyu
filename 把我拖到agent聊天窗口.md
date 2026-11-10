# SnowLuma + AstrBot · 本机自助部署手册（Windows + Docker Desktop）

> **文档类型**：可直接投喂给任意 coding / 运维 Agent 的完整部署提示词  
> **读者/操作者**：**电脑主人本人**（在本机自己部署）；Agent 在本机协助，不是「远程帮客户装」  
> **目标环境**：本机 Windows 10/11 + Docker Desktop（WSL2 后端）  
> **部署产物**：SnowLuma（QQ/OneBot 网关）+ AstrBot（AI 机器人框架），同机互通  
> **版本**：v1.1（2026-11-10）· 基于 v1.0 + WorkBuddy 实机实录修订  
> **变更摘要**：① 本机自助语气（去掉「发给客户」）② 镜像默认 DaoCloud ③ OneBot 预配置改为启动后强制步骤 ④ show-passwords 修 LINKED OK 误报 ⑤ 收录实录 6 条硬经验  

---

## 0. 给 Agent 的总提示词（可整段粘贴）

```text
你是「SnowLuma + AstrBot 本机部署工程师」。操作者就是这台 Windows 电脑的主人，部署目标是本机，不是帮远程客户装机。

硬性规则：
1. 只使用本手册中的命令与路径；不要臆造端口、镜像名或配置字段。
2. 每完成一个阶段，必须用「验收命令」自检；失败则进入「故障分支」，不要跳过。
3. 凡手册标记【询问操作者】的节点，必须停下来向坐在电脑前的人提问，得到答复后再继续；禁止替对方猜测路径、盘符、是否改数据盘、端口冲突怎么处理。
4. 问路径时必须区分：**【A 脚本文件夹】**（deploy-kit 小文件）与 **【B Docker 数据盘】**（镜像/卷，大文件）；禁止只问「部署目录」让对方误解为选镜像存放盘。
4. 密码、API Key、QQ 扫码只由操作者本人在本机浏览器完成；你只负责展示从日志/文件读到的凭据和下一步指引，不要向「第三方客户」转发话术。
5. 涉及删除数据卷、改 Docker 全局设置、安装软件时，先向操作者确认再执行。
6. 全程用操作者能懂的中文简短汇报：当前阶段、结果、下一步、需要本人做什么。
7. 成功标准见 §9；未全部满足不得宣称「部署完成」。

部署相关有**两个不同路径**，提问和记录时必须写清标签，禁止只说「目录」：

| 标签 | 是什么 | 体积 | 默认/示例 |
|------|--------|------|-----------|
| **A. 脚本文件夹（deploy-kit）** | start.ps1 等小文件放哪，不是镜像存放处 | 几十 KB | `D:\docker-snowluma-astrbot\deploy-kit\` |
| **B. Docker 数据盘** | 镜像 + 数据卷所在虚拟磁盘（`docker_data.vhdx`） | 约 8–15 GB | 默认 C 盘；可选改到如 `D:\DockerData` |

规则：
- 问 A 时必须说清「**脚本/部署包文件夹**」，不要说「部署目录」单独出现。
- 问 B 时必须说清「**Docker 镜像和数据存放盘**」，并说明与 A 无关。
- 未指定 B 时保持默认，不主动迁移（见 §3）。

开始执行前，先完成 §1 环境预检，并输出预检结果表。
```

---

## 1. 阶段 0 · 环境预检（Agent 必做）

### 1.1 检查项与命令

在本机 PowerShell（非必须管理员）依次执行：

| # | 检查 | 命令 | 通过标准 |
|---|------|------|----------|
| P1 | 操作系统 | `systeminfo \| Select-String "OS Name"` 或 `[System.Environment]::OSVersion.Version` | Windows 10/11 |
| P2 | Docker CLI | `docker --version` | 输出 `Docker version x.y.z` |
| P3 | Compose | `docker-compose version` 或 `docker compose version` | 有版本号 |
| P4 | Docker 守护进程 | `docker info` | 无 `pipe`/`Cannot connect` 错误 |
| P5 | 磁盘可用空间 | `Get-PSDrive -PSProvider FileSystem \| Select Name,Free` | 目标盘可用 **≥ 15 GB**（建议 20 GB） |
| P6 | 端口占用 | 见下方脚本 | 下列端口均未被占用 |

**P6 端口脚本：**

```powershell
$ports = 5099,6081,6185,6199,13000,13001
foreach ($p in $ports) {
  $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
  if ($c) { Write-Host "BUSY $p -> PID $($c[0].OwningProcess)" } else { Write-Host "FREE $p" }
}
```

**已有无关容器**（如 WordPress）只记录、不删除。

### 1.2 预检分支

| 结果 | Agent 动作 |
|------|------------|
| P2/P3 失败（未装 Docker） | → §2 安装 Docker Desktop；装好并 `docker info` 成功后再继续 |
| P4 失败（Docker 未启动） | 启动 `C:\Program Files\Docker\Docker\Docker Desktop.exe`，轮询 `docker info` 最多 120s；仍失败 → 【询问操作者】是否重启 Docker Desktop / 重启电脑 |
| P5 不足 15 GB | 【询问操作者】换盘或清理；预计占用：镜像约 5.5 GB + 数据约 0.5–2 GB + Docker 本体 1–2 GB |
| P6 有占用 | 【询问操作者】改用备用端口（§4.4）或先停掉占用进程；禁止强杀未知进程 |
| 全部通过 | 进入 §2 |

### 1.3 【询问操作者】预检交互模板

> **两个问题含义不同，务必分开问、分开记。**  
> - 「脚本放哪」= 小文件夹，**不会**占几个 G  
> - 「镜像存哪」= Docker 数据盘，**才是**大头占用

```text
环境预检结果：
- 系统：…
- Docker：…
- 可用空间：…
- 端口：…

请分别确认（注意：下面第 1 条和第 2 条不是同一个路径）：

【A. 脚本文件夹】start.ps1 等小文件放在哪个目录？
  （只放脚本，几十 KB；默认 D:\docker-snowluma-astrbot\deploy-kit\）
  答复示例：D:\docker-snowluma-astrbot\deploy-kit\

【B. Docker 镜像/数据存放盘】镜像和数据卷写在哪个盘？
  （真正占空间的是这里，约 8–15GB；默认不改，继续用 C 盘 Docker 默认位置）
  - 默认：保持 C 盘默认（选这个最省事）
  - 自定义：改为其它盘，例如 D:\DockerData（需要额外迁移步骤）
  请回复：保持默认 / 改为 <路径>

【C. 镜像源】若 Docker Hub 拒绝拉取，是否同意使用 DaoCloud 前缀？（默认是）

【D. 端口冲突】仅当预检发现占用时才问：端口 … 被占用，改用 … 可以吗？
```

**未得到 A 的答复前，不要创建文件夹、不要拉镜像。**  
**未明确要求改 B 时，禁止执行 §3 数据盘迁移。**

---

## 2. 阶段 1 · 安装 / 启动 Docker Desktop

**仅当 P2/P3 失败时执行。** 已装好则跳到 §4（可选 §3）。

### 2.1 安装（由本机操作者执行或同意后代跑）

1. 下载：https://www.docker.com/products/docker-desktop/  
2. 安装（默认 WSL2 后端）。  
3. 启动 Docker Desktop，等待托盘图标稳定。  
4. 验收：

```powershell
docker --version
docker-compose version   # 或: docker compose version
docker info
```

三条均成功 → §3/§4。  
若 `docker compose` 提示 unknown command 但 `docker-compose` 可用，**继续用 `docker-compose`**。

### 2.2 【询问操作者】安装权限

```text
需要安装 Docker Desktop（约 1–2 GB）。是否：
A. 你现在手动安装，装好告诉我
B. 允许我执行安装包（请提供安装包路径）
```

---

## 3. 阶段 2 ·（可选）Docker 数据盘（镜像存放）改到非 C 盘

> 本节改的是 **B：镜像 + 数据卷** 所在虚拟磁盘，**与脚本文件夹 A 无关**。  
> 脚本始终放在操作者指定的 deploy-kit 文件夹里，不会跟着 vhdx 走。

**仅当操作者在 §1.3 明确选择「改为 &lt;路径&gt;」时执行。** 回复「保持默认」则整节跳过 → §4。

### 3.1 图形界面（优先）

1. Docker Desktop → **Settings** → **Resources** → **Advanced**  
2. **Disk image location** → 改为例如 `D:\DockerData`  
3. **Apply & restart**  
4. 验收：路径已变；`docker info` 正常。

### 3.2 命令行迁移（图形无入口时）

**执行前必须【询问操作者】，说明会短暂中断 Docker。**

```powershell
wsl --shutdown
wsl -l -v
# 发行版名以 wsl -l -v 为准，常见为 docker-desktop
wsl --export docker-desktop "D:\DockerWSL\docker-desktop.tar"
wsl --unregister docker-desktop
wsl --import docker-desktop "D:\DockerWSL\docker-desktop" "D:\DockerWSL\docker-desktop.tar" --version 2
```

启动 Docker Desktop，验收 `docker info` / `docker images` / `docker volume ls`。  
确认新盘出现 `docker_data.vhdx` 后，再【询问操作者】是否删除旧 `%LOCALAPPDATA%\Docker\wsl` 与临时 tar。**未确认禁止删除。**

---

## 4. 阶段 3 · 获取部署包并写入配置

### 4.1 获取 deploy-kit

| 方式 | 说明 |
|------|------|
| A. 本机已有压缩包 | 【询问操作者】解压到 **【A 脚本文件夹】**（如 `D:\docker-snowluma-astrbot\deploy-kit\`），不是选镜像盘 |
| B. 从你的网站 URL 下载 | 用 `curl.exe -L -o kit.zip <url>` 或浏览器下载后解压到 **A** |
| C. Agent 现场生成 | 按 §4.2–§4.3 在 **A 脚本文件夹** 创建文件 |

### 4.2 必备文件清单

```text
deploy-kit\
├── docker-compose.yml
├── start.ps1
├── show-passwords.ps1
├── status.ps1
├── stop.ps1
├── 部署工具.bat
├── 快速上手.txt
└── 使用说明.txt
```

**打包注意**：含中文文件名的 zip 请用 **Python `zipfile`**（UTF-8 标志位），不要用 PS 5.1 `Compress-Archive`（GBK 文件名在部分解压器下乱码）。

### 4.3 docker-compose.yml（权威版本 · v1.1）

镜像 **默认带 DaoCloud 前缀**（实测 Docker Hub 对 `motricseven7/snowluma` 可能 `pull access denied` 秒拒，不是网络慢）。

```yaml
services:
  snowluma:
    image: m.daocloud.io/docker.io/motricseven7/snowluma:latest
    container_name: snowluma
    restart: unless-stopped
    shm_size: 1g
    ulimits:
      nofile:
        soft: 65536
        hard: 1048576
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    environment:
      - SNOWLUMA_WEBUI_HOST=0.0.0.0
      - SNOWLUMA_WEBUI_PORT=5099
      - SNOWLUMA_QQ_FLAGS=--disable-gpu --disable-software-rasterizer --disable-gpu-compositing
      - TZ=Asia/Shanghai
    ports:
      - "127.0.0.1:6081:6081"
      - "127.0.0.1:5099:5099"
      - "127.0.0.1:13000:3000"
      - "127.0.0.1:13001:3001"
    volumes:
      - snowluma-gateway-data:/app/data
      - snowluma-client-config:/app/.config
      - snowluma-client-data:/app/.local/share

  astrbot:
    image: m.daocloud.io/docker.io/soulter/astrbot:latest
    container_name: astrbot
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "127.0.0.1:6185:6185"
      - "127.0.0.1:6199:6199"
    volumes:
      - astrbot-data:/AstrBot/data

volumes:
  snowluma-gateway-data:
    name: snowluma-gateway-data
  snowluma-client-config:
    name: snowluma-client-config
  snowluma-client-data:
    name: snowluma-client-data
  astrbot-data:
    name: astrbot-data
```

**端口约定（宿主机，仅 127.0.0.1）：**

| 端口 | 用途 |
|------|------|
| 5099 | SnowLuma WebUI |
| 6081 | noVNC（QQ 扫码） |
| 6185 | AstrBot WebUI |
| 6199 | AstrBot OneBot 反向 WS 监听 |
| 13000 | OneBot HTTP（容器内 3000） |
| 13001 | OneBot WebSocket（容器内 3001） |

### 4.4 端口冲突改法

只改 compose 中**冒号左侧**宿主机端口，例如：

```yaml
- "127.0.0.1:15099:5099"
```

改完后所有口述地址必须同步。  
**禁止**把监听端口 6199 与映射/SnowLuma 连接地址改成三套不一致的值。

### 4.5 脚本行为规格

**start.ps1**：检查 Docker → 优先 `docker-compose` 否则 `docker compose` → `up -d` → 等待 → 调 show-passwords。  

**show-passwords.ps1（v1.1 必须满足）**：
1. `[Console]::OutputEncoding = UTF8`（避免 PS 5.1 OEM 解码中文日志乱码）  
2. 去掉 ANSI 后提取 AstrBot / SnowLuma / noVNC 凭据  
3. 连通判定：**优先** `docker exec astrbot` 读 `/proc/net/tcp*` 中目标端口 `:1837`（6199）且状态 `01` ESTABLISHED 的套接字数；辅以日志 `connected ws://astrbot:6199/ws`  
4. 成功输出：`LINKED OK (AstrBot inbound sockets: N)`  
5. 脚本正文保持 **纯 ASCII**（或 UTF-8 带 BOM）

**status.ps1 / stop.ps1**：状态+尾部日志；`compose down`（保留卷）。

### 4.6 【询问操作者】配置交互

```text
【A. 脚本文件夹】确认：…\deploy-kit\   （小文件，非镜像盘）
【B. Docker 数据盘】保持默认 / 已改为 …（仅当本人要求改时）
【C. 镜像】默认 DaoCloud 前缀

确认后我开始写入脚本文件并启动容器。
（容器启动后的镜像/卷仍占用 B，与 A 无关）
```

---

## 5. 阶段 4 · 启动容器

### 5.1 命令

```powershell
cd <A. 脚本文件夹 deploy-kit>
powershell -ExecutionPolicy Bypass -File .\start.ps1
# 或
docker compose up -d
```

> 命令里的路径是 **A 脚本文件夹**，不是 Docker 数据盘 B。

### 5.2 验收

```powershell
docker ps --filter "name=snowluma" --filter "name=astrbot"
```

期望：两个容器 `Up`，RestartCount 正常（非持续重启）。

### 5.3 故障分支

| 现象 | 处理 |
|------|------|
| `port is already allocated` | 记下端口 → 【询问操作者】改映射（§4.4）→ 再 `up -d` |
| `pull access denied` | **不是慢，是被拒** → 确认 image 为 `m.daocloud.io/docker.io/...`；已前缀仍失败再问操作者网络 |
| pull timeout | 换网络或稍后重试；不要无限重试 |
| 容器反复退出 | `docker logs <name> --tail 100`；核对 shm / SYS_PTRACE / seccomp |

**禁止**未确认就 `docker volume rm` 或 `docker-compose down -v`。

### 5.4 【强制】OneBot 预配置（在请操作者扫码之前完成）

首次启动时两侧配置均为**空**（AstrBot `platform: []`、SnowLuma `wsClients: []`）。  
**不预写则扫码后永远连不上。** 此步为 v1.1 强制步骤，不可跳到 §6。

#### 5.4.1 AstrBot：写入 aiocqhttp 平台

**必须先停容器再改**（运行中的进程会覆盖写入）：

```powershell
docker stop astrbot
# 用一次性容器挂载 astrbot-data 修改 cmd_config.json（或等价 Python 脚本）
# 目标写入 platform 项：
```

```json
{
  "id": "default",
  "type": "aiocqhttp",
  "enable": true,
  "ws_reverse_host": "0.0.0.0",
  "ws_reverse_port": 6199,
  "ws_reverse_token": ""
}
```

```powershell
docker start astrbot
```

配置文件路径：容器内 `/AstrBot/data/cmd_config.json`（可能带 UTF-8 BOM，读取用 `utf-8-sig`）。

#### 5.4.2 SnowLuma：写入 wsClient

```powershell
# 修改 /app/data/config/onebot.json 的 networks.wsClients（及登录后的 onebot_<UIN>.json 若存在）
```

```json
{
  "name": "astrbot",
  "url": "ws://astrbot:6199/ws",
  "reconnectInterval": 5000,
  "reconnectEnabled": true,
  "accessToken": "",
  "messageFormat": "array",
  "reportSelfMessage": false
}
```

```powershell
docker exec snowluma supervisorctl restart snowluma
```

> 登录后 SnowLuma 可能生成 `onebot_<UIN>.json`，字段被归一化为 `reconnectIntervalMs`、补 `role: Universal`，属正常。  
> **导入 AstrBot 备份会覆盖 `platform`**：导入后必须复查 `ws_reverse_host=0.0.0.0`、`ws_reverse_port=6199`。

#### 5.4.3 预配置验收

```powershell
docker logs snowluma 2>&1 | Select-String "WS-Client|connected ws://astrbot"
docker logs astrbot 2>&1 | Select-String "aiocqhttp|Loading IM platform"
```

期望：SnowLuma 已尝试/建立 `ws://astrbot:6199/ws`；AstrBot 已加载 aiocqhttp(default)。  
（完整 LINKED OK 可能在 QQ 登录后才稳定，见 §7。）

---

## 6. 阶段 5 · 获取初始凭据（展示给本机操作者本人）

### 6.1 命令

```powershell
powershell -ExecutionPolicy Bypass -File .\show-passwords.ps1
```

### 6.2 期望信息（全新首次启动）

| 服务 | URL | 用户名 | 密码来源 |
|------|-----|--------|----------|
| AstrBot | http://127.0.0.1:6185 | `astrbot` | 日志 `Initial password:` |
| SnowLuma WebUI | http://127.0.0.1:5099 | `admin` | 日志 `initial credentials` |
| noVNC | http://127.0.0.1:6081/ | — | `vnc-password` 文件或日志 |

### 6.3 规则

- 把三组地址/账号/密码**显示在本机会话里**，供操作者自己复制到浏览器；**不要**写成「发给外部客户」的话术。  
- 要求操作者：**登录后立刻修改** AstrBot 与 SnowLuma WebUI 密码。  
- SnowLuma：未改初始密码则**每次重启会重新生成**（日志 `regenerated a new one`）；已出现 `password updated; all sessions invalidated` 则以本人改后的密码为准。  
- AstrBot 忘记密码：

```powershell
docker exec -it astrbot astrbot password
docker restart astrbot
```

### 6.4 【询问操作者】交互（本机自助）

```text
请你在本机浏览器依次完成：
1) http://127.0.0.1:5099  → admin / 上方密码 → 登录后修改密码
2) http://127.0.0.1:6081/ → noVNC 密码 → 手机 QQ 扫码登录
3) http://127.0.0.1:6185  → astrbot / 上方密码 → 修改密码 → 配置模型 API Key

完成后回复「已登录」；若某一步失败，把报错文字发我。
```

**在操作者确认「已登录」（至少完成 QQ 扫码）之前，不要做 §7 最终连通验收。**

---

## 7. 阶段 6 · OneBot 连通性

### 7.1 架构（禁止填反）

```text
AstrBot = 反向 WS 服务端，监听 0.0.0.0:6199（宿主机 127.0.0.1:6199）
SnowLuma = WS 客户端，连接 ws://astrbot:6199/ws（Docker 网络内容器名）
```

| 字段 | 正确值 | 错误示例（`Name or service not known`） |
|------|--------|------------------------------------------|
| 反向 WebSocket 主机 | `0.0.0.0` | `http://host.docker.internal`、`localhost`、空 |
| 反向 WebSocket 端口 | `6199` | `13000`、`3000` |
| Token | 空（除非两端一致） | 随便填 |

主机字段只接受**本机监听地址**，不能带 `http://`，不能填「要连去的地址」。

### 7.2 验收命令

```powershell
powershell -ExecutionPolicy Bypass -File .\show-passwords.ps1
docker logs snowluma 2>&1 | Select-String "connected ws://astrbot"
```

**成功同时满足：**

1. SnowLuma：`connected ws://astrbot:6199/ws`  
2. `show-passwords.ps1` 输出 **`LINKED OK (AstrBot inbound sockets: N)`** 且 N≥1  
   （或等价：容器内 `/proc/net/tcp` 可见 `:1837` ESTABLISHED）  
3. 日志侧 AstrBot「适配器已连接」（可选旁证；中文日志乱码时以套接字为准）

### 7.3 故障分支

| 错误 | 原因 | 处理 |
|------|------|------|
| `gaierror` + `sock.bind` | 监听主机填错 | §7.1 改 `0.0.0.0:6199`，重启 astrbot |
| 无 `connected` 行 | 未写 wsClients / 未预配置 / QQ 未登录 | 回 §5.4 → §6 扫码 |
| 连上即断 | Token / 6199 未监听 | 对齐 token；确认映射与监听 |
| 备份导入后连不上 | platform 被覆盖 | 复查并重写 §5.4.1 |
| LINKED 误报 | 中文日志编码 | 用 v1.1 脚本（UTF8 + 套接字），勿用 v1.0 |

---

## 8. 阶段 7 · 业务验收

### 8.1 清单（全部勾选才算完成）

- [ ] `docker ps`：snowluma、astrbot 均为 Up  
- [ ] 六端口探测 OK（或已按 §4.4 改过并同步地址）  
- [ ] OneBot 预配置已完成（§5.4）  
- [ ] 操作者已登录 SnowLuma WebUI 并修改密码  
- [ ] 操作者已通过 noVNC 完成 QQ 扫码登录  
- [ ] 操作者已登录 AstrBot、改密、已配置可用模型 API  
- [ ] `LINKED OK (AstrBot inbound sockets: N)` 且 N≥1  
- [ ] 手机 QQ 发消息，机器人有 AI 回复（或明确记录：仅连通完成、模型待本人后配）  
- [ ] 本机已交付：访问地址、密码查看命令、启停命令  

### 8.2 发消息测试（指导本机操作者）

1. 私聊机器人账号，或群内 @  
2. 发送：`在吗`  
3. 期望：AstrBot 日志有消息事件并回复  
4. 无回复：查模型配置、权限白名单、适配器是否仍 connected  

### 8.3 【询问操作者】最终确认

```text
部署验收结果：
- 容器：…
- 连通：LINKED OK / 未通过（原因：…）
- QQ 登录：…
- 模型：…

请确认是否可以结束；若有未完成项请指出。
```

---

## 9. 成功标准（全局）

1. 两个容器稳定 Running（非重启循环）  
2. 本机可打开三个 WebUI 并用已改后的密码登录  
3. SnowLuma → AstrBot 反向 WS 已建立（日志 + `:6199` ESTABLISHED）  
4. （完整交付）QQ 消息触发 AstrBot 模型回复  
5. 本机操作者掌握：URL、`show-passwords.ps1`、启停命令、常见故障  

---

## 10. 日常运维速查（交给本机操作者）

```powershell
powershell -ExecutionPolicy Bypass -File .\show-passwords.ps1   # 地址/密码/连通
powershell -ExecutionPolicy Bypass -File .\status.ps1           # 状态与日志
powershell -ExecutionPolicy Bypass -File .\start.ps1            # 启动
powershell -ExecutionPolicy Bypass -File .\stop.ps1             # 停止
docker compose restart
docker compose pull; docker compose up -d                       # 更新
docker exec -it astrbot astrbot password; docker restart astrbot # 重置 AstrBot 密码
```

**安全**：端口仅 `127.0.0.1`；勿把 6081/5099 暴露公网；API Key 只存在 astrbot-data 卷。

---

## 11. 数据与磁盘

| 内容 | 位置 | 备注 |
|------|------|------|
| 部署脚本 | 本机 deploy-kit 目录 | 可放任意盘 |
| 镜像+卷 | Docker 虚拟磁盘 `docker_data.vhdx` | 默认 `%LOCALAPPDATA%\Docker\wsl\disk\` |
| 数据卷名 | `snowluma-*`、`astrbot-data` | 固定名，勿改 `name:` |

**占用估算**：镜像约 5.5 GB + 卷 0.5–2 GB + Docker 1–2 GB ≈ 8–10 GB；首日消息未积累时卷往往远小于上限（实测曾见约 0.8 GB）。

**清理（须操作者明确同意）：**

```powershell
docker compose down
docker rmi m.daocloud.io/docker.io/motricseven7/snowluma:latest m.daocloud.io/docker.io/soulter/astrbot:latest
# 彻底删数据（丢 QQ 登录态与 AstrBot 配置）:
# docker volume rm snowluma-gateway-data snowluma-client-config snowluma-client-data astrbot-data
```

---

## 12. 错误速查总表

| 症状 | 关键日志/报错 | 动作 |
|------|----------------|------|
| `Name or service not known` + hypercorn bind | `sock.bind` | §7.1 主机改 `0.0.0.0` |
| `pull access denied` | 秒级拒绝 | **换/确认 DaoCloud 前缀**，勿当慢网重试 |
| `port is already allocated` | bind 失败 | §4.4 改宿主机端口 |
| Docker 连不上 | `npipe` / Cannot connect | 启动 Docker Desktop，§1 |
| QQ 未登录 | 无 friends/groups | noVNC 扫码，§6 |
| 有连接无回复 | 无 model / 白名单 | 配模型与权限 |
| 密码每次重启变 | `regenerated a new one` | 登录后必须改密 |
| LINKED 误报 / 中文乱码 | 脚本报 not confirmed | 用 v1.1 show-passwords（UTF8+套接字） |
| zip 中文名乱码 | unzip 乱码 | Python zipfile 重打包 |
| 备份后连不上 | platform 空/被覆盖 | 重做 §5.4.1 |
| 脚本解析失败 | ParserError / `?` | 纯 ASCII 或 UTF-8+BOM |
| compose 命令不存在 | unknown command | 用 `docker-compose` |

---

## 13. Agent 行为纪律

1. **分阶段汇报**：做了什么 / 验收 / 下一步 / 是否需操作者本人操作。  
2. **【询问操作者】必须阻塞等待**；禁止静默替本人决定目录、改盘、端口、删卷、装软件。  
3. **不编造密码**；只来自日志或 `vnc-password`。  
4. **不删除**数据卷/旧 Docker 数据，除非本人明确同意。  
5. **不把** `host.docker.internal`、`http://...` 写入 `ws_reverse_host`。  
6. 遇到未覆盖错误：保留报错 → 一条最保守修复 → 仍失败则说明并请本人指示；禁止连续破坏性盲试。  
7. 结束输出 §8.1 勾选表；未完成不得写「已完成」。  
8. **受众是本机操作者**：输出面向「你在这台电脑上」的指引，不要生成「发给外部客户」的交付话术。

---

## 14. 网站托管建议

```text
https://<your-site>/docs/snowluma-astrbot-agent-deploy.md
https://<your-site>/docs/snowluma-astrbot-agent-deploy.html
```

给 Agent 的最短引导句：

```text
请阅读并严格遵循 https://<your-site>/docs/snowluma-astrbot-agent-deploy.md
在这台 Windows 电脑上完成 SnowLuma + AstrBot 本机部署。
从 §0 与 §1 开始；凡【询问操作者】处先向我提问。
部署包：<你的 zip URL>
```

可选：同目录挂 `docker-compose.yml`、`*.ps1`、zip 直链；文档标版本 v1.1。

---

## 15. 一页纸流程（Agent 记忆锚点）

```text
【A 脚本文件夹】预检 → (装 Docker) → (可选：仅当要求时改 B 数据盘)
  → 把 deploy-kit 放到 A → up -d
  → 【强制】OneBot 预配置（停容器改 AstrBot + 改 SnowLuma + restart）
  → show-passwords 展示凭据 → 本机登录+扫码+配模型
  → LINKED OK (inbound sockets ≥1) + QQ 发消息
  → 交付运维命令 → 勾选 §8.1

切记：问「目录」必须标明 A（脚本）还是 B（镜像盘）；B 默认不动。
```

失败：**看日志 → §12 → 仍不行【询问操作者】**。不跳步、不假装成功。

---

*本手册 v1.1 与交付包配套；冲突时以本文 §4.3 compose 与 §5.4 OneBot 预配置为准。*  
*实录参考：WorkBuddy 2026-11-10 部署实录（DaoCloud、预配置、show-passwords 修复、zip 打包）。*
