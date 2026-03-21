## 📄 `docs/install.md`

### 安装与可选参数

```
如果你只需要开箱即用的体验，直接运行：

```bash
sudo bash install.sh
```

即可完成安装。

本页面仅在你需要 **自定义安装行为**（安装路径、运行用户、内核来源等）时才需要阅读。

```
---

### 可选安装参数

所有参数均通过 **环境变量** 在执行 `install.sh` 前指定。

---

### `CLASH_INSTALL_DIR`

```bash
CLASH_INSTALL_DIR=/opt/clash-for-linux
```

- Clash 的安装目录
- 默认值：`/opt/clash-for-linux`
- 适用场景：
  - 多实例部署
  - 特殊磁盘 / 数据目录
  - 需要与系统目录结构对齐的服务器

------

### `CLASH_SERVICE_USER`

```
CLASH_SERVICE_USER=clash
```

- 指定运行 Clash 服务的系统用户
- 默认值：`clash`（安装时自动创建）
- 说明：
  - 使用低权限用户运行是安全最佳实践
  - 不建议使用 `root`

------

### `CLASH_ENABLE_SERVICE`

```
CLASH_ENABLE_SERVICE=true
```

- 是否创建 systemd 服务
- 默认值：`true`
- 设置为 `false` 时：
  - 仅安装文件
  - 不注册 systemd unit

适用于：

- 容器环境
- 不使用 systemd 的系统
- 二次开发或调试

------

### `CLASH_START_SERVICE`

```
CLASH_START_SERVICE=true
```

- 安装完成后是否立即启动服务
- 默认值：`true`
- 设置为 `false` 时：
  - 安装完成后不自动启动
  - 需手动执行 `clashctl start`

------

### `CLASH_AUTO_DOWNLOAD`

```env
CLASH_AUTO_DOWNLOAD=auto

- 是否在本地未检测到可用内核时自动下载 Mihomo 内核
- 可选值：
  - `auto`（默认）：当未检测到可用内核时自动下载（已有内核则不覆盖）
  - `false`：不进行任何自动下载，仅使用本地已有内核（找不到则报错）
  - `true`：强制重新下载内核（即使本地已有也会覆盖）
 
适用于：

- 离线环境
- 使用自定义内核
- 内网服务器

------

### `CLASH_DOWNLOAD_URL_TEMPLATE`

```env
CLASH_DOWNLOAD_URL_TEMPLATE=https://your-mirror.example.com/{version}/mihomo-{arch}-{version}.gz

- Mihomo 内核下载地址模板（可选，高级配置）
- 仅在 CLASH_AUTO_DOWNLOAD=true 或 auto 且本地无内核时生效
- 默认情况下无需配置，脚本会自动使用官方 GitHub Release 地址


适用于：

- 使用私有镜像
- 国内镜像加速
- 自定义构建内核

------

### 使用示例

```
CLASH_INSTALL_DIR=/data/clash \
CLASH_START_SERVICE=false \
sudo bash install.sh
```

------

> ⚠️ 提示
>  如果你不清楚某个参数的含义，**不要设置它**。
>  默认值已覆盖绝大多数使用场景。

```
---

# 二、`advanced.md` 应该怎么写（这是“高手区”）

## advanced.md 的一句话定位

> **“当你已经能正常使用 Clash，但想用得更深、更稳、更可控时，再来看这里。”**

所以它是：  
👉 *可选*  
👉 *不影响主流程*  
👉 *不追求完整，只追求“有入口”*

---

## 📄 `docs/advanced.md`（推荐骨架）

```md
# 高级配置与进阶用法

本页面包含 clash-for-linux 的高级用法与可选功能。
如果你只关心基本代理与 Dashboard，可以跳过本页。
```

------

## 1️⃣ Mixin 配置

```
## Mixin 配置

Mixin 用于在不修改主配置的情况下，追加或覆盖 Clash 配置项。
```

### 默认行为

- 默认读取目录：`config/mixin.d/`
- 按文件名排序后依次合并

### 示例

```
# config/mixin.d/rules.yaml
rules:
  - DOMAIN-SUFFIX,example.com,DIRECT
```

修改完成后重启服务：

```
clashctl restart
```

------

## 2️⃣ Tun 模式（可选）

```
## Tun 模式

Tun 模式用于实现系统级透明代理。
该功能需要 Clash Meta / Premium 支持。
```

### 启用示例

```
export CLASH_TUN_ENABLE=true
export CLASH_TUN_STACK=system
export CLASH_TUN_AUTO_ROUTE=true
```

> ⚠️ Tun 模式会修改系统网络行为，仅建议在你理解其影响时启用。

------

## 3️⃣ systemd 行为说明

```
## systemd 行为说明

Clash 默认以 systemd 服务运行。
```

- 服务失败会自动重启
- 配置错误会阻止服务进入运行态
- 日志查看：

```
journalctl -u clash-for-linux.service -f
```

------

## 4️⃣ 多订阅管理（clashctl）

```
## 多订阅管理

clashctl 支持多个订阅并进行切换。
clashctl sub add work https://example.com/work
clashctl sub use work
clashctl sub update
```

------

## 5️⃣ 安全说明（可选）

```
## 安全说明

- 管理接口默认仅监听 127.0.0.1
- 推荐使用 SSH 端口转发访问 Dashboard
- 不建议将 external-controller 暴露至公网
```