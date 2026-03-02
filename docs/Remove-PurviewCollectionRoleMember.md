---
external help file: PurviewMetadataPolicy-help.xml
Module Name: PurviewMetadataPolicy
online version:
schema: 2.0.0
---

# Remove-PurviewCollectionRoleMember

## SYNOPSIS
Removes a principal from a role in a Microsoft Purview collection's metadata policy.

## SYNTAX

```
Remove-PurviewCollectionRoleMember [-AccountName] <String> [-CollectionName] <String> [-RoleId] <String>
 [-PrincipalId] <String> [[-PrincipalType] <String>] [-SkipRoleValidation] [-WhatIf] [-Confirm]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the current metadata policy for the specified collection, removes the principal
from the designated role's attribute rule, then commits the updated policy back to Purview
via PUT.

Accepted principal types:
- User (default): users and service principals, stored under 'principal.microsoft.id'
- Group: Entra ID security groups, stored under 'principal.microsoft.groups.id'

This function is idempotent.
If the principal does not hold the role, no API write is made
and the function completes silently.
Use -Verbose to observe the no-op.

This command supports `-WhatIf` and `-Confirm`.
Use `-WhatIf` to preview whether a policy write would occur without sending a PUT request.

## EXAMPLES

### EXAMPLE 1
```
Remove-PurviewCollectionRoleMember `
    -AccountName 'contoso-purview' `
    -CollectionName 'abc123' `
    -RoleId 'purviewmetadatarole_builtin_data-curator' `
    -PrincipalId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

Removes a user or service principal from the Data Curator role on collection 'abc123'
using the 6-character system name.

### EXAMPLE 2
```
Remove-PurviewCollectionRoleMember `
    -AccountName 'contoso-purview' `
    -CollectionName 'Finance Team' `
    -RoleId 'purviewmetadatarole_builtin_data-curator' `
    -PrincipalId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

Same removal using the collection's friendly display name.

### EXAMPLE 3
```
Remove-PurviewCollectionRoleMember `
    -AccountName 'contoso-purview' `
    -CollectionName 'Finance Team' `
    -RoleId 'purviewmetadatarole_builtin_purview-reader' `
    -PrincipalId 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy' `
    -PrincipalType Group
```

Removes an Entra ID security group from the Purview Reader role.
PrincipalType must
match the type used during assignment - groups and users are stored separately.

## PARAMETERS

### -AccountName
The name of the Microsoft Purview account (the subdomain portion of
https://\<AccountName\>.purview.azure.com).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionName
The collection to remove the role assignment from.
Accepts either the 6-character system
name (e.g.
'abc123') or the friendly display name (e.g.
'Finance Team').
Friendly names
are resolved automatically via the account/collections API.
Pass the system name directly
to avoid that extra API call in performance-sensitive loops.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RoleId
The fully-qualified Purview metadata role ID from which to remove the principal.
Use
Get-PurviewMetadataRole to list available roles.
Built-in role IDs follow the pattern:
'purviewmetadatarole_builtin_\<role-name\>'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PrincipalId
The Entra ID Object ID (GUID) of the user, service principal, or group to remove.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PrincipalType
Whether the principal is a 'User' (covers both users and service principals) or a
'Group' (Entra ID security group).
Defaults to 'User'.
Must match the type used when
the principal was originally assigned, as users and groups are stored under different
attribute conditions in the policy JSON.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: User
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipRoleValidation
Skips the pre-flight API call that validates the RoleId exists.
Useful in batch
operations where the same validated role ID is reused across many collections.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the command runs.
The command is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts for confirmation before running the command.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
Controls how PowerShell handles progress stream output generated by this command. Available in PowerShell 7.4 and later.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None. The function writes no output on success. Use -Verbose for operational detail.
## NOTES
Idempotent: safe to call multiple times with the same arguments.
Requires an active Az.Accounts session (Connect-AzAccount or a managed identity context)
with the Purview Collection Administrator role on the target collection.

## RELATED LINKS
