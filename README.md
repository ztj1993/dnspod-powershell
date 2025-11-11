# DNSPod-PowerShell

A dynamic domain name client implemented purely in PowerShell based on DNSPod user API.

This software is converted from `rehiy/dnspod-shell` and maintains the same configuration commands and calling methods as the original project.

## Usage

Set execution policy:
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Execute remote script:
```
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex
```

Set token:
```
$arToken = "12345,7676f344eaeaea9074c123451234512d"
```

Set whether to create new record if domain is not defined (as needed):
```
$arIsCreateRecord = 1
```

Domain update:
```
arDdnsCheck test.org subdomain
```

## Scheduled Execution

Download script to local:
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
$CodeUri = "https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main"
$ScriptDir = "$env:USERPROFILE\Documents\PowerShell\DDNS"
New-Item -Path "$ScriptDir" -ItemType Directory -Force
iwr "$CodeUri/ardnspod.ps1" -OutFile "$ScriptDir\ardnspod.ps1"
iwr "$CodeUri/ddnspod.ps1" -OutFile "$ScriptDir\ddnspod.ps1"
```

Edit the `ddnspod.ps1` script, change `arToken` and `arDdnsCheck` commands to the correct configuration.

Create scheduled task:
```
$Cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ddnspod.ps1"
schtasks /create /sc hourly /tn "DdnsTask" /tr "$Cmd" /ru SYSTEM /wd "$ScriptDir"
```

(Appendix) Run task immediately:
```
schtasks /run /tn "DdnsTask"
```

(Appendix) Delete scheduled task:
```
schtasks /delete /tn "DdnsTask" /f
```

(Appendix) Quick create scheduled task:
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

## Other Methods

Manually create configuration:
```
arDdnsCreate test.org subdomain 4 192.168.0.100
```

Delete domain configuration:
```
arDdnsDelete test.org subdomain 4
```

## Recent Updates

2025/03/19

- Push first version
- Supported basic dynamic domain name client functionality
- Supported domain record deletion
- Supported manual domain record creation
