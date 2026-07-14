# Godot 开发环境

## 锁定版本

- Godot：`4.7.stable.official.5b4e0cb0f`
- 平台：Windows x86_64，标准版（GDScript）
- 官方下载：<https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7>
- 下载包 SHA-256：`02A5312236F4E0209C78BCB2F52135B1963E6B8888C873C9CEE81459E60BCD71`

Godot 官方 Windows 版本是便携式程序，不需要系统级安装。本地解压目录为 `.tools/godot-4.7/`，整个 `.tools/` 已被 Git 忽略。

## 验证命令

```powershell
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --version
```

预期输出：

```text
4.7.stable.official.5b4e0cb0f
```

## 项目命令

Godot 工程建立后统一使用控制台程序执行自动化检查：

```powershell
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --editor --quit
```

该命令必须无脚本解析错误、资源导入错误或缺失依赖。
