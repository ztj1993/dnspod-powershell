@echo off

:: ============================================================================
:: DNSPod Dynamic DNS Auto-Deployment Script
:: 
:: Features:
:: 1. Automatically creates working directory at %USERPROFILE%\Documents\PowerShell\DDNS
:: 2. Downloads the latest ardnspod.ps1 core script from GitHub
:: 3. Generates execution script DdnsTask.ps1 based on environment variables or defaults
:: 4. Automatically creates a Windows Scheduled Task for silent hourly background execution
:: ============================================================================

:: Check Administrator Privileges
net session >nul 2>&1
if %errorlevel% neq 0 goto :RequireAdmin

:: Parse input parameter as task name, default to DdnsTask if not provided
if /i "%~1"=="-Help" goto :ShowHelp
if /i "%~1"=="--help" goto :ShowHelp
if /i "%~1"=="/?" goto :ShowHelp
if /i "%~1"=="-h" goto :ShowHelp

set TASK_NAME=%~1
if "%TASK_NAME%"=="" set TASK_NAME=DdnsTask

:: ================= Configuration Area =================
:: Check if required environment variables are set
if not defined AR_TOKEN (
    echo [Error] Missing required environment variable: AR_TOKEN
    echo Please set the environment variable first, e.g.: set AR_TOKEN=12345,7676f344eaeaea9074c123451234512d
    exit /b 1
)

if not defined AR_DOMAIN (
    echo [Error] Missing required environment variable: AR_DOMAIN
    echo Please set the environment variable first, e.g.: set AR_DOMAIN=test.org
    exit /b 1
)

if not defined AR_SUBDOMAIN (
    echo [Error] Missing required environment variable: AR_SUBDOMAIN
    echo Please set the environment variable first, e.g.: set AR_SUBDOMAIN=subdomain
    exit /b 1
)

:: Optional environment variables (use default values if not set)
if not defined AR_IP_VERSION set AR_IP_VERSION=4
if not defined AR_INTERFACE set AR_INTERFACE=
if not defined AR_IS_CREATE_RECORD set AR_IS_CREATE_RECORD=false
if not defined AR_SCRIPT_DIR set AR_SCRIPT_DIR=%USERPROFILE%\Documents\PowerShell\DDNS

:: Core script download URL
if not defined AR_SCRIPT_URL set AR_SCRIPT_URL=https://raw.githubusercontent.com/ztj1993/dnspod-powershell/refs/heads/main/ardnspod.ps1

:: ============================================

echo Preparing DNSPod Auto-Update Environment...
echo ================= Current Config =================
echo Task Name:     %TASK_NAME%
echo Auth Token:    %AR_TOKEN%
echo Domain:        %AR_DOMAIN%
echo Subdomain:     %AR_SUBDOMAIN%
echo Target Host:   %AR_SUBDOMAIN%.%AR_DOMAIN%
echo IP Version:    %AR_IP_VERSION%
echo Create Record: %AR_IS_CREATE_RECORD%
if defined AR_INTERFACE (
    echo Interface:     %AR_INTERFACE%
) else (
    echo Interface:     [Not specified, using default]
)
echo Script URL:    %AR_SCRIPT_URL%
echo Script Dir:    %AR_SCRIPT_DIR%
echo ============================================
echo.

:: 1. Create directory
call :RunPowerShell "if (!(Test-Path -Path '%AR_SCRIPT_DIR%')) { New-Item -Path '%AR_SCRIPT_DIR%' -ItemType Directory -Force | Out-Null }"

:: 2. Download core script ardnspod.ps1
echo Downloading core script ardnspod.ps1...
call :RunPowerShell "Invoke-WebRequest -Uri '%AR_SCRIPT_URL%' -OutFile '%AR_SCRIPT_DIR%\ardnspod.ps1'"

:: 3. Generate scheduled execution script
echo Generating execution script %TASK_NAME%.ps1...
if exist "%AR_SCRIPT_DIR%\%TASK_NAME%.ps1" del /f /q "%AR_SCRIPT_DIR%\%TASK_NAME%.ps1"
call :AppendScript "Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)"
call :AppendScript "Start-Transcript -Path %TASK_NAME%.log -Append"
call :AppendScript ". .\ardnspod.ps1"
call :AppendScript "$arToken = '%AR_TOKEN%'"
call :AppendScript "$arIsCreateRecord = $%AR_IS_CREATE_RECORD%"
call :AppendScript "arDdnsCheck '%AR_DOMAIN%' '%AR_SUBDOMAIN%' '%AR_IP_VERSION%' '%AR_INTERFACE%'"

:: 4. Create scheduled task
echo Checking and cleaning up old scheduled tasks...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo Found existing %TASK_NAME%, deleting...
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

echo Creating new scheduled task %TASK_NAME%...
set SCRIPT_PATH=%AR_SCRIPT_DIR%\%TASK_NAME%.ps1
set TASK_CMD=powershell.exe -NoProfile -ExecutionPolicy Bypass -File %SCRIPT_PATH%
echo %TASK_CMD%

schtasks /create /sc hourly /tn "%TASK_NAME%" /tr "%TASK_CMD%" /ru SYSTEM /f >nul 2>&1

if %errorlevel% neq 0 (
    echo ===================================================
    echo [Error] Failed to create scheduled task %TASK_NAME%, please check permissions or configuration!
    echo ===================================================
    exit /b 1
)

echo Starting task immediately for the first time...
schtasks /run /tn "%TASK_NAME%" >nul 2>&1

echo.
echo Auto-deployment completed.
echo It will automatically run in the background every hour.
echo You can view the execution log at: %TASK_NAME%.log
exit /b 0

:: ================= Function Area =================
:ShowHelp
echo DNSPod Dynamic DNS Auto-Deployment Script
echo.
echo Usage:
echo   auto_install.bat [TaskName]
echo.
echo Options:
echo   TaskName           Name of the scheduled task (default: DdnsTask)
echo   -Help, -h, /?      Show this help message
echo.
echo Note: Other parameters are read from environment variables (AR_TOKEN, AR_DOMAIN, AR_SUBDOMAIN, etc.)
echo.
echo Example:
echo   set AR_TOKEN=12345,7676f344eaeaea9074c123451234512d
echo   set AR_DOMAIN=test.org
echo   set AR_SUBDOMAIN=subdomain
echo   set AR_IP_VERSION=6
echo   set AR_INTERFACE=eth0
echo   set AR_IS_CREATE_RECORD=true
echo   set AR_SCRIPT_URL=https://your-custom-url.com/ardnspod.ps1
echo   auto_install.bat MyDdnsTask
exit /b 0

:RequireAdmin
echo ===================================================
echo [Error] Insufficient permissions, please run as Administrator!
echo ===================================================
exit /b 1

:RunPowerShell
:: Receive input string as command and execute via PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command %1
exit /b 0

:AppendScript
:: Receive input string and append it line by line to the execution script
:: Use environment variables to pass content, avoiding special characters and quote escaping issues
set "TEMP_LINE=%~1"
call :RunPowerShell "Add-Content -Path \"$env:AR_SCRIPT_DIR\$env:TASK_NAME.ps1\" -Value $env:TEMP_LINE -Encoding UTF8"
set "TEMP_LINE="
exit /b 0
