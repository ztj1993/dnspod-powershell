# DNSPod-PowerShell

基于 DNSPod 用户 API 实现的纯 PowerShell 实现的动态域名客户端。

这个软件由 `rehiy/dnspod-shell` 转换过来的，与源项目保持了相同的配置命令和调用方式。

## 使用方法

设置执行策略：
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

执行远程脚本：
```
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex
```

设置令牌：
```
$arToken = "12345,7676f344eaeaea9074c123451234512d"
```

设置如果域名没有定义是否新建(按需)：
```
$arIsCreateRecord = 1
```

域名更新：
```
arDdnsCheck test.org subdomain
```

## 定时执行

下载脚本到本地：
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
$CodeUri = "https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main"
$ScriptDir = "$env:USERPROFILE\Documents\PowerShell\DDNS"
New-Item -Path "$ScriptDir" -ItemType Directory -Force
iwr "$CodeUri/ardnspod.ps1" -OutFile "$ScriptDir\ardnspod.ps1"
iwr "$CodeUri/ddnspod.ps1" -OutFile "$ScriptDir\ddnspod.ps1"
```

编辑 `ddnspod.ps1` 脚本，更改 `arToken` 和 `arDdnsCheck` 命令为正确的配置。

创建定时任务：
```
$Cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ddnspod.ps1"
schtasks /create /sc hourly /tn "DdnsTask" /tr "$Cmd" /ru SYSTEM /wd "$ScriptDir"
```

(附)立即运行任务：
```
schtasks /run /tn "DdnsTask"
```

(附)删除定时任务：
```
schtasks /delete /tn "DdnsTask" /f
```

(附)快速创建定时任务：
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
$ScriptName = "DdnsTask.ps1"
$ScriptLog = "DdnsTask.log"
$ScriptDir = "$env:USERPROFILE\Documents\PowerShell\DDNS"
$ScriptFile = Join-Path $ScriptDir $ScriptName
New-Item -Path "$ScriptDir" -ItemType Directory -Force
$Script = @'
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex
$arToken = "12345,7676f344eaeaea9074c123451234512d"
arDdnsCheck test.org subdomain
'@
$Script | Out-File -FilePath $ScriptFile -Encoding UTF8
$Cmd = "cmd /c cd /d $ScriptDir && powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptName >> $ScriptLog"
schtasks /create /sc hourly /tn "DdnsTask" /tr "$Cmd" /ru SYSTEM
```

## 其它方法

手动创建配置：
```
arDdnsCreate test.org subdomain 4 192.168.0.100
```

删除域名配置：
```
arDdnsDelete test.org subdomain 4
```

## 最近更新

2025/03/19

- 推送第一个版本
- 支持动态域名客户端基本功能
- 支持删除域名记录
- 支持手动创建域名记录
