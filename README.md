# SnowLuma + AstrBot 本机部署包 v1.1

在 **Windows 10/11** 上用 Docker 部署 **SnowLuma（QQ/OneBot）+ AstrBot（AI 机器人）**，同机互通。  
面向：**电脑主人本人自助部署**，或把手册拖给 Agent（WorkBuddy / Trae / 千问 / Claude 等）协助完成。

---

## 目录里有什么

| 文件 | 说明 |
|------|------|
| **把我拖到agent聊天窗口.md** | Agent 部署手册（v1.1）。拖进聊天窗口，让 Agent 按手册执行 |
| **docker-compose.yml** | 服务定义（镜像已用 DaoCloud 前缀，端口仅本机 127.0.0.1） |
| **start.ps1** | 一键启动 |
| **show-passwords.ps1** | 查看地址、密码、SnowLuma↔AstrBot 连通状态 |
| **status.ps1** | 容器状态与最近日志 |
| **stop.ps1** | 停止服务（保留数据） |
| **部署工具.bat** | 双击菜单（启动 / 看密码 / 状态 / 停止） |
| **快速上手.txt** | 给人的 5 步极简说明 |
| **使用说明.txt** | 完整图文说明（含预配置、排错） |
| **Docker Desktop Installer.exe** | Docker Desktop 离线安装包（约 595MB） |

> **GitHub 说明**：`Docker Desktop Installer.exe` 默认 **不上传** 仓库（见 `.gitignore`）。  
> 网盘完整包可包含该安装包，方便无法访问 Docker 官网的用户。  
> 官网下载：https://www.docker.com/products/docker-desktop/

---

## 两种用法

### 方式 A：给 Agent（推荐）

1. 本机装好并启动 **Docker Desktop**（可用包内 Installer）
2. 把 **`把我拖到agent聊天窗口.md`** 拖进 Agent 聊天窗口
3. 按 Agent 提问回答（脚本放哪、是否改数据盘等）
4. 本机浏览器完成：SnowLuma 改密 → noVNC 扫 QQ → AstrBot 改密 + 配模型
5. 用 `show-passwords.ps1` 看到 `LINKED OK (AstrBot inbound sockets: N)` 即连通

### 方式 B：纯人工

1. 安装并启动 Docker Desktop  
2. 把本文件夹放到例如 `D:\docker-snowluma-astrbot\deploy-kit\`  
3. 双击 `部署工具.bat` → **[1] 启动**  
4. 按 `快速上手.txt` / `使用说明.txt` 完成预配置与登录  

---

## 访问地址（启动后）

| 服务 | 地址 | 账号 |
|------|------|------|
| SnowLuma WebUI | http://127.0.0.1:5099 | `admin` |
| noVNC 扫码桌面 | http://127.0.0.1:6081/ | 密码见脚本输出 |
| AstrBot WebUI | http://127.0.0.1:6185 | `astrbot` |

初始密码用下面命令查看（登录后请立刻修改）：

```powershell
powershell -ExecutionPolicy Bypass -File .\show-passwords.ps1
```

---

## 重要约定

1. **两个路径别搞混**  
   - **A. 脚本文件夹**：本目录小文件放哪（几十 KB）  
   - **B. Docker 数据盘**：镜像/数据卷在哪（约 8–15GB，默认一般不用改）  
2. **OneBot 预配置必须在 QQ 扫码之前完成**（见 `使用说明.txt` 第三步 / 手册 §5.4）  
3. 端口只绑 `127.0.0.1`，不要把 5099 / 6081 暴露公网  
4. 镜像默认：  
   - `m.daocloud.io/docker.io/motricseven7/snowluma:latest`  
   - `m.daocloud.io/docker.io/soulter/astrbot:latest`  

---

## 日常命令

```powershell
.\start.ps1            # 启动
.\show-passwords.ps1   # 地址 / 密码 / 连通
.\status.ps1           # 状态与日志
.\stop.ps1             # 停止
docker compose restart
docker exec -it astrbot astrbot password   # 重置 AstrBot 密码
```

---

## 版本

- **部署包 / 手册：v1.1（2026-11-10）**  
- 变更：本机自助语气 · DaoCloud 默认镜像 · OneBot 预配置强制 · show-passwords 连通检测修复 · A/B 路径说明  

---

## 许可与注意

- 请遵守 SnowLuma、AstrBot 及 Docker 等上游项目的许可协议  
- 本包脚本与文档按仓库内 LICENSE（如有）分发；Docker Desktop 请遵守 Docker 许可条款  
- 部署涉及 QQ 登录与 AI API Key，仅在本人电脑使用，勿把初始密码发到公开聊天  

---

## 传 GitHub 时

```text
应上传：本目录除 Docker Desktop Installer.exe 外的全部文件
不应上传：Docker Desktop Installer.exe（已在 .gitignore）
完整离线包（含 Installer）：自行同步到网盘
```
