<#
.SYNOPSIS
    DNSPod Dynamic DNS Auto-Deployment Script
.DESCRIPTION
    1. Automatically creates working directory at $env:USERPROFILE\Documents\PowerShell\DDNS
    2. Downloads the latest ardnspod.ps1 core script from GitHub
    3. Generates execution script DdnsTask.ps1 based on parameters or environment variables
    4. Automatically creates a Windows Scheduled Task for silent hourly background execution
#>

[CmdletBinding()]
param (
    [switch]$Help,
    [string]$TaskName = $(if ($env:AR_TASK_NAME) { $env:AR_TASK_NAME } else { "DdnsTask" }),
    [string]$Token = $env:AR_TOKEN,
    [string]$Domain = $env:AR_DOMAIN,
    [string]$Subdomain = $env:AR_SUBDOMAIN,
    [string]$IpVersion = $(if ($env:AR_IP_VERSION) { $env:AR_IP_VERSION } else { "4" }),
    [string]$Interface = $env:AR_INTERFACE,
    [string]$IsCreate = $(if ($env:AR_IS_CREATE_RECORD) { $env:AR_IS_CREATE_RECORD } else { "false" }),
    [string]$ScriptDir = $(if ($env:AR_SCRIPT_DIR) { $env:AR_SCRIPT_DIR } else { "$env:USERPROFILE\Documents\PowerShell\DDNS" }),
    [string]$ScriptUrl = $(if ($env:AR_SCRIPT_URL) { $env:AR_SCRIPT_URL } else { "https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1" })
)

if ($Help) {
    Write-Host "DNSPod Dynamic DNS Auto-Deployment Script"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\auto_install.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help               Show this help message"
    Write-Host "  -TaskName <string>  Name of the scheduled task (default: DdnsTask or env:AR_TASK_NAME)"
    Write-Host "  -Token <string>     DNSPod API token (default: env:AR_TOKEN)"
    Write-Host "  -Domain <string>    Target domain (default: env:AR_DOMAIN)"
    Write-Host "  -Subdomain <string> Target subdomain (default: env:AR_SUBDOMAIN)"
    Write-Host "  -IpVersion <string> IP version to use, 4 or 6 (default: 4 or env:AR_IP_VERSION)"
    Write-Host "  -Interface <string> Network interface to bind (default: env:AR_INTERFACE)"
    Write-Host "  -IsCreate <string>  Create record if not exists (default: false or env:AR_IS_CREATE_RECORD)"
    Write-Host "  -ScriptDir <string> Directory to store scripts (default: `$env:USERPROFILE\Documents\PowerShell\DDNS or env:AR_SCRIPT_DIR)"
    Write-Host "  -ScriptUrl <string> URL to download core script (default: GitHub URL or env:AR_SCRIPT_URL)"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\auto_install.ps1 -Token `"12345,7676f344eaeaea9074c123451234512d`" -Domain `"test.org`" -Subdomain `"subdomain`""
    return
}

function Exit-Install {
    param(
        [Int] $ErrorCode = 1
    )

    if ($IS_EXECUTED_FROM_IEX) {
        # Don't abort with `exit` that would close the PS session if invoked
        # with iex, yet set `LASTEXITCODE` for the caller to check
        $Global:LASTEXITCODE = $ErrorCode
        break
    } else {
        exit $ErrorCode
    }
}

function Test-IsAdministrator {
    return ([Security.Principal.WindowsPrincipal]`
            [Security.Principal.WindowsIdentity]::GetCurrent()`
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Prepare variables
$IS_EXECUTED_FROM_IEX = ($null -eq $MyInvocation.MyCommand.Path)

# Ensure TLS 1.2+ for Invoke-WebRequest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Check Administrator Privileges
if (-not (Test-IsAdministrator)) {
    Write-Host "[Error] Insufficient permissions, please run as Administrator!"
    Exit-Install
}

# Validate required parameters
if (-not $Token) {
    Write-Host "[Error] Missing required parameter: Token (or AR_TOKEN environment variable)"
    Exit-Install
}
if (-not $Domain) {
    Write-Host "[Error] Missing required parameter: Domain (or AR_DOMAIN environment variable)"
    Exit-Install
}
if (-not $Subdomain) {
    Write-Host "[Error] Missing required parameter: Subdomain (or AR_SUBDOMAIN environment variable)"
    Exit-Install
}

Write-Host "Preparing DNSPod Auto-Update Environment..."
Write-Host "================= Current Config ================="
Write-Host "Task Name:     $TaskName"
Write-Host "Auth Token:    $Token"
Write-Host "Domain:        $Domain"
Write-Host "Subdomain:     $Subdomain"
Write-Host "Target Host:   $Subdomain.$Domain"
Write-Host "IP Version:    $IpVersion"
Write-Host "Create Record: $IsCreate"
if ($Interface) {
    Write-Host "Interface:     $Interface"
} else {
    Write-Host "Interface:     [Not specified, using default]"
}
Write-Host "Script URL:    $ScriptUrl"
Write-Host "Script Dir:    $ScriptDir"
Write-Host "============================================"
Write-Host ""

# 1. Create directory
if (-not (Test-Path -Path $ScriptDir)) {
    New-Item -Path $ScriptDir -ItemType Directory -Force | Out-Null
}

# 2. Download core script ardnspod.ps1
Write-Host "Downloading core script ardnspod.ps1..."
Invoke-WebRequest -Uri $ScriptUrl -OutFile "$ScriptDir\ardnspod.ps1"

# 3. Generate scheduled execution script
Write-Host "Generating execution script $TaskName.ps1..."
$ExecutionScriptPath = Join-Path $ScriptDir "$TaskName.ps1"

$boolIsCreate = if ($IsCreate -eq 'true' -or $IsCreate -eq '1' -or $IsCreate -eq $true) { '$true' } else { '$false' }

$scriptContent = @"
Set-Location -Path (Split-Path -Parent `$MyInvocation.MyCommand.Path)
Start-Transcript -Path "$TaskName.log" -Append
. .\ardnspod.ps1
`$arToken = '$Token'
`$arIsCreateRecord = $boolIsCreate
arDdnsCheck '$Domain' '$Subdomain' '$IpVersion' '$Interface'
"@

$scriptContent | Set-Content -Path $ExecutionScriptPath -Encoding UTF8 -Force

# 4. Create scheduled task
Write-Host "Checking and cleaning up old scheduled tasks..."
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Found existing $TaskName, deleting..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "Creating new scheduled task $TaskName..."
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$TaskName.ps1`"" -WorkingDirectory $ScriptDir
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
} catch {
    Write-Host "==================================================="
    Write-Host "[Error] Failed to create scheduled task $TaskName, please check permissions or configuration!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "==================================================="
    Exit-Install
}

Write-Host "Starting task immediately for the first time..."
Start-ScheduledTask -TaskName $TaskName

Write-Host "Auto-deployment completed." -ForegroundColor Green
Write-Host "It will automatically run in the background every hour." -ForegroundColor Green
Write-Host "You can view the execution log at: $TaskName.log" -ForegroundColor Cyan
