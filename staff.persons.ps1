#Configuration
$config = ConvertFrom-Json $configuration;
$expansions = $config.expansions -split (",");
$extensions = $config.extensions -split (",");

#Get OAuth Token
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
$Token = [System.Convert]::ToBase64String( [System.Text.Encoding]::ASCII.GetBytes("$($config.apiKey):$($config.apiSecret)") );
$headers = @{ Authorization = "Basic " + $Token };
$tokenResponse = Invoke-RestMethod -uri "$($config.baseurl)/oauth/access_token" -Method 'POST' -Headers $headers -Body (@{grant_type= "client_credentials";})


$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $($tokenResponse.access_token)")
$headers.Add("Accept", "application/json")

#Get Schools
$uri = "$($config.baseurl)/ws/v1/district/school"
$schools = (Invoke-RestMethod $uri -Method GET -Headers $headers).schools.school


$allstaff = [System.Collections.ArrayList]@();
foreach($school in $schools)
{
    #Count Staff
    $uri = "$($config.baseurl)/ws/v1/school/$($school.id)/staff/count"
    $count = (Invoke-RestMethod $uri -Method GET -Headers $headers  -Body $parameters).resource.count

    #Get Staff
    Write-Verbose -Verbose "Retrieving Staff ($($school.id))"
    $page = 1;
    $staff = [System.Collections.ArrayList]@();
    
    while($true)
    {
        $parameters = @{
            expansions = ($expansions -join ',');
            page = $page;
            pagesize = 100

        }
        $uri = "$($config.baseurl)/ws/v1/school/$($school.id)/staff"
        Write-Verbose -Verbose "Page $($page)";
        $response = Invoke-RestMethod $uri -Method GET -Headers $headers -Body $parameters
   
        if($response.staffs.staff -eq $null) { break; } 
        
        if($response.staffs.staff -is [array])
        {
            [void]$staff.AddRange($response.staffs.staff);
        }
        else
        {
            [void]$staff.Add($response.staffs.staff);
        }

        if($staff.count -lt $count)
        {
            $page++;
        }
        else
        {
            break;
        }

    }
    
    if($staff.count -gt 0)
    {
        [void]$allStaff.AddRange($staff);
    }
}

function Get-ObjectProperties 
{
    param ($Object, $Depth = 0, $MaxDepth = 10)
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

foreach($s in $allstaff)
{
    $person = @{};

    $person = Get-ObjectProperties -Object $s;

    $person['ExternalId'] = if($s.id) { $s.Id } else { $s.local_id }
    $person['DisplayName'] = "$($s.Name.first_name) $($s.name.last_name) ($($person.ExternalId))";

    $person['Contracts'] = [System.Collections.ArrayList]@();

    foreach($school in $s.school_affiliations.school_affiliation)
    {
        $contract = @{};
        $location = @{};

        $contract = Get-ObjectProperties -Object $school;
        $contract['PersonExternalId'] = $($person.ExternalId)
        [void]$person['Contracts'].Add($contract);   
    }

    Write-Output ($person | ConvertTo-Json -Depth 20);
}