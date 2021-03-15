#region Configuration
$config = ConvertFrom-Json $configuration;
$expansions = $config.expansions -split (",");
$extensions = $config.extensions -split (",");

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#endregion Configuration

#region Functions
function New-AccessToken() {
    [cmdletbinding()]
    Param (
        [object]$config
    ) 
    Process
    {
        #Get OAuth Token
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $Token = [System.Convert]::ToBase64String( [System.Text.Encoding]::ASCII.GetBytes("$($config.apiKey):$($config.apiSecret)") );
        $headers = @{ Authorization = "Basic " + $Token };
        $tokenResponse = Invoke-RestMethod -uri "$($config.baseurl)/oauth/access_token" -Method 'POST' -Headers $headers -Body (@{grant_type= "client_credentials";})


        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $($tokenResponse.access_token)")
        $headers.Add("Accept", "application/json")

        return $headers;
    }
}


function Get-ObjectProperties 
{
    [cmdletbinding()]
    param (
        [object]$Object, 
        [int]$Depth = 0, 
        [int]$MaxDepth = 10
    )
    $OutObject = @{};

    foreach($prop in $Object.PSObject.properties)
    {
        if ($prop.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject" -or $prop.TypeNameOfValue -eq "System.Object" -and $Depth -lt $MaxDepth)
        {
            $OutObject[$prop.Name] = Get-ObjectProperties -Object $prop.Value -Depth ($Depth + 1);
        }
        else
        {
            $OutObject[$prop.Name] = "$($prop.Value)";
        }
    }
    return $OutObject;
}

function Get-ErrorMessage
{
    [cmdletbinding()]
    param (
        [object]$Response
    )
    $reader = New-Object System.IO.StreamReader($Response.Exception.Response.GetResponseStream())
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    Write-Error "StatusCode: $($Response.Exception.Response.StatusCode.value__)`nStatusDescription: $($Response.Exception.Response.StatusDescription)`nMessage: $($reader.ReadToEnd())"
}
#endregion Functions

#region Execute
try {
    $headers = New-AccessToken -Config $config;

    #Get Schools
    Write-Information "Retrieving Departments (Schools)"
    $uri = "$($config.baseurl)/ws/v1/district/school/count"
    $count = (Invoke-RestMethod $uri -Method GET -Headers $headers ).resource.count
    $page = 1;
    $schools = [System.Collections.ArrayList]@();
    
    while($true)
    {
        $parameters = @{
            page = $page;
            pagesize = $config.pageSize;
        }
        $uri = "$($config.baseurl)/ws/v1/district/school"
        
        
        try {
            Write-Information "Retrieving $($uri) - Page $($page)"
            $response = Invoke-RestMethod $uri -Method GET -Headers $headers -Body $parameters
        }    
        catch {
            Get-ErrorMessage -response $_;
            throw $_;
        }

        if($response.schools.school -is [array])
        {
            [void]$schools.AddRange($response.schools.school);
        }
        else
        {
            [void]$schools.Add($response.schools.school);
        }

        if($schools.count -lt $count)
        {
            $page++;
        }
        else
        {
            break;
        }

    }

    foreach($s in $schools)
    {
        $row = @{
                  ExternalId = $s.id;
                  DisplayName = $s.name;
                  Code = $s.school_number;
        }
 
        $row | ConvertTo-Json -Depth 10
    }
}
catch
{

}
#endregion Execute