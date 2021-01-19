#Config
$config = ConvertFrom-Json $configuration;
$expansions = $config.expansions -split (",");
$extensions = $config.extensions -split (",");

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

#Get OAuth Token
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
$Token = [System.Convert]::ToBase64String( [System.Text.Encoding]::ASCII.GetBytes("$($config.apiKey):$($config.apiSecret)") );
$headers = @{ Authorization = "Basic " + $Token };
$tokenResponse = Invoke-RestMethod -uri "$($config.baseurl)/oauth/access_token" -Method 'POST' -Headers $headers -Body (@{grant_type= "client_credentials";})

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $($tokenResponse.access_token)")
$headers.Add("Accept", "application/json")

#Get Schools
Write-Verbose -Verbose "Retrieving Schools"
$uri = "$($config.baseurl)/ws/v1/district/school/count"
$count = (Invoke-RestMethod $uri -Method GET -Headers $headers ).resource.count
$page = 1;
$schools = [System.Collections.ArrayList]@();
while($true)
{
    $parameters = @{
        page = $page;
        pagesize = 100;
    }
    $uri = "$($config.baseurl)/ws/v1/district/school"
    $response = Invoke-RestMethod $uri -Method GET -Headers $headers -Body $parameters
    
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