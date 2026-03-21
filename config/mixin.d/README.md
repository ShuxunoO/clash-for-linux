# Mixin 配置目录

将额外的 Clash YAML 配置放在此目录下，脚本会按文件名排序后依次拼接到生成的 `config.yaml` 末尾。

如需手动指定顺序或使用自定义路径，请在 `.env` 中设置：

```bash
export CLASH_MIXIN_PATHS='config/mixin.d/base.yaml,config/mixin.d/rules.yaml'
```
