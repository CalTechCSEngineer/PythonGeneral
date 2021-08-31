Param ([Parameter(Mandatory = $true)] [string[]] $onPremIps)
Import-Module $PSScriptRoot\CtIdentityConditionalAccess.psm1 -Force
Connect-CtIdentityConditionalAccess
$allowedCountriesNamedLocation = Set-CtIdentityConditionalAccessNamedLocationByCountry `
    -Name "AllowedCountries"
$calTechNamedLocation = Set-CtIdentityConditionalAccessNamedLocationByIp `
    -Name "CalTech" `
    -Ips @(
        "216.117.31.19/32",
        "104.54.182.145/32",
        "97.77.191.178/32",
        "208.180.214.21/32",
        "50.240.224.155/32",
        "96.94.164.245/32",
        "65.26.45.62/32",
        "66.76.155.194/32"
    )
$onPremNamedLocation = Set-CtIdentityConditionalAccessNamedLocationByIp `
    -Name "OnPrem" `
    -Ips $onPremIps
$skyKickNamedLocation = Set-CtIdentityConditionalAccessNamedLocationByIp `
    -Name "SkyKick" `
    -Ips @("40.64.81.98/32")
Set-CtIdentityConditionalAccessPolicy `
    -Name "Default Block" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -ExcludeLocations @(
        $allowedCountriesNamedLocation.Id,
        $calTechNamedLocation.Id,
        $onPremNamedLocation.Id,
        $skyKickNamedLocation.Id)
$exchangeOnlineServicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'Office 365 Exchange Online'"
$skyKickServicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'SkyKick Cloud Manager'"
$intuneServicePrincipalId = "d4ebce55-015a-49b5-a083-c84d1797ae8c"
$intuneenrollmentServicePrincipalId = "0000000a-0000-0000-c000-000000000000"
$adminRoleIds = Get-MgDirectoryRoleTemplate -Property Id,DisplayName `
    | Where-Object { ($_.DisplayName -notcontains ("Windows Update Deployment Administrator")) -and ($_.DisplayName.Contains("Admin")) } `
    | ForEach-Object { $_.Id }
Set-CtIdentityConditionalAccessPolicy `
    -Name "Admin Access" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -ExcludeApplications @($exchangeOnlineServicePrincipal.AppId, $skyKickServicePrincipal.AppId) `
    -ExcludeLocations @(
        $calTechNamedLocation.Id,
        $onPremNamedLocation.Id,
        $skyKickNamedLocation.Id) `
    -IncludeRoles $adminRoleIds `
    -IncludeUsers @("GuestsOrExternalUsers")
Set-CtIdentityConditionalAccessPolicy
    -Name "Require MFA" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -ExcludeApplications @($skyKickServicePrincipal.AppId) `
    -ExcludeLocations @(
        $calTechNamedLocation.Id,
        $onPremNamedLocation.Id,
        $skyKickNamedLocation.Id) `
    -ExcludeRoles $adminRoleIds `
    -IncludeUsers @("All") `
    -BuiltInControls @("mfa")
Set-CtIdentityConditionalAccessPolicy `
    -Name "Block Basic Authentication" `
    -ClientAppTypes @("exchangeActiveSync", "other") `
    -ExcludeApplications @($skyKickServicePrincipal.AppId) `
    -ExcludeLocations @(
        $allowedCountriesNamedLocation.Id,
        $calTechNamedLocation.Id,
        $onPremNamedLocation.Id,
        $skyKickNamedLocation.Id)
Set-CtIdentityConditionalAccessPolicy `
    -Name "Email Encryption External User Access" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -IncludeApplications @("00000012-0000-0000-c000-000000000000")
Set-CtIdentityConditionalAccessPolicy `
    -Name "Require Approved Device - MacOS" `
    -ClientAppTypes @("browser", "mobileAppsAndDesktopClients") `
    -ExcludeApplications @("d4ebce55-015a-49b5-a083-c84d1797ae8c") `
    -ExcludeLocations  @($onPremNamedLocation.Id) `
    -IncludePlatforms @("macOS")
$mobileAccessAllowedGroup = Get-MgGroup -Filter "DisplayName eq 'Mobile Access Allowed'"
Set-CtIdentityConditionalAccessPolicy `
    -Name "Require Approved Device - Mobile Device" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -ExcludeApplications @("d4ebce55-015a-49b5-a083-c84d1797ae8c") `
    -IncludeGroups @($mobileAccessAllowedGroup.Id) `
    -IncludePlatforms @("android", "iOS") `
    -BuiltInControls @("approvedApplication", "compliantApplication") `
    -Operator "AND"
Set-CtIdentityConditionalAccessPolicy `
    -Name "Block Mobile Devices for Unapproved Users" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -ExcludeGroups @($mobileAccessAllowedGroup.Id) `
    -IncludePlatforms @("android", "iOS")  
Set-CtIdentityConditionalAccessPolicy `
    -Name "Require Approved Device - Windows" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -ExcludeLocations @($calTechNamedLocation.Id, $onPremNamedLocation.Id, $skyKickNamedLocation.Id) `
    -IncludePlatforms @("windows") `
    -BuiltInControls @("domainJoinedDevice")
Set-CtIdentityConditionalAccessPolicy `
    -Name "Block Intune Enrollment Off Prem" `
    -ClientAppTypes @("exchangeActiveSync", "browser", "mobileAppsAndDesktopClients", "other") `
    -IncludeApplications @($intuneServicePrincipalId,$intuneenrollmentServicePrincipalId) `
    -ExcludeLocations @($calTechNamedLocation.id, $onPremNamedLocation.Id) 