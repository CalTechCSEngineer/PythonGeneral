Import-Module $PSScriptRoot\CtDeviceAppManagement.psm1 -Force
Connect-CtDeviceAppManagement

$bundleIds = @(
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Adobe Acrobat Reader"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Authenticator"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Bookings"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Edge"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Excel"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Office"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft OneDrive"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft OneNote"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Outlook"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft PowerPoint"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft SharePoint"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Teams"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft To Do"),
    (Set-CtMgDeviceAppManagementMobileApp "iOS" "Microsoft Word")
) | ForEach-Object { $_.AdditionalProperties.bundleId }
Set-CtDeviceAppManagementiOSManagedAppProtection "Default Mobile App Policy for iOS devices" `
    -BundleIds $bundleIds

$packageIds = @(
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Adobe Acrobat Reader" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.adobe.reader"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Authenticator" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.azure.authenticator"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Bookings" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.exchange.bookings"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Edge" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.emmx"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Excel" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.office.excel"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Office" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.office.officehubrow"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft OneDrive" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.skydrive"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft OneNote" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.office.onenote"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Outlook" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.office.outlook"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft PowerPoint" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.office.powerpoint"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft SharePoint" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.sharepoint"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Teams" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.teams"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft To Do" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.todos"),
    (Set-CtMgDeviceAppManagementMobileApp "Android" "Microsoft Word" `
        -AppStoreUrl "https://play.google.com/store/apps/details?id=com.microsoft.office.word")
) | ForEach-Object { $_.AdditionalProperties.packageId }
Set-CtDeviceAppManagementAndroidManagedAppProtection "Default Mobile App Policy for Android devices" `
    -PackageIds $packageIds