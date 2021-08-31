function Connect-CtDeviceAppManagement {
    Connect-MgGraph "DeviceManagementApps.ReadWrite.All"
    Select-MgProfile "beta"
}

function Remove-CtMgDeviceAppManagementMobileApp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [ValidateSet('Android', 'iOS')] [string] $Platform,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $mobileApp = Get-MgDeviceAppManagementMobileApp `
            -Filter "isof('microsoft.graph.$($Platform)StoreApp')" `
            | Where-Object DisplayName -eq "$Name"
        if ($null -eq $mobileApp) {
            Write-Host "Skipped $Platform mobile app $Name because it does not exist."
        } else {
            $mobileApp | ForEach-Object { Remove-MgDeviceAppManagementMobileApp -MobileAppId $_.Id }
            Write-Host "Removed $Platform mobile app $Name."
        }
    }
}

function Remove-CtDeviceAppManagementiOSManagedAppProtection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $managedAppProtection = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "DisplayName eq '$Name'"
        if ($null -eq $managedAppProtection) {
            Write-Host "Skipped iOS managed app protection $Name because it does not exist."
        } else {
            $managedAppProtection = Remove-MgDeviceAppManagementiOSManagedAppProtection `
                -IosManagedAppProtectionId $managedAppProtection.Id
            Write-Host "Removed iOS managed app protection $Name."
        }
    }
}

function Remove-CtDeviceAppManagementAndroidManagedAppProtection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $managedAppProtection = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "DisplayName eq '$Name'"
        if ($null -eq $managedAppProtection) {
            Write-Host "Skipped Android managed app protection $Name because it does not exist."
        } else {
            $managedAppProtection = Remove-MgDeviceAppManagementAndroidManagedAppProtection `
                -AndroidManagedAppProtectionId $managedAppProtection.Id
            Write-Host "Removed Android managed app protection $Name."
        }
    }
}

function Set-CtMgDeviceAppManagementMobileApp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [ValidateSet('Android', 'iOS')] [string] $Platform,
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $false)] [string] $AppStoreUrl
    )

    Process {
        $mobileApp = Get-MgDeviceAppManagementMobileApp `
            -Filter "isof('microsoft.graph.$($Platform)StoreApp')" `
            | Where-Object DisplayName -eq "$Name"
        if ($null -eq $mobileApp) {
            if ($Platform -eq 'Android') {
                $minimumSupportedVersion = @{ "v9_0" = $true };
            } else {
                $appStoreApp = Invoke-RestMethod `
                    -Uri "https://itunes.apple.com/search?country=us&media=software&entity=software,iPadSoftware&term=$Name" `
                    | ForEach-Object { $_.results[0] }
                $appStoreIcon = Invoke-WebRequest `
                    -Uri $appStoreApp.artworkUrl512 `
                    | ForEach-Object { [System.Convert]::ToBase64String($_.Content) }
                $applicableDeviceType = @{
                    "iPad" = $true;
                    "iPhoneAndIPod" = $true;
                };
                $appStoreUrl = $appStoreApp.trackViewUrl;
                $description = $appStoreApp.description;
                $minimumSupportedVersion = @{ "v12_0" = $true };
                $publisher = $appStoreApp.artistName;
                $settings = @{
                    "@odata.type" = "#microsoft.graph.$($Platform)StoreAppAssignmentSettings";
                    "uninstallOnDeviceRemoval" = $false
                };
            }

            $body = @{
                "@odata.type" = "#microsoft.graph.$($Platform)StoreApp";
                "applicableDeviceType" = $applicableDeviceType;
                "appStoreUrl" = $appStoreUrl;
                "description" = $description;
                "displayName" = $Name;
                "largeIcon" = @{
                    "type" = "image/jpeg";
                    "value" = $appStoreIcon;
                };
                "minimumSupportedOperatingSystem" = $minimumSupportedVersion;
                "publisher" = $publisher;
            } | ConvertTo-Json
            $mobileApp = New-MgDeviceAppManagementMobileApp -BodyParameter $body
            $mobileApp = Get-MgDeviceAppManagementMobileApp -MobileAppId $mobileApp.Id
            while ($mobileApp.PublishingState -eq 'processing') {
                $mobileApp = Get-MgDeviceAppManagementMobileApp -MobileAppId $mobileApp.Id
                Start-Sleep 1
            }

            $body = @{
                "mobileAppAssignments" = @(
                    @{
                        "@odata.type" = "#microsoft.graph.mobileAppAssignment";
                        "target" = @{
                            "@odata.type" = "#microsoft.graph.allLicensedUsersAssignmentTarget";
                        };
                        "intent" = "AvailableWithoutEnrollment";
                        "settings" = $settings;
                    }
                );
            } | ConvertTo-Json -Depth 3
            Invoke-GraphRequest `
                -Method POST `
                -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($mobileApp.Id)/assign" `
                -Body $body
            Write-Host "Created $Platform mobile app $Name."
        } else {
            Write-Host "Skipped $Platform mobile app $Name because it already exists."
        }

        return $mobileApp
    }
}

