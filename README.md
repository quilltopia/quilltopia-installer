# quilltopia-installer

下载并安装 [quilltopia v0.0.4](https://github.com/quilltopia/quilltopia/releases/tag/v0.0.4) 的独立引导脚本。

要求 Apple Silicon Mac、macOS 26 或更高版本，以及已安装的 GitHub CLI (`gh`)。
如果 Release 需要认证，先运行 `gh auth login`，使用有仓库读取权限的账号。

```sh
./install.sh
```

脚本使用 `gh release download` 下载固定版本的
`quilltopia-aarch64-apple-darwin.tar.gz` 和同名 `.sha256` 文件，校验 SHA-256 后解压，
调用其中的 `quilltopia/install.sh`。不会下载 latest。

安装参数原样传递给包内安装器：

```sh
# 跳过安装确认，适用于非交互环境
./install.sh --force

# 指定安装根目录；包含空格时加引号
./install.sh --install-root "$HOME/Applications/quilltopia"
```

默认安装到 `~/.quilltopia`。安装和恢复行为以目标版本的
[安装说明](https://github.com/quilltopia/quilltopia/blob/v0.0.4/INSTALL.md) 为准。

下载、校验或解压失败会终止，不运行安装器。成功后删除临时下载与解包目录；
安装失败或中断时保留 suite 并输出路径，以便使用其中的独立 `bin/qu` 恢复安装。
SHA-256 用于校验下载内容与同一 Release 的校验文件一致。

该目录可整体迁移到独立的 `quilltopia-installer` 仓库，不依赖 quilltopia 源码或工具链。
