#
# PowerShell AnripDdns v1.0.0
#
# Dynamic DNS using DNSPod API
#
# Author: Ztj, https://github.com/ztj1993
#
# Reference: Rehiy, https://github.com/rehiy
#                   https://www.rehiy.com/?s=dnspod
#
#
# Usage: please refer to `ddnspod.ps1`
#

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$arToken = $env:arToken

# The url to be used for querying public ip address.
$arIp4QueryUrl = "http://ipv4.rehi.org/ip"
$arIp6QueryUrl = "http://ipv6.rehi.org/ip"

# The temp file to store the last record ip
$arLastRecordFile = Join-Path $env:TEMP "ardnspod_last_record"

# The error code to return when a ddns record is not changed
# By default, report unchanged event as success
$arErrCodeUnchanged = $null

# indicates whether a new domain record should be created
# if the record does not already exist. It is set to 1 (true) if a new record should be created
# when the domain record is missing, and 0 (false) otherwise.
$arIsCreateRecord = $false

# Output log to stderr
function arLog {
    param (
        [string]$message
    )
    Write-Host $message
}

# Use Invoke-WebRequest to open url
# Args: url postdata
function arRequest {
    param (
        [string]$url,
        [string]$data
    )

    $params = @{
        Uri = $url
    }

    if ($data) {
        $params["Method"] = "POST"
        $params["Body"] = $data
    } else {
        $params["Method"] = "GET"
    }

    try {
        $response = Invoke-WebRequest @params -UseBasicParsing
        return $response.Content.Trim()
    } catch {
        arLog "> arRequest - Error: $_"
        return $false
    }
}

# Get IPv4 by ip route or network
function arWanIp4 {
    $hostIp = arRequest $arIp4QueryUrl

    if (-not $hostIp) {
        arLog "> arWanIp4 - Can't get ip address"
        return $true
    }

    if ($hostIp -notmatch '^[0-9\.]+$') {
        arLog "> arWanIp4 - Invalid ip address"
        return $false
    }

    return $hostIp
}

# Get IPv4 from a specific interface
# Args: interface
function arDevIp4 {
    param (
        [string]$interface
    )

    $adapter = Get-NetAdapter -Name $interface -ErrorAction SilentlyContinue
    if (-not($adapter)) {
        arLog "> arDevIp4 - Can't get network adapter interface"
        return $false
    }

    $hostIp = Get-NetIPAddress -InterfaceAlias $interface -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress

    if (-not $hostIp) {
        arLog "> arDevIp4 - Can't get ip address"
        return $false
    }

    if ($hostIp -notmatch '^[0-9\.]+$') {
        arLog "> arDevIp4 - Invalid ip address"
        return $false
    }

    return $hostIp
}

# Get IPv6 by ip route or network
function arWanIp6 {
    $hostIp = arRequest $arIp6QueryUrl

    if (-not $hostIp) {
        arLog "> arWanIp6 - Can't get ip address"
        return $true
    }

    if ($hostIp -notmatch '^[0-9a-fA-F:]+$') {
        arLog "> arWanIp6 - Invalid ip address"
        return $false
    }

    return $hostIp
}

# Get IPv6 from a specific interface
# Args: interface
function arDevIp6 {
    param (
        [string]$interface
    )

    $adapter = Get-NetAdapter -Name $interface -ErrorAction SilentlyContinue
    if (-not($adapter)) {
        arLog "> arDevIp6 - Can't get network adapter interface"
        return $false
    }

    $hostIp = Get-NetIPAddress -InterfaceAlias $interface -AddressFamily IPv6 | Select-Object -ExpandProperty IPAddress

    if (-not $hostIp) {
        arLog "> arDevIp6 - Can't get ip address"
        return $false
    }

    if ($hostIp -notmatch '^[0-9a-fA-F:]+$') {
        arLog "> arDevIp6 - Invalid ip address"
        return $false
    }

    return $hostIp
}

# Dnspod Bridge
# Args: interface data
function arDdnsApi {
    param (
        [string]$interface,
        [string]$data
    )

    $dnsapi = "https://dnsapi.cn/$interface"
    $params = "login_token=$arToken&format=json&lang=en&$data"

    try {
        $body = arRequest $dnsapi $params
        if (-not $body) {
            throw "response body is empey"
        }
        $json = $body | ConvertFrom-Json
        if ($json.PSObject.Properties['code']) {
            if ($json.code -eq 10004) {
                throw $json.message
            }
        }
        return $json
    } catch {
        arLog "> arDdnsApi - Error: $_"
        return $false
    }
}

# Fetch Record Id
# Args: domain subdomain recordType
function arDdnsLookup {
    param (
        [string]$domain,
        [string]$subdomain,
        [string]$recordType
    )

    $subDomainRule = ""
    if ($subdomain -ne "@") {
        $subDomainRule = "&sub_domain=$subdomain"
    }

    # Get Record Id
    $resp = arDdnsApi "Record.List" "domain=$domain$subDomainRule&record_type=$recordType"
    if ($resp.status.code -ne 1) {
        $errMsg = $resp.status.message
        arLog "> arDdnsLookup - Error: $errMsg"
        if ($arIsCreateRecord -eq 1) {
            if ($errMsg -eq "No records on the list") {
                return $true
            }
        }
        return $false
    }

    return $resp.records.id
}

