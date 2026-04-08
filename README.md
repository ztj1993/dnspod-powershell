# DNSPod-PowerShell

A dynamic domain name client implemented purely in PowerShell based on DNSPod user API.

This software is converted from `rehiy/dnspod-shell` and maintains the same configuration commands and calling methods as the original project.

## Usage (reference ddnspod.ps1)
```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Execute remote script
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex
# Set token:
$arToken = "12345,7676f344eaeaea9074c123451234512d"
# Set whether to create new record if domain is not defined (as needed):
$arIsCreateRecord = 1
# Domain update:
arDdnsCheck test.org subdomain
```

## Other Usage Methods

### Windows PowerShell Environment Automatic Installation (reference auto_install.ps1)
This script will create a scheduled task that executes every hour.

The downloaded script is located in the `%USERPROFILE%\Documents\PowerShell\DDNS` directory.

To clean up, simply delete the directory scripts and the scheduled task.
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$env:AR_TOKEN="12345,7676f344eaeaea9074c123451234512d"
$env:AR_DOMAIN="test.org"
$env:AR_SUBDOMAIN="subdomain"
$env:AR_IP_VERSION="6"
$env:AR_IS_CREATE_RECORD="true"

irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/auto_install.ps1 | iex
```

### Windows CMD Environment Automatic Installation (reference auto_install.bat)
This script will create a scheduled task that executes every hour.

The downloaded script is located in the `%USERPROFILE%\Documents\PowerShell\DDNS` directory.

To clean up, simply delete the directory scripts and the scheduled task.
```bat
set TASK_NAME=DdnsTask
set AR_TOKEN=12345,7676f344eaeaea9074c123451234512d
set AR_DOMAIN=test.org
set AR_SUBDOMAIN=subdomain
set AR_IP_VERSION=6
set AR_IS_CREATE_RECORD=true
curl -sS -k -o %TEMP%\ddnspod.bat https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/auto_install.bat && %TEMP%\ddnspod.bat
```

(Appendix) Run task immediately:
```
schtasks /run /tn "DdnsTask"
```

(Appendix) Delete scheduled task:
```
schtasks /delete /tn "DdnsTask" /f
```

## Available Command Line Commands

Manually create domain record:
```
arDdnsCreate test.org subdomain 4 192.168.0.100
```

Delete domain record:
```
arDdnsDelete test.org subdomain 4
```

## Other Common Commands

Run task immediately:
```
schtasks /run /tn "DdnsTask"
```

Delete scheduled task:
```
schtasks /delete /tn "DdnsTask" /f
```

## Recent Updates

2026/04/08

- Added auto_install.cmd automatic installation script
- Update README

2025/03/19

- Push first version
- Supported basic dynamic domain name client functionality
- Supported domain record deletion
- Supported manual domain record creation
