# DNSPod-PowerShell

A dynamic DNS client implemented in pure PowerShell based on the DNSPod user API.

This project is converted from `rehiy/dnspod-shell` and keeps the familiar command style from the original project.

## Features

- Pure PowerShell implementation
- Supports IPv4 (`A`) and IPv6 (`AAAA`) records
- Supports automatic record creation when the record does not exist
- Supports binding to a specific network interface
- Supports manual record creation and deletion
- Includes Windows scheduled-task auto-install scripts for PowerShell and CMD
- Includes mock tests and integration tests

## Requirements

- Windows PowerShell 5.1 or later
- A DNSPod API token in the format `ID,Token`
- Administrator privileges for `auto_install.ps1` and `auto_install.bat`

## Quick Start

Reference script: `ddnspod.ps1`

```powershell
# Allow local script execution for the current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Load functions from GitHub
irm https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1 | iex

# Set your DNSPod token
$arToken = "12345,7676f344eaeaea9074c123451234512d"

# Create the record automatically if it does not exist
$arIsCreateRecord = $true

# Update an IPv4 record
arDdnsCheck "test.org" "subdomain"

# Update an IPv6 record
arDdnsCheck "test.org" "subdomain6" 6

# Update by binding to a specific interface
arDdnsCheck "test.org" "subdomain" 4 "Ethernet"
```

## Core Commands

### Update a record

```powershell
arDdnsCheck "<domain>" "<subdomain>" [4|6] [interface]
```

Examples:

```powershell
arDdnsCheck "example.com" "home"
arDdnsCheck "example.com" "home" 6
arDdnsCheck "example.com" "home" 4 "Ethernet"
```

### Create a record manually

```powershell
arDdnsCreate "example.com" "home" "A" "192.168.0.100"
arDdnsCreate "example.com" "home6" "AAAA" "2001:db8::100"
```

### Delete a record

```powershell
arDdnsDelete "example.com" "home" 4
arDdnsDelete "example.com" "home6" 6
```

## Configuration Variables

Variables used by `ardnspod.ps1` and `ddnspod.ps1`:

- `$arToken`: DNSPod API token, format `ID,Token`
- `$arIp4QueryUrl`: public IPv4 query endpoint, default `http://ipv4.ddnsip.cn`
- `$arIp6QueryUrl`: public IPv6 query endpoint, default `http://ipv6.ddnsip.cn`
- `$arLastRecordFile`: cache file prefix for the last synced IP
- `$arErrCodeUnchanged`: optional exit code when the IP is unchanged
- `$arIsCreateRecord`: whether to create a missing record automatically

## Automatic Installation

Both install scripts:

- download `ardnspod.ps1`
- generate a task script in the target directory
- create an hourly Windows scheduled task
- start the task once immediately after installation

Default script directory:

```text
%USERPROFILE%\Documents\PowerShell\DDNS
```

### PowerShell installer

Reference script: `auto_install.ps1`

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

Supported parameters and environment variables:

- `TaskName` / `AR_TASK_NAME`: scheduled task name, default `DdnsTask`
- `Token` / `AR_TOKEN`: required DNSPod token
- `Domain` / `AR_DOMAIN`: required domain
- `Subdomain` / `AR_SUBDOMAIN`: required subdomain
- `IpVersion` / `AR_IP_VERSION`: `4` or `6`, default `4`
- `Interface` / `AR_INTERFACE`: optional network interface alias
- `IsCreate` / `AR_IS_CREATE_RECORD`: `true` or `false`, default `false`
- `ScriptDir` / `AR_SCRIPT_DIR`: script output directory
- `ScriptUrl` / `AR_SCRIPT_URL`: custom `ardnspod.ps1` download URL

Show built-in help:

```powershell
.\auto_install.ps1 -Help
```

### CMD installer

Reference script: `auto_install.bat`

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

The CMD installer reads configuration from these environment variables:

- `AR_TOKEN`
- `AR_DOMAIN`
- `AR_SUBDOMAIN`
- `AR_IP_VERSION`
- `AR_INTERFACE`
- `AR_IS_CREATE_RECORD`
- `AR_SCRIPT_DIR`
- `AR_SCRIPT_URL`

## Scheduled Task Management

Run the task immediately:

```bat
schtasks /run /tn "DdnsTask"
```

Delete the scheduled task:

```bat
schtasks /delete /tn "DdnsTask" /f
```

## Tests

Test files:

- `tests/ardnspod.Mock.Tests.ps1`
- `tests/ardnspod.Integration.Tests.ps1`

Run mock tests:

```powershell
Invoke-Pester .\tests\ardnspod.Mock.Tests.ps1
```

Run integration tests:

```powershell
$env:AR_TOKEN="12345,token"
$env:AR_DOMAIN="example.com"
$env:AR_SUBDOMAIN="ddns-test"
Invoke-Pester .\tests\ardnspod.Integration.Tests.ps1
```

Integration tests create and delete temporary DNS records. Use a safe test subdomain.

## Recent Updates

2026/04/22

- Updated English and Chinese documentation
- Added usage details for interface binding and auto-install parameters
- Added test instructions

2026/04/08

- Added automatic installation script for CMD
- Updated README

2025/03/19

- Initial release
- Added basic DDNS update support
- Added domain record deletion support
- Added manual domain record creation support
