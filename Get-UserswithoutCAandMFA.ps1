$thumbprint = "542DA90E6983852130E14518AA245E5CC099EE1F"
$AppID = "ba0e3818-f0db-4572-ba50-f5760229581e"
$TenantID = "22c0cdc8-6c63-4348-adf7-2d5caff9e7cf"

Connect-MgGraph -CertificateThumbprint $thumbprint -ClientId $AppID -TenantId $TenantID

$customers = Get-MgContract

foreach ($customer in $customers) {
    $Customer.DisplayName
    Connect-MgGraph -CertificateThumbprint $thumbprint -ClientId $AppID -TenantId $customer.CustomerId
    
[array]$conditionalAccessUserIds = @()
[array]$includeUserIds = @()
[array]$excludeUserIds = @()

Get-MgIdentityConditionalAccessPolicy | ForEach-Object {
    $policy = $_.DisplayName

    # Include users
    if ($_.Conditions.Users.IncludeUsers.Contains("All")) {
        [array]$includeUsers = Get-MgUser | ForEach-Object {
            [PSCustomObject]@{ 
                Id = $_.Id;
                Policy = $policy;
                IncludedBy = "All Users";
                ExcludedBy = $null;
            }
        }
    } else {
        [array]$includeUsers = $_.Conditions.Users.IncludeUsers | ForEach-Object {
            [PSCustomObject]@{ 
                Id = $_.Id;
                Policy = $policy;
                IncludedBy = "User";
                ExcludedBy = $null;
            }
        }
    }

    # Include groups
    $_.Conditions.Users.IncludeGroups | ForEach-Object {
        $includeUsers += Get-MgGroupMember -GroupId $_ | ForEach-Object {
            [PSCustomObject]@{
                Id = $_.Id;
                Policy = $policy;
                IncludedBy = "Group";
                ExcludedBy = $null;
            }
        }
    }

    # Include roles
    $_.Conditions.Users.IncludeRoles | ForEach-Object {
        $includeUsers += Get-MgDirectoryRole `
            -Filter "RoleTemplateId eq '$_'" `
            | ForEach-Object { 
                Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id | ForEach-Object {
                    [PSCustomObject]@{
                        Id = $_.Id;
                        Policy = $policy;
                        IncludedBy = "Role";
                        ExcludedBy = $null;
                    }
                }}
    }

    # Exclude users
    [array]$excludeUsers = $_.Conditions.Users.ExcludeUsers | ForEach-Object {
        [PSCustomObject]@{ 
            Id = $_.Id;
            Policy = $policy;
            IncludedBy = $null;
            ExcludedBy = "User";
        }
    }

    # Exclude groups
    $_.Conditions.Users.ExcludeGroups | ForEach-Object {
        $excludeUsers += Get-MgGroupMember -GroupId $_ | ForEach-Object {
            [PSCustomObject]@{
                Id = $_.Id;
                Policy = $policy;
                IncludedBy = $null;
                ExcludedBy = "Group";
            }
        }
    }

    # Exclude roles
    $_.Conditions.Users.ExcludeRoles | ForEach-Object {
        $excludeUsers += Get-MgDirectoryRole `
            -Filter "RoleTemplateId eq '$_'" `
            | ForEach-Object { 
                Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id | ForEach-Object {
                    [PSCustomObject]@{
                        Id = $_.Id;
                        Policy = $policy;
                        IncludedBy = $null
                        ExcludedBy = "Role";
                    }
                }}
    }

    $includeUserIds += $includeUsers | ForEach-Object { $_.Id }
    $excludeUserIds += $excludeUsers | ForEach-Object { $_.Id }

}

if($includeUserIds.Count -eq 0){
    Write-Host "No Conditional Access policies exist."
    $users = Get-MgUser
    $mfaresultslist = @()
    foreach($user in $users){
        $checkMFAofuser = $null -ne (Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $user.id | Select-Object -First 1)
        $signIns = Get-MgAuditLogSignIn -All | Where-Object {$_.CreatedDateTime -gt ((Get-Date).AddMonths(-1).ToString('o'))}
        $mfaresultslist += ([PSCustomObject]@{
            UserPrincipalName = $user.displayname;
            MicrosoftAuthenticator = $checkMFAofuser;
            SignIns = ($signIns | Where-Object UserId -eq $user.Id).Count;
        }) | Where-Object {$_.MicrosoftAuthenticator -eq $false -and $_.SignIns -ne 0}
    }

    if ($mfaresultslist.count -eq 0){
        Write-Host "`n"
        Write-Host "All clear, no sign-ins without MFA using MS Authenticator!"
        Write-Host "`n"
    } else{
        Write-Host "`n"
        $mfaresultslist
        Write-Host "`n"
    }

}else {
    $conditionalAccessUserIds = $excludeUserIds | Where-Object { $includeUserIds -notcontains $_ } | Select-Object -Unique
    $caormfaresultslist = @()
    foreach ($ID in $conditionalAccessUserIds){
        
        get-mguser -filter "Id eq '$($ID)'" | Select-Object -ExpandProperty DisplayName

        $signIns = Get-MgAuditLogSignIn -All -Filter "UserId eq '$($ID)'" | Where-Object {$_.CreatedDateTime -gt ((Get-Date).AddMonths(-1).ToString('o'))}
        $signInswoCA = $signIns | Where-Object { $_.ConditionalAccessStatus -eq "notApplied" }

        $checkMFAofuser = $null -ne (Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $ID | Select-Object -First 1)
        $username = Get-MgUser -Filter "Id eq '$($ID)'" | Select-Object -ExpandProperty UserPrincipalName
        $caormfaresultslist += ([PSCustomObject]@{
            UserPrincipalName = $username;
            MicrosoftAuthenticator = $checkMFAofuser;
            SignIns = ($signInswoCA | Where-Object UserId -eq $ID).Count;
        }) | Where-Object {$_.MicrosoftAuthenticator -eq $false -and $_.SignIns -ne 0}

    }

    if ($caormfaresultslist.count -eq 0){
        Write-Host "`n"
        Write-Host "All clear, no sign-ins without Conditional Access or MFA using MS Authenticator!"
        Write-Host "`n"
    } else{
        Write-Host "`n"
        $caormfaresultslist
        Write-Host "`n"
        }
}

Disconnect-MgGraph
}
Disconnect-MgGraph