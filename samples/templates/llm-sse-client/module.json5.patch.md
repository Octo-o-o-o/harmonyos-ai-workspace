# module.json5 改动

在 `entry/src/main/module.json5` 加：

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

## HTTP / HTTPS 注意

鸿蒙默认拦截明文 HTTP（仅 HTTPS 通），如必须用 HTTP，要在 `module.json5` 加：

```json5
{
  "module": {
    "metadata": [
      {
        "name": "ohos.net.http.cleartextTraffic",
        "value": "true"
      }
    ]
  }
}
```

⚠️ 但 AGC 上架会拒（`AGC-RJ-007`：传输明文未加密）。**强烈建议生产用 HTTPS**。
