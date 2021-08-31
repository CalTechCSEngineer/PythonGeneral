##Connect-MgGraph -Scopes "User.ReadBasic.All,UserAuthenticationMethod.Read.All" | Out-Null
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
$conditionalAccessUserIds = $excludeUserIds | Where-Object { $includeUserIds -notcontains $_ } | Select-Object -Unique
<#foreach($ID in $conditionalAccessUserIds){
    get-mguser -filter "Id eq '$($ID)'" | Select-Object -ExpandProperty DisplayName
}#>
foreach ($ID in $conditionalAccessUserIds){
    $signIns = Get-MgAuditLogSignIn -All -Filter "UserId eq '$($ID)'" | Where-Object {$_.CreatedDateTime -gt ((Get-Date).AddMonths(-1).ToString('o'))}
    $signInswoCA = $signIns | Where-Object { $_.ConditionalAccessStatus -eq "notApplied" }

    $checkMFAofuser = $null -ne (Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $ID | Select-Object -First 1)
    $username = Get-MgUser -Filter "Id eq '$($ID)'" | Select-Object -ExpandProperty UserPrincipalName
    $caormfaresultslist = ([PSCustomObject]@{
        UserPrincipalName = $username;
        MicrosoftAuthenticator = $checkMFAofuser;
        SignIns = ($signInswoCA | Where-Object UserId -eq $ID).Count;
    }) | Where-Object {$_.MicrosoftAuthenticator -eq $false -and $_.SignIns -ne 0}

}

if ($null -eq $caormfaresultslist){
    Write-Host "
    "
    Write-Host "All clear, no sign-ins without Conditional Access or MFA using MS Authenticator!"
} else{$caormfaresultslist}