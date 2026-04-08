# DNSPod-PowerShell

基于 DNSPod 用户 API 实现的纯 PowerShell 实现的动态域名客户端。

这个软件由 `rehiy/dnspod-shell` 转换过来的，与源项目保持了相同的配置命令和调用方式。

## 使用方法(参考 ddnspod.ps1)
```powershell
# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# 执行远程脚本
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex
# 设置令牌：
$arToken = "12345,7676f344eaeaea9074c123451234512d"
# 设置如果域名没有定义是否新建(按需)：
$arIsCreateRecord = 1
# 域名更新：
arDdnsCheck test.org subdomain
```

## 其它使用方法

### Windows PowerShell 环境自动安装(参考 auto_install.ps1)
此脚本会创建定时任务，每小时执行一次。

下载的脚本位于 `%USERPROFILE%\Documents\PowerShell\DDNS` 目录下。

清理时删除目录脚本和定时任务即可。
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$env:AR_TOKEN="12345,7676f344eaeaea9074c123451234512d"
$env:AR_DOMAIN="test.org"
$env:AR_SUBDOMAIN="subdomain"
$env:AR_IP_VERSION="6"
$env:AR_IS_CREATE_RECORD="true"

irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/auto_install.ps1 | iex
```

### Windows CMD 环境自动安装(参考 auto_install.bat)
此脚本会创建定时任务，每小时执行一次。

下载的脚本位于 `%USERPROFILE%\Documents\PowerShell\DDNS` 目录下。

清理时删除目录脚本和定时任务即可。
```bat
set TASK_NAME=DdnsTask
set AR_TOKEN=12345,7676f344eaeaea9074c123451234512d
set AR_DOMAIN=test.org
set AR_SUBDOMAIN=subdomain
set AR_IP_VERSION=6
set AR_IS_CREATE_RECORD=true
curl -sS -k -o %TEMP%\ddnspod.bat https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/auto_install.bat && %TEMP%\ddnspod.bat
```

(附)立即运行任务：
```
schtasks /run /tn "DdnsTask"
```

(附)删除定时任务：
```
schtasks /delete /tn "DdnsTask" /f
```

## 命令行可用命令

手动创建域名记录：
```
arDdnsCreate test.org subdomain 4 192.168.0.100
```

删除域名记录：
```
arDdnsDelete test.org subdomain 4
```

## 其它常用命令

立即运行任务：
```
schtasks /run /tn "DdnsTask"
```

删除定时任务：
```
schtasks /delete /tn "DdnsTask" /f
```

## 最近更新

2026/04/08

- 增加 auto_install.cmd 自动安装脚本
- 更新 README

2025/03/19

- 推送第一个版本
- 支持动态域名客户端基本功能
- 支持删除域名记录
- 支持手动创建域名记录
