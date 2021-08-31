Param([Parameter(Mandatory = $true)] [string] $UserId)
Connect-MgGraph -Scopes "User.ReadBasic.All,UserAuthenticationMethod.Read.All" | Out-Null
Get-MgAuditLogSignIn -All -Filter "UserId eq '$UserId'" `
    | Where-Object { ($_.AppliedConditionalAccessPolicies | Where-Object Result -eq NotApplied).Length }