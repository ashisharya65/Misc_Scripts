
<#

    .SYNOPSIS
    PowerShell Script to get all Intune applications associated to an Azure AD Group.
    
    .DESCRIPTION
    With this Powershell script, one can easily get all the Intune applications where an Azure AD group is assigned.
    This script requires to set the environment variables in your client machine with below names:
        - AZURE_CLIENT_ID
        - AZURE_CLIENT_SECRET
        - AZURE_TENANT_ID
        
    .NOTES
        Author : Ashish Arya
        Date   : 09 Feb 2023
        
#>

####################################################################################
Function Get-AuthToken {
    <#
    .SYNOPSIS
    This function uses the Azure AD app details which in turn will help to get the access token to interact with Microsoft Graph API.
    .DESCRIPTION
    This function uses the Azure AD app details which in turn will help to get the access token to interact with Microsoft Graph API.
    As a prerequisite for executing this script, you will require the MSAL.PS powershell module for authenticating to the API.
    #>

    # Checking if the MSAL.PS Powershell module is installed or not. If not then it will be installed.
    Write-Host "`nChecking for MSAL.PS module..." -ForegroundColor 'Yellow'
    Start-Sleep 5

    $MSALPSModule = Get-Module -Name MSAL.PS -ListAvailable

    if ($null -eq $MSALPSModule) {
        Write-Host "MSAL.PS PowerShell module is not installed." -ForegroundColor 'Red'
  
        $Confirm = Read-Host "Press Y for installing the module or N for cancelling the installion"
  
        if ($Confirm -eq "Y") {
            Install-Module -name 'MSAL.PS' -Scope CurrentUser -Force
        }  
        else {
            Write-Host "You have cancelled the installation and the script cannot continue.." -ForegroundColor 'Red'
            write-host
            exit
        }
  
    }
    Else {
        Write-Host "MSAL.PS PowerShell Module is already installed." -ForegroundColor 'Green'
    }
    
    # Azure AD app details
    $authparams = @{
        ClientId     = $env:AZURE_CLIENT_ID
        TenantId     = $env:AZURE_TENANT_ID
        ClientSecret = ($env:AZURE_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force)
    }
    $auth = Get-MsalToken @authParams

    $authorizationHeader = @{
        Authorization = $auth.CreateAuthorizationHeader()
    }

    return $authorizationHeader

}

####################################################################################
Function Get-IntuneApp() {

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

####################################################################################
Function Get-IntuneAppAssignment() {

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

####################################################################################
Function Get-AADGroup() {

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
        (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).Value

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

# Access token for authenticating to MS Graph
$authToken = Get-AuthToken

# Getting all the Intune applications details
$AllApps = Get-IntuneApp | Select-object displayName, id

# Prompt for Group name
$GroupName = Read-Host -prompt "`nEnter the group name associated to the apps"

# Azure AD Group Object id
$Groupid = (Get-AADGroup -GroupName $GroupName).id

Write-Host -ForegroundColor Yellow "`n---------------------------------"
Write-Host -ForegroundColor Yellow "|          Applications         |"
Write-Host -ForegroundColor Yellow "---------------------------------"

# Azure AD Group Object id
$Groupid = (Get-AADGroup -GroupName $GroupName).id

# Looping through all the apps to get those apps which has the group in the assignment section
Foreach ($App in $AllApps) {

    $AssigedGroupIds = (Get-IntuneAppAssignment -applicationId $App.Id).assignments.id

    If ($AssigedGroupIds -match $Groupid) {
        
        Write-Host "$($App.displayName)" -ForegroundColor 'Green'
    }
} 

Write-Host


