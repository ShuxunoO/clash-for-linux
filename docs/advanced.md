## 📄 `docs/advanced.md`

```
# Advanced Usage

本页面包含 clash-for-linux 的 **高级用法与可选功能**。

如果你已经能够正常完成以下事情：

- 安装并启动 Clash 服务
- 通过 SSH 转发访问 Dashboard
- 使用 `proxy_on` / `proxy_off` 控制代理

那么本页面的内容 **不是必须的**。  
只有当你希望 **更精细地控制配置、网络行为或运行方式** 时，再继续阅读。

---

## 1. Mixin Configuration

Mixin 用于在 **不直接修改主配置文件** 的情况下，
对 Clash 配置进行 **追加或覆盖**。

这是推荐的方式，用于长期维护和升级。

### Default Behavior

- 默认读取目录：`config/mixin.d/`
- 按文件名排序后依次合并
- 后加载的文件会覆盖前面的配置

### Example

```yaml
# config/mixin.d/10-rules.yaml
rules:
  - DOMAIN-SUFFIX,example.com,DIRECT
```

修改完成后，重启服务即可生效：

```
clashctl restart
```

### When to Use Mixin

- 添加自定义规则
- 覆盖 DNS、rules、proxies 等配置
- 避免每次更新订阅后手动修改 config.yaml

------

## 2. Tun Mode (Optional)

Tun 模式用于实现 **系统级透明代理**，需要
 **Clash Meta / Premium** 内核支持。

⚠️ 启用 Tun 模式会影响系统网络行为，
 仅建议在你理解其作用与风险时使用。

### Enable Tun Mode

在 `.env` 中配置：

```
export CLASH_TUN_ENABLE=true
export CLASH_TUN_STACK=system
export CLASH_TUN_AUTO_ROUTE=true
export CLASH_TUN_AUTO_REDIRECT=false
export CLASH_TUN_STRICT_ROUTE=false
export CLASH_TUN_DNS_HIJACK='any:53'
```

配置完成后重启服务：

```
clashctl restart
```

------

## 3. systemd Behavior

Clash 默认以 **systemd 服务** 的方式运行。

### Service Characteristics

- 服务异常退出时会自动重启
- 配置文件错误会阻止服务进入运行态
- 服务以低权限用户运行（默认 `clash`）

### Check Service Status

```
systemctl status clash-for-linux.service
```

### View Logs

```
journalctl -u clash-for-linux.service -f
```

日志是排查问题时的 **第一入口**。

------

## 4. Multiple Subscriptions

`clashctl` 支持管理多个订阅地址，
 并在不同订阅之间进行切换。

### Basic Usage

```
clashctl sub add work https://example.com/work
clashctl sub add personal https://example.com/personal
```

### Switch Subscription

```
clashctl sub use work
```

### Update Subscription

```
clashctl sub update
```

------

## 5. Custom Binary

在部分场景下，你可能希望使用：

- 自行编译的 Clash 内核
- 内网分发的二进制
- 特定版本的内核

你可以通过环境变量指定内核路径：

```
export CLASH_BIN=/path/to/clash
```

重启服务后生效。

------

## 6. Security Notes

clash-for-linux 以 **安全默认配置** 为原则：

- 管理接口默认仅监听 `127.0.0.1`
- 推荐使用 SSH 端口转发访问 Dashboard
- 不建议将 `external-controller` 暴露到公网

如果你确实需要对外访问，请确保：

- 已配置强随机 Secret
- 已正确设置防火墙规则
- 理解潜在的安全风险

------

## 7. Troubleshooting

### Service Keeps Restarting

- 检查 `runtime/config.yaml` 是否存在语法错误
- 查看 systemd 日志：

```
journalctl -u clash-for-linux.service -n 100
```

### Dashboard Not Accessible

- 确认 `external-controller` 仅绑定在本机
- 使用 SSH 端口转发方式访问
- 确认服务处于 running 状态

------

## Final Notes

本页面内容 **全部为可选功能**。

如果你不确定是否需要其中某一项，
 **最安全的选择是保持默认配置**。

clash-for-linux 的设计目标是：

> 一次安装，长期稳定运行，而不是频繁折腾。