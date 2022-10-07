#$entitlementContext = '{ "configuration": { "defaultDomain": "*******", "correlationPersonField": "externalID", "correlationAccountField": "employeeID", "baseurl": "https://********.powerschool.com", "apiKey": "*******", "apiSecret": "*******" } }'
#$account = @{additionalFields = @{employeeId = '1234'};sAMAccountName = 'sampleStudent'} | convertTo-json
#region Configuration
$a = $account | ConvertFrom-Json
#Write-Information $account

# The entitlementContext contains the configuration
# - configuration: The configuration that is set in the Custom PowerShell configuration
$eRef = $entitlementContext | ConvertFrom-Json

$nonUniqueFields = [System.Collections.Generic.List[String]]::new()

$config = @{
    baseurl   = $eRef.configuration.baseurl
    apiKey    = $eRef.configuration.apiKey
    apiSecret = $eRef.configuration.apiSecret
    filter    = "student_username=={0}" -f $a.SAMAccountName
}
$success = $True;
# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#endregion Configuration
#region Functions
function New-AccessToken() {
    [cmdletbinding()]
    Param (
        [object]$config
    )
    Process {
        #Get OAuth Token
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $Token = [System.Convert]::ToBase64String( [System.Text.Encoding]::ASCII.GetBytes("$($config.apiKey):$($config.apiSecret)") );
        $headers = @{ Authorization = "Basic " + $Token };
        $tokenResponse = Invoke-RestMethod -uri "$($config.baseurl)/oauth/access_token" -Method 'POST' -Headers $headers -Body (@{grant_type = "client_credentials"; })
        $headers = @{
            "Authorization" = "Bearer $($tokenResponse.access_token)"
            "Accept"        = "application/json"
        }
        return $headers;
    }
}
function Get-ErrorMessage {
    [cmdletbinding()]
    param (
        [object]$Response
    )
    try {
        $reader = New-Object System.IO.StreamReader($Response.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        Write-Error "StatusCode: $($Response.Exception.Response.StatusCode.value__)`nStatusDescription: $($Response.Exception.Response.StatusDescription)`nMessage: $($reader.ReadToEnd())"
    }
    catch {
        Write-Information $response
    }
}
#endregion Functions
#region Execute
try {
    $headers = New-AccessToken -Config $config;
    #Get Students
    $uri = "$($config.baseurl)/ws/v1/district/student"
    $parameters = @{
        q          = $config.filter
    }
    try {
        Write-Information "Retrieving $($uri)"
        $response = (Invoke-RestMethod $uri -Method GET -Headers $headers -Body $parameters)
    }
    catch {
        Get-ErrorMessage -response $_;
        $success = $false;
        break;
    }
}
catch {
    throw $_;
}
if ($response.students.student -and $response.students.student.local_id -ne $a.additionalFields.employeeID) {
    #found user
    $nonUniqueFields.add('samAccountName')
    Write-Information ('generated samAccountName: {0} , conflicting ID : {1}' -f $a.samAccountName, $response.students.student.local_id)
}

#endregion Execute

#region Return Result
$result = [PSCustomObject]@{
    Success         = $success;
    # Add field name as string when field is not unique
    NonUniqueFields = $nonUniqueFields
};

# Send result back
Write-Output $result | ConvertTo-Json -Depth 2
#endregion Return Result
