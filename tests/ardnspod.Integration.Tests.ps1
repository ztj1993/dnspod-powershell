$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "..\ardnspod.ps1")

function Get-IntegrationConfig {
    $token = $env:AR_TOKEN
    $domain = $env:AR_DOMAIN
    $subdomain = $env:AR_SUBDOMAIN

    if (-not $token -or -not $domain -or -not $subdomain) {
        Set-TestInconclusive "Set AR_TOKEN, AR_DOMAIN and AR_SUBDOMAIN before running integration tests."
    }

    return @{
        Token = $token
        Domain = $domain
        Subdomain = $subdomain
    }
}

function Find-Record {
    param(
        [string]$Domain,
        [string]$Subdomain,
        [string]$RecordType = "A"
    )

    $response = arDdnsApi "Record.List" "domain=$Domain&sub_domain=$Subdomain&record_type=$RecordType"

    if (-not $response -or -not $response.status) {
        return $null
    }

    if ($response.status.code -ne "1" -or -not $response.records) {
        return $null
    }

    return @($response.records)[0]
}

function Remove-RecordIfExists {
    param(
        [string]$Domain,
        [string]$Subdomain,
        [string]$RecordType = "A"
    )

    $record = Find-Record $Domain $Subdomain $RecordType
    if ($record -and $record.id) {
        $response = arDdnsApi "Record.Remove" "domain=$Domain&record_id=$($record.id)"
        $response.status.code | Should Be "1"
    }
}

Describe "ardnspod integration" {
    BeforeEach {
        $config = Get-IntegrationConfig
        $script:arToken = $config.Token
        $script:arIsCreateRecord = 1
        $script:arLastRecordFile = Join-Path $TestDrive "ardnspod_last_record"
    }

    It "runs the full A-record lifecycle: lookup, create, info, update and delete" {
        $config = Get-IntegrationConfig
        $subdomain = ("{0}-int-{1}" -f $config.Subdomain, [System.Guid]::NewGuid().ToString("N").Substring(0, 8)).ToLower()
        $initialIp = "198.51.100.10"
        $updatedIp = "198.51.100.11"

        try {
            Remove-RecordIfExists $config.Domain $subdomain "A"

            $missingRecord = Find-Record $config.Domain $subdomain "A"
            $missingRecord | Should Be $null

            $createdRecordId = arDdnsCreate $config.Domain $subdomain "A" $initialIp
            $createdRecordId | Should Not BeNullOrEmpty

            $lookupRecordId = arDdnsLookup $config.Domain $subdomain "A"
            $lookupRecordId.ToString() | Should Be $createdRecordId.ToString()

            $info = arDdnsApi "Record.Info" "domain=$($config.Domain)&record_id=$createdRecordId"
            $infoSubdomain = $null
            $infoRecordType = $null
            if ($info.record.PSObject.Properties['sub_domain']) {
                $infoSubdomain = $info.record.sub_domain
            } elseif ($info.record.PSObject.Properties['name']) {
                $infoSubdomain = $info.record.name
            }

            if ($info.record.PSObject.Properties['record_type']) {
                $infoRecordType = $info.record.record_type
            } elseif ($info.record.PSObject.Properties['type']) {
                $infoRecordType = $info.record.type
            }

            $info.status.code | Should Be "1"
            $info.record.id.ToString() | Should Be $createdRecordId.ToString()
            $infoSubdomain | Should Be $subdomain
            $infoRecordType | Should Be "A"
            $info.record.value | Should Be $initialIp

            arDdnsUpdate $config.Domain $subdomain $createdRecordId "A" $updatedIp

            $updatedInfo = arDdnsApi "Record.Info" "domain=$($config.Domain)&record_id=$createdRecordId"
            $updatedInfo.status.code | Should Be "1"
            $updatedInfo.record.value | Should Be $updatedIp

            arDdnsDelete $config.Domain $subdomain "4"

            $deletedRecord = Find-Record $config.Domain $subdomain "A"
            $deletedRecord | Should Be $null
        } finally {
            Remove-RecordIfExists $config.Domain $subdomain "A"
        }
    }
}
