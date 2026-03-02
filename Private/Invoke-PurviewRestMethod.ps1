function Invoke-PurviewRestMethod {
    <#
    .SYNOPSIS
    Generic REST wrapper for all Microsoft Purview data-plane API calls.

    .DESCRIPTION
    Acquires a bearer token via Az.Accounts and invokes Invoke-RestMethod against the
    Purview data-plane endpoint. Handles token acquisition, header construction, and
    surfaces API errors with enough context to diagnose failures.

    All Purview data-plane APIs share the base URL https://{accountName}.purview.azure.com.
    The API version must be specified per call because different API surfaces (policystore,
    account/collections, etc.) use different versions.

    .PARAMETER AccountName
    The name of the Microsoft Purview account (without the full domain).

    .PARAMETER UriSuffix
    The path portion of the request URI, e.g. '/policystore/metadataPolicies'.
    A leading slash is optional and will be normalised.

    .PARAMETER Method
    The HTTP method. Defaults to GET.

    .PARAMETER Body
    Optional JSON request body string. Only sent for non-GET methods.

    .PARAMETER ApiVersion
    The api-version query string value for this request.
    Defaults to '2021-07-01' (metadata policy stable).
    Pass '2019-11-01-preview' for the account/collections API.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,

        [Parameter(Mandatory = $true)]
        [string]$UriSuffix,

        [Parameter(Mandatory = $false)]
        [string]$Method = 'GET',

        [Parameter(Mandatory = $false)]
        [string]$Body = '',

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = '2021-07-01'
    )

    Write-Verbose "Acquiring Purview data-plane access token..."
    $TokenResult = Get-AzAccessToken -ResourceUrl "https://purview.azure.net" -ErrorAction Stop

    $Headers = @{
        "Authorization" = "Bearer $($TokenResult.Token)"
        "Content-Type"  = "application/json"
    }

    $UriSuffix = $UriSuffix.TrimStart('/')
    $FullUri   = "https://$AccountName.purview.azure.com/$UriSuffix`?api-version=$ApiVersion"

    Write-Verbose "[$Method] $FullUri"

    $InvokeParams = @{
        Uri     = $FullUri
        Method  = $Method
        Headers = $Headers
    }

    if ($Method -ne 'GET' -and -not [string]::IsNullOrEmpty($Body)) {
        $InvokeParams.Body = $Body
    }

    try {
        return Invoke-RestMethod @InvokeParams
    }
    catch {
        $statusCode = $null
        $exception = $_.Exception
        $responseProperty = $null
        if ($null -ne $exception -and $null -ne $exception.PSObject) {
            $responseProperty = $exception.PSObject.Properties['Response']
        }

        if ($null -ne $responseProperty -and $null -ne $responseProperty.Value) {
            try {
                $statusCode = [int]$responseProperty.Value.StatusCode
            }
            catch {
                $statusCode = $null
            }
        }

        $message = $null
        if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($_.ErrorDetails.Message)) {
            $message = $_.ErrorDetails.Message
        }
        elseif ($null -ne $exception -and -not [string]::IsNullOrWhiteSpace($exception.Message)) {
            $message = $exception.Message
        }
        else {
            $message = $_.ToString()
        }

        if ($null -eq $statusCode) {
            $statusCode = 'unknown'
        }

        throw "Purview API error ($Method $FullUri) — HTTP $statusCode`: $message"
    }
}
