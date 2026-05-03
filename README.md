# Finder Video Grid

当前版本：`1.2`

macOS Finder 右键快速操作，为视频生成一张 1920 x 1080 的视频网格图。

## 功能

- 抽取 16 帧，拼成 4 x 4 视频网格
- 顶部显示文件名、大小、分辨率、视频/音频编码和时长
- 每个画面底部显示时间戳
- 默认输出到视频同目录的 `视频网格` 文件夹
- 同名图片自动追加序号，不覆盖旧图

## v1.2 更新

- Swift module cache 不再生成到视频网格输出文件夹
- Swift 缓存统一写入 `~/Library/Caches/finder-video-grid/`
- 运行后会自动清理输出文件夹里的旧 `swift-module-cache`
- 仓库首页整理为核心 workflow 加 README 的清爽结构

## 安装

1. 到 GitHub Release 下载 `finder-video-grid-1.2.pkg`
2. 双击安装，按提示输入管理员密码
3. 在 Finder 中右键视频文件，选择：

```text
快速操作 > 生成视频网格
```

需要先安装 `ffmpeg`：

```bash
brew install ffmpeg
```

如果 macOS 提示安装包来自未认证开发者，可以在 Finder 中按住 Control 点击 pkg 后选择“打开”。当前 pkg 未做 Developer ID 签名。

## 仓库结构

```text
生成视频网格.workflow/
README.md
.gitignore
```

核心处理脚本位于：

```text
生成视频网格.workflow/Contents/Resources/create-video-contact-sheet.sh
```

## 卸载

```bash
sudo rm -rf "/Library/Services/生成视频网格.workflow"
/System/Library/CoreServices/pbs -flush
killall Finder
```
