Connect-MgGraph -Scopes "User.ReadBasic.All,UserAuthenticationMethod.Read.All" | Out-Null
[array]$conditionalAccessUserIds = @()
Get-MgIdentityConditionalAccessPolicy | ForEach-Object {
    $policy = $_.DisplayName

    # Include users
    if ($_.Conditions.Users.IncludeUsers.Contains("All")) {
        $includeUsers = Get-MgUser | ForEach-Object {
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
                Id = $_;
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
    $excludeUsers = $_.Conditions.Users.ExcludeUsers | ForEach-Object {
        [PSCustomObject]@{ 
            Id = $_;
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

    $includeUserIds = $includeUsers | ForEach-Object { $_.Id } | Sort-Object | Get-Unique
    $excludeUserIds = $excludeUsers | ForEach-Object { $_.Id } | Sort-Object | Get-Unique
    $userIds = $includeUserIds | Where-Object { $excludeUserIds -notcontains $_ }
    $conditionalAccessUserIds = ($conditionalAccessUserIds + $userIds) | Sort-Object | Get-Unique
}

$signIns = Get-MgAuditLogSignIn -All -Filter "CreatedDateTime gt $((Get-Date).AddMonths(-1).ToString("o"))"
(Get-MgUser `
    | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id;
            UserPrincipalName = $_.UserPrincipalName;
            ConditionalAccess = $conditionalAccessUserIds -contains $_.Id;
            MicrosoftAuthenticator = (Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $_.Id `
                | Select-Object -First 1) -ne $null;
            SignIns = ($signIns | Where-Object UserId -eq $_.Id).Count;
        }
    }) `
    | Where-Object { $_.ConditionalAccess -eq $false -or $_.MicrosoftAuthenticator -eq $false }