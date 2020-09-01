#Config
$baseurl = "https://<CUSTOMER>.powerschool.com";
$apiKey = "<KEY>";
$apiSecret = "<SECRET>";
$expansions = @("demographics", "school_enrollment", "contact_info");
$extensions = @();
$filter = "name.last_name==*;school_enrollment.enroll_status_code==(-1,0)"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

#Get OAuth Token
$Token = [System.Convert]::ToBase64String( [System.Text.Encoding]::ASCII.GetBytes("$($apiKey):$($apiSecret)") );
$headers = @{ Authorization = "Basic " + $Token };
$tokenResponse = Invoke-RestMethod -uri "$($baseurl)/oauth/access_token" -Method 'POST' -Headers $headers -Body (@{grant_type= "client_credentials";})


$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $($tokenResponse.access_token)")
$headers.Add("Accept", "application/json")


#Count Students
$uri = "$($baseurl)/ws/v1/district/student/count"
$parameters = @{
                    q = "name.last_name==*;school_enrollment.enroll_status_code==(-1,0)";
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
        q = $filter;

    }
    $uri = "$($baseurl)/ws/v1/district/student"
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
$uri = "$($baseurl)/ws/v1/district/school/count"
$count = (Invoke-RestMethod $uri -Method GET -Headers $headers ).resource.count
$page = 1;
$schools = [System.Collections.ArrayList]@();
while($true)
{
    $parameters = @{
        page = $page;
        pagesize = 100;
    }
    $uri = "$($baseurl)/ws/v1/district/school"
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

foreach($student in $students)
{
    $person = @{};
    $person['ExternalId'] = if($student.id) { $student.Id } else { $student.local_id }
    $person['DisplayName'] = "$($student.FullNameFL) ($($person.ExternalId))";

    foreach($prop in $student.PSObject.properties)
    {
        $person[$prop.Name] = "$($prop.Value)";
    }

    $person['Contracts'] = [System.Collections.ArrayList]@();

    foreach($school in $schools)
    {
        if($school.Id -eq $student.school_enrollment.school_id)
        {
            $contract = @{};
            $location = @{};

            foreach($prop in $school.PSObject.properties)
            {
                $contract[$prop.Name] = "$($prop.Value)";
                $location[$prop.Name] = "$($prop.Value)";
            }

            foreach($prop in $student.school_enrollment.PSObject.properties)
            {
                $contract[$prop.Name] = "$($prop.Value)";
            }

            [void]$person['Contracts'].Add($contract);
            $person['Location'] = $location;
            break;
        }   
    }

    Write-Output ($person | ConvertTo-Json -Depth 20);
}
