# Finder Video Grid

当前版本：`1.1`

在 Finder 中右键视频文件，通过 macOS 的“快速操作”生成一张带视频信息的 1080p 视频网格图。

## 功能

- 抽取 16 帧。
- 第一帧从第 5 秒开始；如果视频不足 5 秒，则从第 0 秒开始。
- 其余 15 帧在剩余时长内平均分布。
- 拼成带顶部信息区的 4 x 4 视频网格图。
- 输出尺寸为 1920 x 1080。
- 顶部显示文件名、大小、分辨率、视频/音频解码器和时长。
- 每个画面底部叠加对应时间戳。
- 生成文件默认保存在视频同目录的 `视频网格` 文件夹，命名为 `原文件名_grid_1080p.jpg`。
- 如果同名图片已经存在，会自动生成 `原文件名_grid_1080p_2.jpg`、`原文件名_grid_1080p_3.jpg`，不会覆盖旧图。

## 文件说明

- `create-video-contact-sheet.sh`：实际处理视频的脚本。
- `生成视频网格.workflow`：Finder/Automator 快速操作。
- `install-finder-quick-action.sh`：安装脚本，会复制 workflow、启用快速操作，并刷新 Finder。
- `uninstall-finder-quick-action.sh`：卸载脚本，会移除 workflow、处理脚本和服务菜单记录。
- `build-pkg.sh`：生成 macOS `.pkg` 安装包。
- `VERSION`：当前版本号。
- `CHANGELOG.md`：版本记录。

## 依赖

需要安装 `ffmpeg`。脚本还会调用 macOS 的 `/usr/bin/swift` 来绘制视频网格版式和文字信息。

```bash
brew install ffmpeg
```

## 安装 Finder 快速操作

推荐从 GitHub Release 下载并直接安装 pkg：

```text
finder-video-grid-1.1.pkg
```

双击打开安装包，按提示输入管理员密码。安装完成后，在 Finder 中右键视频文件，选择：

```text
快速操作 > 生成视频网格
```

pkg 会把快速操作安装到：

```text
/Library/Services/生成视频网格.workflow
```

如果 macOS 提示安装包来自未认证开发者，可以在 Finder 中按住 Control 点击 pkg 后选择“打开”。当前 pkg 未做 Developer ID 签名。

Release 同时提供源码包：

```text
finder-video-grid-1.1-source.zip
```

### 从源码安装

如果你下载的是源码包，也可以在源码目录运行：

```bash
chmod +x install-finder-quick-action.sh
./install-finder-quick-action.sh
```

安装脚本会把快速操作安装到：

```text
~/Library/Services/生成视频网格.workflow
```

同时会把处理脚本复制到：

```text
~/Library/Application Scripts/com.codex.video-grid/create-video-contact-sheet.sh
```

## 卸载

如果使用 pkg 安装，先运行源码包里的卸载脚本：

```bash
chmod +x uninstall-finder-quick-action.sh
./uninstall-finder-quick-action.sh
```

如果终端提示系统级 workflow 需要管理员权限，继续运行它打印出的命令：

```bash
sudo rm -rf '/Library/Services/生成视频网格.workflow'
```

然后刷新 Finder：

```bash
/System/Library/CoreServices/pbs -flush
killall Finder
```

卸载脚本也会清理 1.0 使用过的旧名称和旧脚本目录。

## 使用方式

安装后在 Finder 中选择一个或多个视频文件，右键选择：

```text
快速操作 > 生成视频网格
```

在部分 macOS 版本中，它也可能显示在：

```text
Services / 服务
```

## 如果右键菜单没有出现

先重新运行安装脚本：

```bash
./install-finder-quick-action.sh
```

如果仍然没有出现，打开系统设置手动启用：

```text
系统设置 > 键盘 > 键盘快捷键 > 服务 > 文件和文件夹 > 生成视频网格
```

确认已勾选后，重启 Finder：

```bash
killall Finder
```

## 直接命令行使用

```bash
./create-video-contact-sheet.sh /path/to/video.mp4
```

也可以一次传入多个视频：

```bash
./create-video-contact-sheet.sh /path/to/a.mp4 /path/to/b.mov
```

## 版本

当前稳定版本为 `1.1`。
