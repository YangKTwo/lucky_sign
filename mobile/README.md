# 今日幸运签 · Flutter 客户端

## 前端技术栈

| 层 | 技术 |
|---|---|
| 框架 | **Flutter**（Dart SDK ≥ 3.3，Material 3） |
| 状态 | 原生 `StatefulWidget` + `setState`；未读角标用 `ValueNotifier`（`ChatInbox`） |
| 网络 | `http` REST；`stomp_dart_client` WebSocket/STOMP 社区聊天 |
| 本地存储 | `shared_preferences`（JWT / userId / 未读） |
| 媒体 | `image_picker`（打卡图、头像） |
| 工具 | `intl` 日期；`http_parser` 上传 MIME |
| 路由 | `MaterialApp` + `Navigator`（无 go_router / 状态库） |
| 目标平台 | Android / iOS / Web |

**不是** React Native / Vue / 小程序；也未使用 Provider、Riverpod、Bloc、GetX。

## 前置
1. 安装 [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
2. 已有 Android Studio，执行 `flutter doctor` 把 Android toolchain 配好

## 初始化工程（首次）
在 `mobile` 目录执行（会补齐 android/ios 平台文件，不覆盖已有 `lib/`）：

```powershell
cd c:\Users\Administrator\Desktop\App\mobile
flutter create . --project-name lucky_sign --org com.luckysign
flutter pub get
```

## 连接后端
- 默认连云端（见 `lib/config.dart`）
- 模拟器本机后端：`--dart-define=API_BASE=http://10.0.2.2:8080 --dart-define=WS_BASE=ws://10.0.2.2:8080/ws`
- 真机局域网示例：

```powershell
flutter run --dart-define=API_BASE=http://192.168.1.8:8080 --dart-define=WS_BASE=ws://192.168.1.8:8080/ws
```

## 运行
先启动后端，再（选安卓模拟器或 Chrome，不要选 Windows）：

```powershell
flutter run -d emulator-5554
# 或
flutter run -d chrome
```

工程只保留 Android / iOS / Web，已去掉 Windows / Linux / macOS 桌面端。
