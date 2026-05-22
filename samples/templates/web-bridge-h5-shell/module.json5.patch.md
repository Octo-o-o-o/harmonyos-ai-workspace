# module.json5 改动

在 `entry/src/main/module.json5` 的 `module.requestPermissions` 里加：

```json5
{
  "module": {
    "requestPermissions": [
      // 加载远端资源 / SSE 等都需要
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

如果 H5 还需要访问相机 / 麦克风 / 文件，按业务再追加；不要默认全开（`AGC-RJ-002` 拒因：申请未使用的敏感权限）。

# resources/rawfile 准备

把你的 H5 离线包构建产物放到：

```
entry/
└── src/main/resources/rawfile/
    └── dist/
        ├── index.html
        ├── assets/
        └── ...
```

`WebViewHost.ets` 中 `src: 'resource://rawfile/dist/index.html'` 即对应这条路径。
