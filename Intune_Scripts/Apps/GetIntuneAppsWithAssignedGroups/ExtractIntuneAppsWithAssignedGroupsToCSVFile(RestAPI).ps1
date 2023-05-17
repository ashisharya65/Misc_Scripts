
<#
    .SYNOPSIS
        PowerShell Script to extract a report of Intune Apps and their assigned Azure AD groups.

    .DESCRIPTION
        With this Powershell script, we will get a report of all the Intune apps created in your Tenant and their assigned Azure AD groups.

    .NOTES
        Author : Ashish Arya
        Date   : 17 May 2023
#>

# CSV file path
$CSVFilePath = "$($PSScriptRoot)\" + "$($myInvocation.myCommand.name.split('.')[0])" + ".csv"

#Function for Setting Environment Variables
Function Set-EnvtVariables {
    <#
    .SYNOPSIS
    Function set the environment variables in user context.
    .DESCRIPTION
    This script will help you to create the user environment variables on the device where you are executing this script.
    This script will ask you to provide the Clientid, ClientSecret and Tenantid from your Azure AD app created for PowerShell-Graph API integration.
    .EXAMPLE
    Set-EnvtVariables
    .NOTES
    Name: Set-EnvtVariables
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ClientId,
        [Parameter(Mandatory)]
        [string] $ClientSecret,
        [Parameter(Mandatory)]
        [string] $TenantId
    )

    $EnvtVariables = @(
        [PSCustomObject]@{
            Name  = "AZURE_CLIENT_ID"
            Value = $CliendId
        },
        [PSCustomObject]@{
            Name  = "AZURE_CLIENT_SECRET"
            Value = $ClientSecret
        },
        [PSCustomObject]@{
            Name  = "AZURE_TENANT_ID"
            Value = $TenantId
        }
    )

    Foreach ($EnvtVar in $EnvtVariables) {
        
        Try {
            [System.Environment]::SetEnvironmentVariable($EnvtVar.Name, $EnvtVar.Value, [System.EnvironmentVariableTarget]::User)
        }
        Catch {
            Write-Host "Unable to set the $($EnvtVar.Name) environment value. So please set the Environment variables for your Azure AD registered app in order to execute this script successfully." -foreground 'Red'
        }
        
    }
}

