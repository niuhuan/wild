<div align="center">
  <h1 align="center">
    <img src="lib/assets/icon.png" width="200">
    <br/>
    Wild Novel

[![license](https://img.shields.io/github/license/niuhuan/wild)](https://raw.githubusercontent.com/niuhuan/wild/master/LICENSE)
[![releases](https://img.shields.io/github/v/release/niuhuan/wild)](https://github.com/niuhuan/wild/releases)
[![downloads](https://img.shields.io/github/downloads/niuhuan/wild/total)](https://github.com/niuhuan/wild/releases)
  </h1>
</div>

一个使用 Flutter 开发的轻小说文库客户端，提供流畅的阅读体验和丰富的功能。

- 源仓库地址 [https://github.com/niuhuan/wild](https://github.com/niuhuan/wild)

## 截图

<img src="images/IMG_01.PNG" max-width="100%" width="350" /> <img src="images/IMG_02.PNG" max-width="100%" width="350" />


<img src="images/IMG_03.PNG" max-width="100%" width="350" /> <img src="images/IMG_04.PNG" max-width="100%" width="350" />


## 功能特性

### 阅读功能
- 支持小说阅读，支持章节跳转
- 自定义阅读主题（浅色/深色/跟随系统）
- 自定义字体大小、行高、段落间距
- 阅读进度自动保存
- 支持继续阅读功能

### 书架功能
- 书架管理（添加/删除）
- 书架分类管理
- 支持多选操作
- 自动同步阅读进度

### 搜索功能
- 支持按书名和作者搜索
- 搜索历史记录
- 点击作者名快速搜索该作者的其他作品
- 搜索结果无限滚动加载

### 分类浏览
- 支持多种分类标签
- 支持按更新/热门/完结/动画化筛选
- 分类浏览历史记录
- 无限滚动加载

### 排行榜
- 支持多种排序方式（更新/发布/访问量/推荐/收藏等）
- 排行榜浏览历史记录
- 无限滚动加载

### 其他功能
- 用户登录/登出
- 阅读历史记录
- 完结小说专区
- 动画化作品标记
- 自动签到

## 技术架构

### 前端技术栈
- Flutter 3.x
- Dart 3.x
- Material Design 3
- BLoC 状态管理
- 响应式编程

### 后端技术栈
- Rust
- Flutter Rust Bridge (FRB)
- SQLite 本地数据库

### 项目结构
```
lib/
├── cubits/          # 状态管理
├── models/          # 数据模型
├── pages/           # 页面组件
│   ├── home/       # 首页相关
│   ├── novel/      # 小说相关
│   ├── category/   # 分类相关
│   └── ...
├── src/            # Rust 代码
│   └── rust/       # Rust 实现
├── widgets/        # 通用组件
└── main.dart       # 应用入口
```

### 数据流
1. UI 层通过 BLoC 发送事件
2. BLoC 处理事件并调用 Rust 接口
3. Rust 层处理业务逻辑和数据处理
4. 数据通过 FRB 返回给 Dart 层
5. BLoC 更新状态并通知 UI 更新

## 开发环境

- Flutter 3.x
- Dart 3.x
- Rust 1.75+
- Android Studio / VS Code
- Xcode (macOS)

## 构建和运行

1. 安装依赖
```bash
flutter pub get
```

2. 运行开发版本
```bash
flutter run
```

3. 构建发布版本
```bash
flutter build apk  # Android
flutter build ios  # iOS
```

## 责任声明

1. 本项目仅供学习和研究使用，不得用于商业用途
2. 本项目不存储任何小说内容，所有内容均来自网络
3. 本项目不承担任何因使用本软件而产生的法律责任
4. 使用本软件即表示同意以上声明

## 开源协议

本项目采用 GNU General Public License v3.0 (GPLv3) 协议开源。这意味着：

1. 你可以自由使用、修改和分发本软件
2. 你必须保留版权声明和许可声明
3. 如果你分发修改后的版本，必须使用相同的 GPLv3 协议
4. 你必须提供源代码
5. 你的修改必须开源

详情请查看 [LICENSE](LICENSE) 文件。

## 致谢

- [Flutter](https://flutter.dev/)
- [Rust](https://www.rust-lang.org/)
- [Flutter Rust Bridge](https://github.com/fzyzcjy/flutter_rust_bridge)
- [Material Design](https://m3.material.io/)
- [BLoC](https://bloclibrary.dev/)