function Set-CtDeviceAppManagementiOSManagedAppProtection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string[]] $BundleIds
    )

    Process {
        $managedAppProtection = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "DisplayName eq '$Name'"
        if ($null -eq $managedAppProtection) {
            $body = @{
                "@odata.type" = "#microsoft.graph.iosManagedAppProtection";
                "apps" = $BundleIds | ForEach-Object {
                    @{
                        "mobileAppIdentifier" = @{
                            "@odata.type" = "#microsoft.graph.iosMobileAppIdentifier";
                            "bundleId" = $_;
                        };
                    }
                };
                "allowedDataStorageLocations" = @("oneDriveForBusiness", "sharePoint");
                "allowedOutboundClipboardSharingLevel" = "managedAppsWithPasteIn";
                "allowedOutboundDataTransferDestinations" = "managedApps";
                "appDataEncryptionType" = "whenDeviceLocked";
                "assignments" = @(
                    @{
                        "target" = @{
                            "@odata.type" = "#microsoft.graph.groupAssignmentTarget";
                            "groupId" = "eb09e17c-8caf-47b9-a081-d3f6cb5a0a40"; # All Users
                        };
                    }
                );
                "dataBackupBlocked" = $true;
                "deviceComplianceRequired" = $true;
                "disableAppPinIfDevicePinIsSet" = $true;
                "displayName" = $Name;
                "exemptedAppProtocols" = @();
                "periodOfflineBeforeAccessCheck" = "PT12H";
                "periodOfflineBeforeWipeIsEnforced" = "P90D";
                "periodOnlineBeforeAccessCheck" = "PT5M";
                "pinRequired" = $true;
                "saveAsBlocked" = $true;
            } | ConvertTo-Json -Depth 3
            $managedAppProtection = New-MgDeviceAppManagementiOSManagedAppProtection -BodyParameter $body
            Write-Host "Created iOS managed app protection $Name."
        } else {
            Write-Host "Skipped iOS managed app protection $Name because it already exists."
        }
    }
}

function Set-CtDeviceAppManagementAndroidManagedAppProtection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string[]] $PackageIds
    )

    Process {
        $managedAppProtection = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "DisplayName eq '$Name'"
        if ($null -eq $managedAppProtection) {
            $body = @{
                "@odata.type" = "#microsoft.graph.androidManagedAppProtection";
                "apps" = $PackageIds | ForEach-Object {
                    @{
                        "mobileAppIdentifier" = @{
                            "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier";
                            "packageId" = $_;
                        };
                    }
                };
                "allowedDataStorageLocations" = @("oneDriveForBusiness");
                "allowedOutboundClipboardSharingLevel" = "managedAppsWithPasteIn";
                "allowedOutboundDataTransferDestinations" = "managedApps";
                "assignments" = @(
                    @{
                        "target" = @{
                            "@odata.type" = "#microsoft.graph.groupAssignmentTarget";
                            "groupId" = "eb09e17c-8caf-47b9-a081-d3f6cb5a0a40"; # All Users
                        };
                    }
                );
                "dataBackupBlocked" = $true;
                "deviceComplianceRequired" = $true;
                "displayName" = $Name;
                "encryptAppData" = $true;
                "periodOfflineBeforeAccessCheck" = "PT12H";
                "periodOfflineBeforeWipeIsEnforced" = "P90D";
                "periodOnlineBeforeAccessCheck" = "PT30M";
                "pinRequired" = $true;
                "saveAsBlocked" = $true;
            } | ConvertTo-Json -Depth 3
            $managedAppProtection = New-MgDeviceAppManagementAndroidManagedAppProtection -BodyParameter $body
            Write-Host "Created Android managed app protection $Name."
        } else {
            Write-Host "Skipped Android managed app protection $Name because it already exists."
        }
    }
}

function Test-CtMgDeviceAppManagementMobileApp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [ValidateSet('Android', 'iOS')] [string] $Platform,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $mobileApp = Get-MgDeviceAppManagementMobileApp `
            -Filter "isof('microsoft.graph.$($Platform)StoreApp')" `
            | Where-Object DisplayName -eq "$Name"
        if ($null -eq $mobileApp) {
            Write-Host "Missing $Platform mobile app $Name."
        } else {
            Write-Host "Found $Platform mobile app $Name."
        }
    }
}

function Test-CtDeviceAppManagementiOSManagedAppProtection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $managedAppProtection = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "DisplayName eq '$Name'"
        if ($null -eq $managedAppProtection) {
            Write-Host "Missing iOS managed app protection $Name."
        } else {
            Write-Host "Found iOS managed app protection $Name."
        }
    }
}

function Test-CtDeviceAppManagementAndroidManagedAppProtection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Name
    )

    Process {
        $managedAppProtection = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "DisplayName eq '$Name'"
        if ($null -eq $managedAppProtection) {
            Write-Host "Missing Android managed app protection $Name."
        } else {
            Write-Host "Found Android managed app protection $Name."
        }
    }
}