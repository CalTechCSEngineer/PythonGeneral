function Connect-CtIdentityConditionalAccess {
    Connect-MgGraph "Application.Read.All,Directory.Read.All,Group.Read.All,Policy.Read.All,Policy.ReadWrite.ConditionalAccess"
    Select-MgProfile "v1.0"
}

function Remove-CtIdentityConditionalAccessNamedLocation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $namedLocation = Get-MgIdentityConditionalAccessNamedLocation -Filter "DisplayName eq '$Name'"
        if ($null -eq $namedLocation) {
            Write-Host "Skipped named location $Name because it does not exist."
        } else {
            Remove-MgIdentityConditionalAccessNamedLocation -NamedLocationId $namedLocation.Id
            Write-Host "Removed named location $Name."
        }
    }
}

function Remove-CtIdentityConditionalAccessPolicy {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $policy = Get-MgIdentityConditionalAccessPolicy -Filter "DisplayName eq '$Name'"
        if ($null -eq $policy) {
            Write-Host "Skipped policy $Name because it does not exist."
        } else {
            Remove-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id
            Write-Host "Removed policy $Name."
        }
    }
}

function Set-CtIdentityConditionalAccessNamedLocationByCountry {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $namedLocation = Get-MgIdentityConditionalAccessNamedLocation -Filter "DisplayName eq '$Name'"
        if ($null -eq $namedLocation) {
            $body = @{
                "@odata.type" = "#microsoft.graph.countryNamedLocation";
                "displayName" = $Name;
                "countriesAndRegions" = @("CA", "MX", "US");
                "includeUnknownCountriesAndRegions" = $false;
            } | ConvertTo-Json
            $namedLocation = New-MgIdentityConditionalAccessNamedLocation -BodyParameter $body
            Write-Host "Created named location $Name."
        } else {
            Write-Host "Skipped named location $Name because it already exists."
        }

        return $namedLocation
    }
}

function Set-CtIdentityConditionalAccessNamedLocationByIp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string[]] $Ips
    )

    Process {
        $namedLocation = Get-MgIdentityConditionalAccessNamedLocation -Filter "DisplayName eq '$Name'"
        if ($null -eq $namedLocation) {
            $body = @{
                "@odata.type" = "#microsoft.graph.ipNamedLocation";
                "displayName" = $Name;
                "isTrusted" = $true;
                "ipRanges" = @($ips | ForEach-Object { Select-Object
                    @{
                        "@odata.type" = "#microsoft.graph.iPv4CidrRange";
                        "cidrAddress" = $_;
                    }
                });
            } | ConvertTo-Json
            $namedLocation = New-MgIdentityConditionalAccessNamedLocation -BodyParameter $body
            Write-Host "Created named location $Name."
        } else {
            Write-Host "Skipped named location $Name because it already exists."
        }

        return $namedLocation
    }
}

function Set-CtIdentityConditionalAccessPolicy {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $Name,
        [Parameter(Mandatory = $true, Position = 1)] [string[]] $ClientAppTypes,
        [Parameter(Mandatory = $false)] [string[]] $IncludeApplications = @("all"),
        [Parameter(Mandatory = $false)] [string[]] $ExcludeApplications = $null,
        [Parameter(Mandatory = $false)] [string[]] $IncludeGroups = $null,
        [Parameter(Mandatory = $false)] [string[]] $ExcludeGroups = $null,
        [Parameter(Mandatory = $false)] [string[]] $IncludeLocations = $null,
        [Parameter(Mandatory = $false)] [string[]] $ExcludeLocations = $null,
        [Parameter(Mandatory = $false)] [string[]] $IncludePlatforms = $null,
        [Parameter(Mandatory = $false)] [string[]] $ExcludePlatforms = $null,
        [Parameter(Mandatory = $false)] [string[]] $IncludeRoles = $null,
        [Parameter(Mandatory = $false)] [string[]] $ExcludeRoles = $null,
        [Parameter(Mandatory = $false)] [string[]] $IncludeUsers = @("all"),
        [Parameter(Mandatory = $false)] [string[]] $ExcludeUsers = $null,
        [Parameter(Mandatory = $false)] [string[]] $BuiltInControls = @("block"),
        [Parameter(Mandatory = $false)] [string] $Operator = "OR"
    )

    Process {
        $policy = Get-MgIdentityConditionalAccessPolicy -Filter "DisplayName eq '$Name'"
        if ($null -eq $policy) {
            if ($null -ne $IncludeGroups) {
                $IncludeUsers = $null
            }

            $body = @{
                "displayName" = $Name;
                "state" = "enabledForReportingButNotEnforced";
                "conditions" = @{
                    "applications" = @{
                        "includeApplications" = $IncludeApplications;
                        "excludeApplications" = $ExcludeApplications;
                    };
                    "clientAppTypes" = $ClientAppTypes;
                    "locations" = @{
                        "includeLocations" = @("all");
                        "excludeLocations" = $ExcludeLocations;
                    };
                    "platforms" = @{ 
                        "includePlatforms" = $IncludePlatforms;
                        "excludePlatforms" = $ExcludePlatforms;
                    };
                    "users" = @{
                        "includeGroups" = $IncludeGroups;
                        "includeRoles" = $IncludeRoles;
                        "includeUsers" = $IncludeUsers;
                        "excludeGroups" = $ExcludeGroups;
                        "excludeRoles" = $ExcludeRoles;
                        "excludeUsers" = $ExcludeUsers;
                    };
                };
                "grantControls" = @{
                    "operator" = $Operator;
                    "builtInControls" = $BuiltInControls;
                };
            } | ConvertTo-Json -Depth 3
            New-MgIdentityConditionalAccessPolicy -BodyParameter $body | Out-Null
            Write-Host "Created policy $Name."
        } else {
            Write-Host "Skipped policy $Name because it already exists."
        }
    }
}

function Test-CtIdentityConditionalAccessNamedLocation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $namedLocation = Get-MgIdentityConditionalAccessNamedLocation -Filter "DisplayName eq '$Name'"
        if ($null -eq $namedLocation) {
            Write-Host "Missing named location $Name."
        } else {
            Write-Host "Found named location $Name."
        }
    }
}

function Test-CtIdentityConditionalAccessPolicy {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $policy = Get-MgIdentityConditionalAccessPolicy -Filter "DisplayName eq '$Name'"
        if ($null -eq $policy) {
            Write-Host "Missing policy $Name."
        } else {
            Write-Host "Found policy $Name."
        }
    }
}