# Plank Dock 编译指南（中文）

英文见 [COMPILE_EN.md](COMPILE_EN.md)。本文的包名与命令均在 **Ubuntu 24.04 LTS (noble)** 上实测过。

## 一、构建依赖

configure 阶段会**无条件**检查下列模块（`configure.ac` 里的 `PKG_CHECK_MODULES`），缺一个就配不过：

| 依赖 | 最低版本 | 提供它的 apt 包 |
|---|---|---|
| glib / gobject / gio / gio-unix | 2.48.0 | `libglib2.0-dev` |
| gtk+3 / gdk-x11-3 | 3.10.0 | `libgtk-3-dev` |
| cairo | 1.13 | `libcairo2-dev` |
| gdk-pixbuf | 2.26.0 | `libgdk-pixbuf-2.0-dev` |
| libbamf3 | 0.4.0 | `libbamf3-dev` |
| libwnck-3 | — | `libwnck-3-dev` |
| gee-0.8 | — | `libgee-0.8-dev` |
| **x11** | — | **`libx11-dev`** |
| **libgnome-menu-3.0** | — | **`libgnome-menu-3-dev`** |

构建工具链：`autoconf`、`automake`、`libtool`、`pkg-config`、`gettext`（`AM_GNU_GETTEXT` 需要 `autopoint`）、`valac`。

> `vapigen`、`glib-compile-resources` **不是独立的包**：前者由 `valac` 提供（`/usr/bin/vapigen`），后者由 `libglib2.0-dev-bin` 提供。把它们写进 `apt install` 列表会直接报 *Unable to locate package* 而让整条命令失败。

一条命令装齐：

```bash
sudo apt install autoconf automake libtool pkg-config gettext valac \
  libglib2.0-dev libgtk-3-dev libcairo2-dev libgdk-pixbuf-2.0-dev \
  libbamf3-dev libwnck-3-dev libgee-0.8-dev libx11-dev libgnome-menu-3-dev
```

### 可选依赖（不装也能编，只是少功能）

| 功能 | 需要的包 | 关掉它的开关 |
|---|---|---|
| 指针屏障（贴边隐藏不被鼠标"甩"出去） | `libxi-dev` `libxfixes-dev` | `--disable-barriers` |
| 动态快捷菜单 quicklist | `libdbusmenu-glib-dev` `libdbusmenu-gtk3-dev` | 自动探测，缺了就 `Dbusmenu support: no` |
| Apport 崩溃报告文件 | 无需开发库，只装数据文件 | `--disable-apport` |

## 二、编译安装

```bash
./autogen.sh --prefix=/usr      # 生成 configure 并直接配置（本仓库没有 ./bootstrap）
make -j$(nproc)
sudo make install
```

`autogen.sh` 会跑 `aclocal --install` 和 `autoreconf --force --install`，需要联网拉取缺失的宏。

## 三、运行与验证

```bash
./plank --version            # 安装后
make -C po plank.pot         # 可选：刷新翻译模板
```

不安装直接跑构建产物时，**必须用 libtool 包装脚本** `./src/plank`，它会把 `LD_LIBRARY_PATH` 指到 `lib/.libs`；直接跑 `src/.libs/plank` 会加载系统里已装的旧 `libplank.so.1`。取证方法：

```bash
LD_DEBUG=libs ./src/plank --version 2>&1 | grep 'libplank.so.1 =>'
```

（注意：`=>` 这种行格式只有 `LD_DEBUG=libs` 才输出，用 `LD_DEBUG=files` 取到空值不代表加载失败。）

调试运行：`gdb --args ./src/plank -d`。

## 四、运行期依赖 bamfdaemon（重要）

**"正在运行的程序"图标完全来自 libbamf3 的窗口匹配器。** Ubuntu 22.04/24.04 的 `libbamf3` 只是 D-Bus 客户端，需要会话总线上有 `org.ayatana.bamf` 服务；该服务由 **`bamfdaemon`** 提供，而 `libbamf3-dev` 并**不**依赖它（发行版的 `libplank1` 包才在 Depends 里写了它）。

症状：dock 装好能启动，但只显示钉住的启动器，运行中的程序一个都不出现。

判定：

```bash
sudo apt install bamfdaemon          # 修复；靠系统级 D-Bus 激活文件按需拉起，无需自启动项
```

用 gir1.2-bamf-3 直接问匹配器，若报 `The name org.ayatana.bamf was not provided by any .service files` 且返回 0 个应用，而 `wmctrl -l` 明明有十几个窗口，就是这个原因。

另外：plank 会过滤 `_NET_WM_WINDOW_TYPE_DOCK` 类型的窗口（所以 xfce4-panel 不进 dock），也不会显示自己。

## 五、版本号是怎么来的

`plank_released=0` 时，版本由 `build-aux/git-version-gen` 从 `git describe` 推导（例如 `0.11.89.31-6ce2`）。**只改 `configure.ac` 里的 m4 版本段是没用的。** 两条正路：

- 发版：给提交打标签 `git tag 0.12`，之后 `git describe` 自然给出 `0.12`；
- 本地固定：在源码根放一个 `.tarball-version` 写上 `0.12`（脚本先读它，再看 git）。

## 六、踩过的坑

- **改完 docklet 的 `.vala`，一次 `make -j8` 不会重链 `.so`**：VALAC 生成了新 `.c`，但同一轮递归 make 里没跑 CCLD。要么再 `make` 一次，要么 `touch` 后重编。
- `autogen.sh` 里的 `automake --force-missing` 会覆盖受版本管理的辅助文件。本仓库已改用 `AM_INIT_AUTOMAKE([foreign ...])`，因此不再需要 `INSTALL`（GNU 通用模板，对本项目第一步就失效，已删除）。
- `make clean` **不清 `po/*.gmo`**，所以两次构建的告警总数会因为 msgfmt 没重跑而变化，别把它当成代码差异。
- dock 正在运行时执行 `sudo make install`（或用 apt 替换 libgtk/libbamf3 等）会换掉已 mmap 的库文件，是经典的 SIGBUS/SIGSEGV 来源。先停再装。

## 七、打 deb 包

```bash
sudo apt install debhelper dpkg-dev build-essential fakeroot
dpkg-buildpackage -us -uc -b          # 产物在上级目录
```

`debian/` 只出**一个**运行包 `plank`（含 dock 本体、libplank、7 个 docklet、主题、翻译）加一个可选的 `-dbgsym`（调试符号，只在解析崩溃栈时才需要装）。不再拆 `libplank1` / `libplank-common`，也不再发开发文件（头文件、`.pc`、`.vapi` —— 见 `debian/not-installed`）：只出 amd64 时 `Architecture: all` 的数据包省不下任何东西，而只要不发头文件，就不可能有外部程序去链这个库。所以 `sudo apt install ./plank_0.12-2_amd64.deb` 一条命令就够，不需要先凑齐兄弟包。

