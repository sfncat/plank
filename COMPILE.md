# Plank Dock 编译指南

## 系统依赖

在编译前请确保安装以下依赖：

### 核心依赖
- glib-2.0 >= 2.48.0
- gtk+-3.0 >= 3.10.0
- cairo >= 1.13
- libbamf3 >= 0.4.0
- libwnck-3.0
- gee-0.8
- gdk-pixbuf-2.0 >= 2.26.0

### 构建工具
- autoconf
- automake
- libtool
- valac >= 0.34.0
- vapigen
- glib-compile-resources
- xmllint
- pkg-config

在Ubuntu/Debian系统上可以使用以下命令安装：
```bash
sudo apt install autoconf automake libtool valac vapigen \
libglib2.0-dev libgtk-3-dev libcairo2-dev libbamf3-dev \
libwnck-3-dev libgee-0.8-dev libgdk-pixbuf2.0-dev \
libxi-dev libxfixes-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev
```

### 可选依赖
- xi >= 1.6.99.1 (用于屏障支持)
- xfixes >= 5.0 (用于屏障支持)
- dbusmenu-glib-0.4 >= 0.4 (用于动态快捷菜单)

在Ubuntu/Debian系统上可以使用以下命令安装：
```bash
sudo apt install libglib2.0-dev libgtk-3-dev libcairo2-dev libbamf3-dev \
libwnck-3-dev libgee-0.8-dev libgdk-pixbuf2.0-dev valac vapigen \
libxi-dev libxfixes-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev
```

## 基本编译步骤

1. 生成配置脚本（如果是开发者版本）：
   ```bash
   ./autogen.sh --prefix=/usr
   ```
   或使用标准方式：
   ```bash
   test -f configure || ./bootstrap
   ./configure
   ```

2. 编译项目：
   ```bash
   make -j2  # 使用2个并行任务编译
   ```

3. 安装（可选）：
   ```bash
   sudo make install
   ```

## 常用配置选项

- 指定安装路径：
  ```bash
  ./configure --prefix=/usr/local
  ```

- 启用/禁用特定功能：
  ```bash
  ./configure --enable-debug
  ```

- 查看所有配置选项：
  ```bash
  ./configure --help
  ```

## 运行和测试

- 运行本地编译的Plank：
  ```bash
  ./src/plank
  ```

- 调试模式运行：
  ```bash
  libtool --mode=execute gdb --args src/plank -d
  ```

## 清理

- 清理编译文件：
  ```bash
  make clean
  ```

- 完全清理（包括配置）：
  ```bash
  make distclean
  ```

## 验证安装

安装完成后，可以通过以下方式验证：

1. 检查版本号：
```bash
plank --version
```

2. 运行程序测试功能：
```bash
plank
```

3. 查看安装位置：
```bash
which plank
```

4. 检查安装的文件：
```bash
ls -l /usr/local/bin/plank  # 根据实际安装路径调整
```

## 开发者注意事项

- 代码风格遵循K&R "One True Brace Style"，使用4空格宽的tab缩进
- 提交代码前请阅读HACKING文件中的贡献指南
