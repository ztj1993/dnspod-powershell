# DNSPod-PowerShell

基于 DNSPod 用户 API 的纯 PowerShell 动态域名客户端。

本项目由 `rehiy/dnspod-shell` 转换而来，尽量保持与原项目一致的配置方式和调用习惯。

## 功能特性

- 纯 PowerShell 实现
- 支持 IPv4 (`A`) 和 IPv6 (`AAAA`) 记录
- 支持记录不存在时自动创建
- 支持绑定指定网卡获取 IP
- 支持手动创建和删除记录
- 提供 PowerShell 和 CMD 两种 Windows 定时任务自动安装脚本
- 附带 Mock 测试与集成测试

## 环境要求

- Windows PowerShell 5.1 或更高版本
- DNSPod API Token，格式为 `ID,Token`
- 使用 `auto_install.ps1` 或 `auto_install.bat` 时需要管理员权限

## 快速开始

参考脚本：`ddnspod.ps1`

```powershell
# 为当前用户允许本地脚本执行
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 从 GitHub 加载函数
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex

# 设置 DNSPod Token
$arToken = "12345,7676f344eaeaea9074c123451234512d"

# 记录不存在时自动创建
$arIsCreateRecord = $true

# 更新 IPv4 记录
arDdnsCheck "test.org" "subdomain"

# 更新 IPv6 记录
arDdnsCheck "test.org" "subdomain6" 6

# 绑定指定网卡更新
arDdnsCheck "test.org" "subdomain" 4 "Ethernet"
```

## 核心命令

### 更新记录

```powershell
arDdnsCheck "<domain>" "<subdomain>" [4|6] [interface]
```

示例：

```powershell
arDdnsCheck "example.com" "home"
arDdnsCheck "example.com" "home" 6
arDdnsCheck "example.com" "home" 4 "Ethernet"
```

### 手动创建记录

```powershell
arDdnsCreate "example.com" "home" "A" "192.168.0.100"
arDdnsCreate "example.com" "home6" "AAAA" "2001:db8::100"
```

### 删除记录

```powershell
arDdnsDelete "example.com" "home" 4
arDdnsDelete "example.com" "home6" 6
```

## 配置变量

`ardnspod.ps1` 和 `ddnspod.ps1` 使用的主要变量：

- `$arToken`：DNSPod API Token，格式 `ID,Token`
- `$arIp4QueryUrl`：公网 IPv4 查询地址，默认 `http://ipv4.ddnsip.cn`
- `$arIp6QueryUrl`：公网 IPv6 查询地址，默认 `http://ipv6.ddnsip.cn`
- `$arLastRecordFile`：上次同步 IP 的缓存文件前缀
- `$arErrCodeUnchanged`：IP 未变化时可返回的退出码
- `$arIsCreateRecord`：记录不存在时是否自动创建

## 自动安装

两种安装脚本都会执行以下操作：

- 下载 `ardnspod.ps1`
- 在目标目录生成任务执行脚本
- 创建每小时运行一次的 Windows 定时任务
- 安装完成后立即执行一次任务

默认脚本目录：

```text
%USERPROFILE%\Documents\PowerShell\DDNS
```

### PowerShell 自动安装

参考脚本：`auto_install.ps1`

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$env:AR_TOKEN="12345,7676f344eaeaea9074c123451234512d"
$env:AR_DOMAIN="test.org"
$env:AR_SUBDOMAIN="subdomain"
$env:AR_IP_VERSION="6"
$env:AR_INTERFACE="Ethernet"
$env:AR_IS_CREATE_RECORD="true"

irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/auto_install.ps1 | iex
```

支持的参数与环境变量：

- `TaskName` / `AR_TASK_NAME`：计划任务名，默认 `DdnsTask`
- `Token` / `AR_TOKEN`：必填，DNSPod Token
- `Domain` / `AR_DOMAIN`：必填，主域名
- `Subdomain` / `AR_SUBDOMAIN`：必填，子域名
- `IpVersion` / `AR_IP_VERSION`：`4` 或 `6`，默认 `4`
- `Interface` / `AR_INTERFACE`：可选，网卡别名
- `IsCreate` / `AR_IS_CREATE_RECORD`：`true` 或 `false`，默认 `false`
- `ScriptDir` / `AR_SCRIPT_DIR`：脚本输出目录
- `ScriptUrl` / `AR_SCRIPT_URL`：自定义 `ardnspod.ps1` 下载地址

查看内置帮助：

```powershell
.\auto_install.ps1 -Help
```

### CMD 自动安装

参考脚本：`auto_install.bat`

```bat
set TASK_NAME=DdnsTask
set AR_TOKEN=12345,7676f344eaeaea9074c123451234512d
set AR_DOMAIN=test.org
set AR_SUBDOMAIN=subdomain
set AR_IP_VERSION=6
set AR_INTERFACE=Ethernet
set AR_IS_CREATE_RECORD=true
curl -sS -k -o %TEMP%\ddnspod.bat https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/auto_install.bat && %TEMP%\ddnspod.bat %TASK_NAME%
```

CMD 安装脚本读取以下环境变量：

- `AR_TOKEN`
- `AR_DOMAIN`
- `AR_SUBDOMAIN`
- `AR_IP_VERSION`
- `AR_INTERFACE`
- `AR_IS_CREATE_RECORD`
- `AR_SCRIPT_DIR`
- `AR_SCRIPT_URL`

## 定时任务管理

立即运行任务：

```bat
schtasks /run /tn "DdnsTask"
```

删除定时任务：

```bat
schtasks /delete /tn "DdnsTask" /f
```

## 测试

测试文件：

- `tests/ardnspod.Mock.Tests.ps1`
- `tests/ardnspod.Integration.Tests.ps1`

运行 Mock 测试：

```powershell
Invoke-Pester .\tests\ardnspod.Mock.Tests.ps1
```

运行集成测试：

```powershell
$env:AR_TOKEN="12345,token"
$env:AR_DOMAIN="example.com"
$env:AR_SUBDOMAIN="ddns-test"
Invoke-Pester .\tests\ardnspod.Integration.Tests.ps1
```

集成测试会创建并删除临时 DNS 记录，建议使用专门的测试子域名。

## 最近更新

2026/04/22

- 更新中英文文档
- 补充网卡绑定、自动安装参数等说明
- 补充测试运行说明

2026/04/08

- 增加 CMD 自动安装脚本
- 更新 README

2025/03/19

- 首次发布
- 支持基础 DDNS 更新
- 支持删除域名记录
- 支持手动创建域名记录
