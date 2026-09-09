# 今日幸运签 · Flutter 客户端

## 前置
1. 安装 [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
2. 已有 Android Studio，执行 `flutter doctor` 把 Android  toolchain 配好

## 初始化工程（首次）
在 `mobile` 目录执行（会补齐 android/ios 平台文件，不覆盖已有 `lib/`）：

```powershell
cd c:\Users\Administrator\Desktop\App\mobile
flutter create . --project-name lucky_sign --org com.luckysign
flutter pub get
```

## 连接后端
- 模拟器默认：`http://10.0.2.2:8080`（已写在 `lib/config.dart`）
- 真机：改成电脑局域网 IP，例如：

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
