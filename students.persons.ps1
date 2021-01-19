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


#Count Students
$uri = "$($config.baseurl)/ws/v1/district/student/count"
$parameters = @{
                    q = $config.filter;
}
$count = (Invoke-RestMethod $uri -Method GET -Headers $headers  -Body $parameters).resource.count

#Get Students
Write-Verbose -Verbose "Retrieving Students"
$page = 1;
$students = [System.Collections.ArrayList]@();
while($true)
{
    $parameters = @{
        expansions = ($expansions -join ',');
        page = $page;
        pagesize = 100
        q = $config.filter;

    }
    $uri = "$($config.baseurl)/ws/v1/district/student"
    Write-Verbose -Verbose "Page $($page)";
    $response = Invoke-RestMethod $uri -Method GET -Headers $headers -Body $parameters
    
    if($response.students.student -is [array])
    {
        [void]$students.AddRange($response.students.student);
    }
    else
    {
        [void]$students.Add($response.students.student);
    }

    if($students.count -lt $count)
    {
        $page++;
    }
    else
    {
        break;
    }

}

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

foreach($student in $students)
{
    $person = @{};

    $person = Get-ObjectProperties -Object $student;

    $person['ExternalId'] = if($student.id) { $student.Id } else { $student.local_id }
    $person['DisplayName'] = "$($student.Name.first_name) $($student.name.last_name) ($($person.ExternalId))";

    $person['Contracts'] = [System.Collections.ArrayList]@();

    foreach($school in $schools)
    {
        if($school.Id -eq $student.school_enrollment.school_id)
        {
            $contract = @{};
            $location = @{};

            $contract = Get-ObjectProperties -Object $school;
            $location = Get-ObjectProperties -Object $school;

            $contract['School_enrollment'] = Get-ObjectProperties -Object $student.school_enrollment;

            [void]$person['Contracts'].Add($contract);
            $person['Location'] = $location;
            break;
        }   
    }

    Write-Output ($person | ConvertTo-Json -Depth 20);
}