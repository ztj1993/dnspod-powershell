$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "..\ardnspod.ps1")

Describe "ardnspod" {
    BeforeEach {
        $arErrCodeUnchanged = 99
        $arIsCreateRecord = $false
        $arLastRecordFile = Join-Path $TestDrive "ardnspod_last_record"
    }

    Context "arGetIpConfig" {
        It "returns IPv4 config by default" {
            $config = arGetIpConfig "4"

            $config.RecordType | Should Be "A"
            $config.AddressFamily | Should Be "IPv4"
            $config.QueryUrl | Should Be $arIp4QueryUrl
            $config.Pattern | Should Be '^[0-9\.]+$'
        }

        It "returns IPv6 config for version 6" {
            $config = arGetIpConfig "6"

            $config.RecordType | Should Be "AAAA"
            $config.AddressFamily | Should Be "IPv6"
            $config.QueryUrl | Should Be $arIp6QueryUrl
            $config.Pattern | Should Be '^[0-9a-fA-F:]+$'
        }
    }

    Context "arDdnsLookup" {
        It "passes subdomain filter and returns record id" {
            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = 1; message = "OK" }
                    records = [pscustomobject]@{ id = "42" }
                }
            } -ParameterFilter { $interface -eq "Record.List" -and $data -eq "domain=example.com&sub_domain=www&record_type=A" }

            $recordId = arDdnsLookup "example.com" "www" "A"

            $recordId | Should Be "42"
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter { $interface -eq "Record.List" -and $data -eq "domain=example.com&sub_domain=www&record_type=A" }
        }

        It "returns null when record is missing and auto-create is enabled" {
            $arIsCreateRecord = 1

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = 10; message = "No records on the list" }
                    records = [pscustomobject]@{ id = $null }
                }
            } -ParameterFilter { $interface -eq "Record.List" -and $data -eq "domain=example.com&sub_domain=missing&record_type=AAAA" }

            # Mock: arLog
            Mock arLog {}

            $recordId = arDdnsLookup "example.com" "missing" "AAAA"

            $recordId | Should Be $null
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter { $interface -eq "Record.List" -and $data -eq "domain=example.com&sub_domain=missing&record_type=AAAA" }
            Assert-MockCalled arLog -Times 0 -Exactly
        }
    }

    Context "arDdnsUpdate" {
        It "returns unchanged code without calling API when cached ip matches host ip" {
            $recordId = "123"
            $cacheFile = "$arLastRecordFile.$recordId"
            Set-Content -Path $cacheFile -Value "1.2.3.4"

            # Mock: arDdnsApi
            Mock arDdnsApi {}

            # Mock: arLog
            Mock arLog {}

            $result = arDdnsUpdate "example.com" "www" $recordId "A" "1.2.3.4"

            $result | Should Be 99
            Assert-MockCalled arDdnsApi -Times 0 -Exactly
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arDdnsUpdate - unchanged" }
        }

        It "updates record and refreshes cached ip when API returns a new value" {
            $recordId = "123"
            $cacheFile = "$arLastRecordFile.$recordId"
            Set-Content -Path $cacheFile -Value "1.2.3.4"

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = "1"; message = "OK" }
                    record = [pscustomobject]@{ value = "5.6.7.8" }
                }
            } -ParameterFilter {
                $interface -eq "Record.Ddns" -and
                $data -match "domain=example.com" -and
                $data -match "sub_domain=www" -and
                $data -match "record_id=123" -and
                $data -match "record_type=A" -and
                $data -match "value=5.6.7.8"
            }

            # Mock: arLog
            Mock arLog {}

            $result = arDdnsUpdate "example.com" "www" $recordId "A" "5.6.7.8"

            $result | Should Be $null
            (Get-Content $cacheFile) | Should Be "5.6.7.8"
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter {
                $interface -eq "Record.Ddns" -and
                $data -match "domain=example.com" -and
                $data -match "sub_domain=www" -and
                $data -match "record_id=123" -and
                $data -match "record_type=A" -and
                $data -match "value=5.6.7.8"
            }
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arDdnsUpdate - updated" }
        }

        It "loads last ip from Record.Info before updating when cache is missing" {
            $recordId = "456"
            $cacheFile = "$arLastRecordFile.$recordId"

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = "1"; message = "OK" }
                    record = [pscustomobject]@{ value = "1.2.3.4" }
                }
            } -ParameterFilter {
                $interface -eq "Record.Info" -and
                $data -eq "domain=example.com&record_id=456"
            }

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = "1"; message = "OK" }
                    record = [pscustomobject]@{ value = "5.6.7.8" }
                }
            } -ParameterFilter {
                $interface -eq "Record.Ddns" -and
                $data -match "domain=example.com" -and
                $data -match "sub_domain=www" -and
                $data -match "record_id=456" -and
                $data -match "record_type=A" -and
                $data -match "value=5.6.7.8"
            }

            # Mock: arLog
            Mock arLog {}

            $result = arDdnsUpdate "example.com" "www" $recordId "A" "5.6.7.8"

            $result | Should Be $null
            Test-Path $cacheFile | Should Be $true
            (Get-Content $cacheFile) | Should Be "5.6.7.8"
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter {
                $interface -eq "Record.Info" -and
                $data -eq "domain=example.com&record_id=456"
            }
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter {
                $interface -eq "Record.Ddns" -and
                $data -match "domain=example.com" -and
                $data -match "sub_domain=www" -and
                $data -match "record_id=456" -and
                $data -match "record_type=A" -and
                $data -match "value=5.6.7.8"
            }
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arDdnsUpdate - updated" }
        }

        It "returns unchanged when Record.Info already matches target ip" {
            $recordId = "654"

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = "1"; message = "OK" }
                    record = [pscustomobject]@{ value = "5.6.7.8" }
                }
            } -ParameterFilter {
                $interface -eq "Record.Info" -and
                $data -eq "domain=example.com&record_id=654"
            }

            # Mock: arDdnsApi
            Mock arDdnsApi {} -ParameterFilter {
                $interface -eq "Record.Ddns" -and
                $data -match "record_id=654"
            }

            # Mock: arLog
            Mock arLog {}

            $result = arDdnsUpdate "example.com" "www" $recordId "A" "5.6.7.8"

            $result | Should Be 99
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter {
                $interface -eq "Record.Info" -and
                $data -eq "domain=example.com&record_id=654"
            }
            Assert-MockCalled arDdnsApi -Times 0 -Exactly -ParameterFilter {
                $interface -eq "Record.Ddns" -and
                $data -match "record_id=654"
            }
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arDdnsUpdate - unchanged" }
        }
    }

    Context "arGetHostIp" {
        It "returns queried IPv4 when no interface is specified" {
            # Mock: arRequest
            Mock arRequest { "1.2.3.4" } -ParameterFilter { $url -eq $arIp4QueryUrl }

            $hostIp = arGetHostIp "4"

            $hostIp | Should Be "1.2.3.4"
            Assert-MockCalled arRequest -Times 1 -Exactly -ParameterFilter { $url -eq $arIp4QueryUrl }
        }

        It "returns the first non-link-local IPv6 address from the interface" {
            # Mock: Get-NetAdapter
            Mock Get-NetAdapter { [pscustomobject]@{ Name = "Ethernet" } } -ParameterFilter { $Name -eq "Ethernet" }

            # Mock: Get-NetIPAddress
            Mock Get-NetIPAddress {
                @(
                    [pscustomobject]@{ IPAddress = "fe80::1" }
                    [pscustomobject]@{ IPAddress = "2001:db8::10" }
                )
            } -ParameterFilter { $InterfaceAlias -eq "Ethernet" -and $AddressFamily -eq "IPv6" }

            $hostIp = arGetHostIp "6" "Ethernet"

            $hostIp | Should Be "2001:db8::10"
            Assert-MockCalled Get-NetAdapter -Times 1 -Exactly -ParameterFilter { $Name -eq "Ethernet" }
            Assert-MockCalled Get-NetIPAddress -Times 1 -Exactly -ParameterFilter { $InterfaceAlias -eq "Ethernet" -and $AddressFamily -eq "IPv6" }
        }

        It "returns null when public IP query returns nothing" {
            # Mock: arRequest
            Mock arRequest { $null } -ParameterFilter { $url -eq $arIp4QueryUrl }

            # Mock: arLog
            Mock arLog {}

            $hostIp = arGetHostIp "4"

            $hostIp | Should Be $null
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arGetHostIp - Can't get ip address, fallback to auto" }
        }
    }

    Context "arDdnsCheck" {
        It "creates a record when lookup returns nothing and then updates it" {
            # Mock: arLog
            Mock arLog {}

            # Mock: arGetIpConfig
            Mock arGetIpConfig { @{ RecordType = "A" } }

            # Mock: arGetHostIp
            Mock arGetHostIp { "5.6.7.8" }

            # Mock: arDdnsLookup
            Mock arDdnsLookup { $null }

            # Mock: arDdnsCreate
            Mock arDdnsCreate { "789" }

            # Mock: arDdnsUpdate
            Mock arDdnsUpdate {}

            arDdnsCheck "example.com" "www" "4"

            Assert-MockCalled arGetIpConfig -Times 1 -ParameterFilter { $ipVersion -eq "4" }
            Assert-MockCalled arGetHostIp -Times 1 -ParameterFilter { $ipVersion -eq "4" }
            Assert-MockCalled arDdnsLookup -Times 1 -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "A" }
            Assert-MockCalled arDdnsCreate -Times 1 -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "A" -and $hostIp -eq "5.6.7.8" }
            Assert-MockCalled arDdnsUpdate -Times 1 -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordId -eq "789" -and $recordType -eq "A" -and $hostIp -eq "5.6.7.8" }
        }

        It "updates an existing record without creating a new one" {
            # Mock: arLog
            Mock arLog {}

            # Mock: arGetIpConfig
            Mock arGetIpConfig { @{ RecordType = "A" } }

            # Mock: arGetHostIp
            Mock arGetHostIp { "9.8.7.6" }

            # Mock: arDdnsLookup
            Mock arDdnsLookup { "555" } -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "A" }

            # Mock: arDdnsCreate
            Mock arDdnsCreate {} -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "A" -and $hostIp -eq "9.8.7.6" }

            # Mock: arDdnsUpdate
            Mock arDdnsUpdate {} -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordId -eq "555" -and $recordType -eq "A" -and $hostIp -eq "9.8.7.6" }

            arDdnsCheck "example.com" "www" "4"

            Assert-MockCalled arDdnsLookup -Times 1 -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "A" }
            Assert-MockCalled arDdnsCreate -Times 0 -Exactly -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "A" -and $hostIp -eq "9.8.7.6" }
            Assert-MockCalled arDdnsUpdate -Times 1 -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordId -eq "555" -and $recordType -eq "A" -and $hostIp -eq "9.8.7.6" }
        }
    }

    Context "arDdnsDelete" {
        It "deletes the resolved IPv4 record" {
            # Mock: arLog
            Mock arLog {}

            # Mock: arDdnsLookup
            Mock arDdnsLookup { "123" } -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "home" -and $recordType -eq "A" }

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = 1; message = "OK" }
                }
            } -ParameterFilter { $interface -eq "Record.Remove" -and $data -eq "domain=example.com&record_id=123" }

            arDdnsDelete "example.com" "home" "4"

            Assert-MockCalled arDdnsLookup -Times 1 -Exactly -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "home" -and $recordType -eq "A" }
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter { $interface -eq "Record.Remove" -and $data -eq "domain=example.com&record_id=123" }
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arDdnsDelete - successful" }
        }

        It "deletes the resolved IPv6 record" {
            # Mock: arLog
            Mock arLog {}

            # Mock: arDdnsLookup
            Mock arDdnsLookup { "321" } -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "AAAA" }

            # Mock: arDdnsApi
            Mock arDdnsApi {
                [pscustomobject]@{
                    status = [pscustomobject]@{ code = 1; message = "OK" }
                }
            } -ParameterFilter { $interface -eq "Record.Remove" -and $data -eq "domain=example.com&record_id=321" }

            arDdnsDelete "example.com" "www" "6"

            Assert-MockCalled arDdnsLookup -Times 1 -Exactly -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "www" -and $recordType -eq "AAAA" }
            Assert-MockCalled arDdnsApi -Times 1 -Exactly -ParameterFilter { $interface -eq "Record.Remove" -and $data -eq "domain=example.com&record_id=321" }
            Assert-MockCalled arLog -Times 1 -ParameterFilter { $Message -eq "> arDdnsDelete - successful" }
        }

        It "stops before delete API when no record is found" {
            # Mock: arDdnsLookup
            Mock arDdnsLookup { $null } -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "missing" -and $recordType -eq "A" }

            # Mock: arDdnsApi
            Mock arDdnsApi {} -ParameterFilter { $interface -eq "Record.Remove" -and $data -eq "domain=example.com&record_id=" }

            # Mock: arLog
            Mock arLog {
                param($Message, $ErrorCode)

                if ($ErrorCode -ne $null) {
                    throw "arLogExit:$ErrorCode"
                }
            }

            { arDdnsDelete "example.com" "missing" "4" } | Should Throw "arLogExit:0"

            Assert-MockCalled arDdnsLookup -Times 1 -Exactly -ParameterFilter { $domain -eq "example.com" -and $subdomain -eq "missing" -and $recordType -eq "A" }
            Assert-MockCalled arDdnsApi -Times 0 -Exactly -ParameterFilter { $interface -eq "Record.Remove" -and $data -eq "domain=example.com&record_id=" }
        }
    }
}