# Update Record Value
# Args: domain subdomain recordId recordType [hostIp]
function arDdnsUpdate {
    param (
        [string]$domain,
        [string]$subdomain,
        [string]$recordId,
        [string]$recordType,
        [string]$hostIp = $null
    )

    $lastRecordIpFile = "$arLastRecordFile.$recordId"

    # fetch last ip
    $lastRecordIp = $null
    if (Test-Path $lastRecordIpFile) {
        $lastRecordIp = Get-Content $lastRecordIpFile
    }

    # fetch from api
    if (-not $lastRecordIp) {
        $recordResp = arDdnsApi "Record.Info" "domain=$domain&record_id=$recordId"
        $recordCode = $recordResp.status.code
        $lastRecordIp = $recordResp.record.value
    }

    # update ip
    $value=""
    if ($hostIp) {
        if ($hostIp -eq $lastRecordIp) {
            arLog "> arDdnsUpdate - unchanged" # unchanged event
            return $arErrCodeUnchanged
        }
        $value="&value=$hostIp"
    }
    $recordResp = arDdnsApi "Record.Ddns" "domain=$domain&sub_domain=$subdomain&record_id=$recordId&record_type=$recordType$value&record_line=%e9%bb%98%e8%ae%a4"

    # parse result
    $recordCode = $recordResp.status.code
    $recordIp = $recordResp.record.value

    # check result
    if ($recordCode -ne "1") {
        $errMsg = $recordResp.status.message
        arLog "> arDdnsUpdate - error: $errMsg"
        return $false
    } elseif ($recordIp -eq $lastRecordIp) {
        arLog "> arDdnsUpdate - unchanged" # unchanged event
        return $arErrCodeUnchanged
    } else {
        arLog "> arDdnsUpdate - updated" # updated event
        if ($lastRecordIpFile) {
            Set-Content -Path $lastRecordIpFile -Value $recordIp
        }
    }
}

# DDNS Check
# Args: domain subdomain [6|4] interface
function arDdnsCheck {
    param (
        [string]$domain,
        [string]$subdomain,
        [string]$ipVersion,
        [string]$interface = $null
    )

    arLog "=== Check $subdomain.$domain ==="
    arLog "Fetching Host Ip"

    if ($ipVersion -eq "6" -and $interface) {
        $recordType = "AAAA"
        $hostIp = arDevIp6 $interface
    } elseif ($ipVersion -eq "4" -and $interface) {
        $recordType = "A"
        $hostIp = arDevIp4 $interface
    } elseif ($ipVersion -eq "6") {
        $recordType = "AAAA"
        $hostIp = arWanIp6
    } else {
        $recordType = "A"
        $hostIp = arWanIp4
    }

    if ($hostIp -eq $false) {
        exit 20
        return $false
    } elseif ($hostIp -eq $true) {
        arLog "> Host Ip: Auto"
        arLog "> Record Type: $recordType"
    } else {
        arLog "> Host Ip: $hostIp"
        arLog "> Record Type: $recordType"
    }

    arLog "Fetching RecordId"
    $recordId = arDdnsLookup $domain $subdomain $recordType

    if ($recordId -eq $false) {
        return $false
    } elseif ($recordId -eq $true) {
        arLog "Creating Record value"
        $recordId = arDdnsCreate $domain $subdomain $recordType $hostIp
        if ($recordId -eq $false) {
            return $false
        }
        arLog "> Record Id: $recordId"
    } else {
        arLog "> Record Id: $recordId"
    }

    arLog "Updating Record value"
    arDdnsUpdate $domain $subdomain $recordId $recordType $hostIp
}

# Create Record
# Args: domain subdomain recordType hostIp
function arDdnsCreate {
    param (
        [string]$domain,
        [string]$subdomain,
        [string]$recordType,
        [string]$hostIp
    )

    # create record
    $resp = arDdnsApi "Record.Create" "domain=$domain&sub_domain=$subdomain&record_type=$recordType&value=$hostIp&record_line=%e9%bb%98%e8%ae%a4"

    # parse result
    $recordCode = $resp.status.code
    if ($recordCode -ne 1) {
        $errMsg = $resp.status.message
        arLog "> arDdnsCreate - error: $errMsg"
        return $false
    }

    arLog "> arDdnsCreate - created"
    return $resp.record.id
}

# Delete Record
# Args: domain subdomain recordType
function arDdnsDelete {
    param (
        [string]$domain,
        [string]$subdomain,
        [string]$ipVersion
    )

    arLog "=== Delete $subdomain.$domain ==="

    if ($ipVersion -eq "6") {
        $recordType = "AAAA"
    } else {
        $recordType = "A"
    }

    arLog "> Record Type: $recordType"

    arLog "Fetching RecordId"
    $recordId = arDdnsLookup $domain $subdomain $recordType
    if ($recordId -is [bool]) {
        return $null
    } else {
        arLog "> Record Id: $recordId"
    }

    arLog "Deleting Record"
    $resp = arDdnsApi "Record.Remove" "domain=$domain&record_id=$recordId"

    # parse result
    $recordCode = $resp.status.code
    if ($recordCode -ne 1) {
        $errMsg = $resp.status.message
        arLog "> arDdnsDelete - error: $errMsg"
        return $false
    }

    arLog "> arDdnsDelete - successful"
}