#Function To get the access token
Function Get-AuthToken {
    <#
    .SYNOPSIS
    This function uses the Azure AD app details which in turn will help to get the access token to interact with Microsoft Graph API.
    .DESCRIPTION
    This function uses the Azure AD app details which in turn will help to get the access token to interact with Microsoft Graph API.
    As a prerequisite for executing this script, you will require the MSAL.PS powershell module for authenticating to the API.
    #>

    # Checking if the MSAL.PS Powershell module is installed or not. If not then it will be installed.
    $MSALPSModule = Get-Module -Name 'MSAL.PS' -ListAvailable

    if ($null -eq $MSALPSModule) {
        Write-Host "MSAL.PS PowerShell module is required to be installed on this machine in order to connect to MS Graph API. Hence installing it" -ForegroundColor 'Yellow'
        Install-Module -name 'MSAL.PS' -Scope CurrentUser -Force  
    }

    # Azure AD app details
    $authparams = @{
        ClientId     = [System.Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
        TenantId     = [System.Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
        ClientSecret = ([System.Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET") | ConvertTo-SecureString -AsPlainText -Force)
    }
    $auth = Get-MsalToken @authParams

    $authorizationHeader = @{
        Authorization = $auth.CreateAuthorizationHeader()
    }

    return $authorizationHeader

}

#Function to get all Intune app
Function Get-IntuneApplication{

<#
.SYNOPSIS
This function is used to get applications from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any applications added
.EXAMPLE
Get-IntuneApplication
Returns any applications configured in Intune
.NOTES
NAME: Get-IntuneApplication
#>

[cmdletbinding()]

$graphApiVersion = "Beta"
$Resource = "deviceAppManagement/mobileApps"

try {

$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
(Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).Value | ? { (!($_.'@odata.type').Contains("managed")) }

}

catch {

$ex = $_.Exception
Write-Host "Request to $Uri failed with HTTP Status $([int]$ex.Response.StatusCode) $($ex.Response.StatusDescription)" -f Red
$errorResponse = $ex.Response.GetResponseStream()
$reader = New-Object System.IO.StreamReader($errorResponse)
$reader.BaseStream.Position = 0
$reader.DiscardBufferedData()
$responseBody = $reader.ReadToEnd();
Write-Host "Response content:`n$responseBody" -f Red
Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
write-host
break

}

}

#Function to get all the assignment details associated with an Intune app
Function Get-IntuneAppAssignment{

    <#
    .SYNOPSIS
    This function is used to get an application assignment from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets an application assignment
    .EXAMPLE
    Get-ApplicationAssignment
    Returns an Application Assignment configured in Intune
    .NOTES
    NAME: Get-ApplicationAssignment
    #>

    [cmdletbinding()]

    param
    (
        $ApplicationId
    )

    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps/$ApplicationId/?`$expand=categories,assignments"
    
    try {
        
        if (!$ApplicationId) {

            write-host "No Application Id specified, specify a valid Application Id" -f Red
            break

        }

        else {
        
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get)
        
        }
    
    }
    
    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break

    }

} 

# Getting all the Azure AD group details
Function Get-AADGroup{

    <#
    .SYNOPSIS
    This function is used to get AAD Groups from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Groups registered with AAD
    .EXAMPLE
    Get-AADGroup
    Returns all users registered with Azure AD
    .NOTES
    NAME: Get-AADGroup
    #>

    [cmdletbinding()]

    param
    (
        $GroupName,
        $id,
        [switch]$Members
    )

    # Defining Variables
    $graphApiVersion = "v1.0"
    $Group_resource = "groups"
    
    try {

        if ($id) {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=id eq '$id'"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value

        }
        
        elseif ($GroupName -eq "" -or $null -eq $GroupName) {
        
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)"
            (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).Value
        
        }

        else {
            
            if (!$Members) {

                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).Value
            
            }
            
            elseif ($Members) {
            
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
                $Group = (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).Value
            
                if ($Group) {

                    $GID = $Group.id

                    $Group.displayName
                    write-host

                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$GID/Members"
                    (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).Value

                }

            }
        
        }

    }

    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break

    }

}
####################################################################################

#Checking if the environment variables for the Azure AD app are created or not
if ($null -eq (Get-ChildItem env: | Where-Object { $_.Name -like "Azure_*" })) {
    Write-Host "`nThe environment variables for your Azure AD app are not created. Hence creating..." -ForegroundColor "Yellow"
    Set-EnvtVariables
}

# Access token for authenticating to MS Graph
$authToken = Get-AuthToken

# Getting all the Intune applications details
$AllApps = Get-IntuneApplication | Select-object displayName, id

Write-Host "`nCollating all the information..`n" -ForegroundColor 'Yellow'

# Looping through all Intune Apps
Foreach($App in $AllApps){
    
    # Inializing the variables 
    $GroupIds = $GroupNames = $null

    # Getting the Group Ids
    $GroupIds = ((Get-IntuneAppAssignment -ApplicationId $App.id).assignments.target | Select-Object groupid).groupId

    # Looping through the Group Ids to get the corresponding group names
    Foreach($GroupId in $GroupIds){

        # Getting the Group DisplayName
        $GroupName = (Get-AADGroup -Id $GroupId).DisplayName

        # Collecting all the group names
        [Array]$GroupNames += $GroupName
    }

    # Joining group names using comma(,)
    [string]$GroupList = $GroupNames -join ", "

    # Creating the custom object to store Intune app name and Group names
    $ReportLine = [PSCustomObject][Ordered]@{  
        "ApplicationNames"     = $App.DisplayName
        "GroupNames"           = $GroupList
    }

    # Adding the custom object to the report array
    [Array] $Report += $ReportLine
}

Write-Host "`nExporting all the information.." -ForegroundColor 'Yellow'

# Exporting the app and groups details to CSV Report
$Report | Export-CSV -NoTypeInformation $CSVFilePath
