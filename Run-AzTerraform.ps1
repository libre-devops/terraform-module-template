param (
    [string]$RunTerraformInit = "true",
    [string]$RunTerraformPlan = "true",
    [string]$RunTerraformPlanDestroy = "false",
    [string]$RunTerraformApply = "false",
    [string]$RunTerraformDestroy = "false",
    [bool]$DebugMode = $false,
    [string]$DeletePlanFiles = "true",
    [string]$TerraformVersion = "latest",
    [string]$CloneSharedVars = "true",
    [string]$SharedVarsRepo = "https://github.com/libre-devops/terraform-azurerm-shared-vars.git",

    [Parameter(Mandatory = $true)]
    [string]$BackendStorageSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$BackendStorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$BackendStorageAccountRgName,

    [Parameter(Mandatory = $true)]
    [string]$BackendStorageAccountBlobContainerName,

    [Parameter(Mandatory = $true)]
    [string]$BackendStorageAccountBlobStatefileName
)

try
{
    $ErrorActionPreference = 'Stop'
    $CurrentWorkingDirectory = (Get-Location).path

    # Enable debug mode if DebugMode is set to $true
    if ($DebugMode)
    {
        $DebugPreference = "Continue"
        $Env:TF_LOG = "DEBUG"
    }
    else
    {
        $DebugPreference = "SilentlyContinue"
    }

    function Convert-ToBoolean($value)
    {
        $valueLower = $value.ToLower()
        if ($valueLower -eq "true")
        {
            return $true
        }
        elseif ($valueLower -eq "false")
        {
            return $false
        }
        else
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Invalid value - $value. Exiting."
            exit 1
        }
    }

    # Function to check if tenv is installed
    function Test-TenvExists
    {
        try
        {
            $tenvPath = Get-Command tenv -ErrorAction Stop
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Tenv found at: $( $tenvPath.Source )" -ForegroundColor Green
        }
        catch
        {
            Write-Warning "[$( $MyInvocation.MyCommand.Name )] Warning: tenv is not installed or not in PATH. Skipping version checking."
        }
    }

    # Function to check if Terraform is installed
    function Test-TerraformExists
    {
        try
        {
            $terraformPath = Get-Command terraform -ErrorAction Stop
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Terraform found at: $( $terraformPath.Source )" -ForegroundColor Green
        }
        catch
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform is not installed or not in PATH. Exiting."
            exit 1
        }
    }

    function Assert-AzStorageContainer
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$StorageAccountSubscription,

            [Parameter(Mandatory = $true)]
            [string]$StorageAccountName,

            [Parameter(Mandatory = $true)]
            [string]$ResourceGroupName,

            [Parameter(Mandatory = $true)]
            [string]$ContainerName
        )

        begin {
            try
            {
                $azureAplicationId = $Env:ARM_CLIENT_ID
                $azureTenantId = $Env:ARM_TENANT_ID
                $azurePassword = ConvertTo-SecureString $Env:ARM_CLIENT_SECRET -AsPlainText -Force
                $psCred = New-Object System.Management.Automation.PSCredential($azureAplicationId, $azurePassword)
                Connect-AzAccount -ServicePrincipal -Credential $psCred -Tenant $azureTenantId | Out-Null
                Write-Host "Info: Connected to AzAccount using Powershell" -ForegroundColor Yellow

                # Set the subscription context
                Set-AzContext -SubscriptionId $StorageAccountSubscription | Out-Null

                # Get the Storage Account
                $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error in setting up the Azure context: $_"
                return
            }
        }

        process {
            try
            {
                # Create a storage context using OAuth token
                $ctx = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -UseConnectedAccount

                # Check if the Blob Container Exists
                $container = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue

                # Create the Container if it Doesn't Exist
                if ($null -eq $container)
                {
                    New-AzStorageContainer -Name $ContainerName -Context $ctx
                    Write-Host "Success: Container '$ContainerName' created." -ForegroundColor Green
                }
                else
                {
                    Write-Host "Info: Container '$ContainerName' already exists." -ForegroundColor Yellow
                }
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error in processing the container creation: $_"
            }
        }

        end {
            Write-Host "Operation completed, removing PowerShell Context"
            Disconnect-AzAccount | Out-Null
        }
    }

    function Copy-SharedVars
    {
        param (
            [Parameter(Mandatory = $true)]
            [string]$WorkingDirectory,

            [Parameter(Mandatory = $true)]
            [string]$SharedVarsRepo
        )

        git clone $SharedVarsRepo

        # Get the repo name and remove the '.git' suffix if present
        $repoName = ((Split-Path -Leaf $SharedVarsRepo) -replace '\.git$', '')

        # Construct the full path to the cloned repo
        $SharedVarsRepoPath = Join-Path -Path $WorkingDirectory -ChildPath $repoName

        # Change directory into the cloned repo
        Set-Location -Path $SharedVarsRepoPath

        # Check if the clone was successful
        if ($LASTEXITCODE -eq 0)
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Successfully cloned repo to '$SharedVarsRepoPath'." -ForegroundColor Green

            # Find and copy .tfvars files to the working directory
            Get-ChildItem -Path . -Filter *global.auto.tfvars -Recurse | ForEach-Object {
                $sourceFile = $_.FullName
                $destinationFile = Join-Path -Path $WorkingDirectory -ChildPath $_.Name
                Copy-Item -Path $sourceFile -Destination $destinationFile

                Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Successfully copied file '$sourceFile' to '$destinationFile'." -ForegroundColor Green
            }

            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Successfully copied all .global.auto.tfvars files to '$WorkingDirectory'." -ForegroundColor Green

        }
        else
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Failed to clone the repo '$SharedVarsRepo'."
            exit 1
        }

        # Change directory back to the original working directory
        Set-Location -Path $WorkingDirectory
    }


    function Select-TerraformWorkspace
    {
        param (
            [string]$Workspace
        )

        # Try to create a new workspace or select it if it already exists
        terraform workspace select -or-create=true $Workspace
        if ($LASTEXITCODE -eq 0)
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Successfully created and selected the Terraform workspace '$Workspace'." -ForegroundColor Green
            return $Workspace
        }
        else
        {

            throw "[$( $MyInvocation.MyCommand.Name )] Error: Failed to select the existing Terraform workspace '$Workspace'."
            exit 1

        }
    }

    function Invoke-TerraformInit
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$BackendStorageSubscriptionId,

            [Parameter(Mandatory = $true)]
            [string]$BackendStorageAccountName,

            [Parameter(Mandatory = $true)]
            [string]$Workspace,

            [Parameter(Mandatory = $true)]
            [string]$WorkingDirectory,

            [Parameter(Mandatory = $true)]
            [bool]$CloneSharedVars,

            [Parameter(Mandatory = $true)]
            [string]$SharedVarsRepo
        )

        Begin {
            # Initial setup and variable declarations
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Initializing Terraform..."
            $BackendStorageAccountBlobContainerName = $BackendStorageAccountBlobContainerName
            $BackendStorageAccountRgName = $BackendStorageAccountRgName

            Ensure-AzStorageContainer `
                -StorageAccountSubscription $BackendStorageSubscriptionId `
                -StorageAccountName $BackendStorageAccountName `
                -ResourceGroupName $BackendStorageAccountRgName `
                -ContainerName $BackendStorageAccountBlobContainerName
        }

        Process {
            try
            {
                # Change to the specified working directory
                Set-Location -Path $WorkingDirectory

                if (Test-Path -Path "${WorkingDirectory}/.terraform")
                {
                    Remove-Item -Force .terraform -Recurse -Confirm:$false
                }

                if ($CloneSharedVars -eq $true)
                {
                    Clone-SharedVars -WorkingDirectory $WorkingDirectory -SharedVarsRepo $SharedVarsRepo
                }
                else
                {
                    throw "[$( $MyInvocation.MyCommand.Name )] Error: Failed to select the existing Terraform workspace '$Workspace'."
                    exit 1
                }

                # Construct the backend config parameters
                $backendConfigParams = @(
                    "-backend-config=subscription_id=$BackendStorageSubscriptionId",
                    "-backend-config=storage_account_name=$BackendStorageAccountName",
                    "-backend-config=resource_group_name=$BackendStorageAccountRgName",
                    "-backend-config=container_name=$BackendStorageAccountBlobContainerName"
                    "-backend-config=key=$BackendStorageAccountBlobStatefileName"
                )

                Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Backend config params are: $backendConfigParams"

                # Run terraform init with the constructed parameters
                terraform init @backendConfigParams | Out-Host
                Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Last exit code is $LASTEXITCODE"
                # Check if terraform init was successful
                if ($LASTEXITCODE -ne 0)
                {
                    throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform init failed with exit code $LASTEXITCODE"
                    exit 1
                }
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform init failed with exception: $_"
                exit 1
            }
        }

        End {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Terraform initialization completed."
        }
    }


    function Invoke-TerraformPlan
    {
        [CmdletBinding()]
        param (
            [string]$WorkingDirectory = $WorkingDirectory,
            [bool]$RunTerraformPlan = $true
        )

        Begin {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Begin: Initializing Terraform Plan in $WorkingDirectory"
        }

        Process {
            if ($RunTerraformPlan)
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Terraform Plan in $WorkingDirectory" -ForegroundColor Green
                try
                {
                    Set-Location -Path $WorkingDirectory
                    terraform plan -out tfplan.plan | Out-Host

                    if (Test-Path tfplan.plan)
                    {
                        terraform show -json tfplan.plan | Tee-Object -FilePath tfplan.json | Out-Null
                    }
                    else
                    {
                        throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform plan file not created"
                        exit 1
                    }
                }
                catch
                {
                    throw "[$( $MyInvocation.MyCommand.Name )] Error encountered during Terraform plan: $_"
                    exit 1
                }
            }
        }

        End {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] End: Completed Terraform Plan execution"
        }
    }



    # Function to execute Terraform plan for destroy
    function Invoke-TerraformPlanDestroy
    {
        [CmdletBinding()]
        param (
            [string]$WorkingDirectory = $WorkingDirectory,
            [bool]$RunTerraformPlanDestroy = $true
        )

        Begin {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Begin: Preparing to execute Terraform Plan Destroy in $WorkingDirectory"
        }

        Process {
            if ($RunTerraformPlanDestroy)
            {
                try
                {
                    Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Terraform Plan Destroy in $WorkingDirectory" -ForegroundColor Yellow
                    Set-Location -Path $WorkingDirectory
                    terraform plan -destroy -out tfplan.plan | Out-Host

                    if (Test-Path tfplan.plan)
                    {
                        terraform show -json tfplan.plan | Tee-Object -FilePath tfplan.json | Out-Null
                    }
                    else
                    {
                        throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform plan file not created"
                        exit 1
                    }
                }
                catch
                {
                    throw  "[$( $MyInvocation.MyCommand.Name )] Error encountered during Terraform Plan Destroy: $_"
                    exit 1
                }
            }
            else
            {
                throw  "[$( $MyInvocation.MyCommand.Name )] Error encountered during Terraform Plan Destroy or internal script error occured: $_"
                exit 1
            }
        }

        End {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] End: Completed execution of Terraform Plan Destroy"
        }
    }

    # Function to execute Terraform apply
    function Invoke-TerraformApply
    {
        if ($RunTerraformApply -eq $true)
        {
            try
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Terraform Apply in $WorkingDirectory" -ForegroundColor Yellow
                if (Test-Path tfplan.plan)
                {
                    terraform apply -auto-approve tfplan.plan | Out-Host
                }
                else
                {
                    throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform plan file not present for terraform apply"
                    return $false
                }
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform Apply failed"
                return $false
            }
        }
    }

    # Function to execute Terraform destroy
    function Invoke-TerraformDestroy
    {
        if ($RunTerraformDestroy -eq $true)
        {
            try
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Terraform Destroy in $WorkingDirectory" -ForegroundColor Yellow
                if (Test-Path tfplan.plan)
                {
                    terraform apply -auto-approve tfplan.plan | Out-Host
                }
                else
                {
                    throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform plan file not present for terraform destroy"
                    return $false
                }
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform Destroy failed"
                return $false
            }
        }
    }

    # Convert string parameters to boolean
    $ConvertedRunTerraformInit = Convert-ToBoolean $RunTerraformInit
    $ConvertedRunTerraformPlan = Convert-ToBoolean $RunTerraformPlan
    $ConvertedRunTerraformPlanDestroy = Convert-ToBoolean $RunTerraformPlanDestroy
    $ConvertedRunTerraformApply = Convert-ToBoolean $RunTerraformApply
    $ConvertedRunTerraformDestroy = Convert-ToBoolean $RunTerraformDestroy
    $ConvertedCloneSharedVars = Convert-ToBoolean $CloneSharedVars
    $ConvertedDeletePlanFiles = Convert-ToBoolean $DeletePlanFiles


    # Diagnostic output
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunTerraformInit: $ConvertedRunTerraformInit"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunTerraformPlan: $ConvertedRunTerraformPlan"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunTerraformPlanDestroy: $ConvertedRunTerraformPlanDestroy"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunTerraformApply: $ConvertedRunTerraformApply"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunTerraformDestroy: $ConvertedRunTerraformDestroy"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: DebugMode: $DebugMode"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedDeletePlanFiles: $ConvertedDeletePlanFiles"


    # Chicken and Egg checker
    if (-not$ConvertedRunTerraformInit -and ($ConvertedRunTerraformPlan -or $ConvertedRunTerraformPlanDestroy -or $ConvertedRunTerraformApply -or $ConvertedRunTerraformDestroy))
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform init must be run before executing plan, plan destroy, apply, or destroy commands."
        exit 1
    }

    if ($ConvertedRunTerraformPlan -eq $true -and $ConvertedRunTerraformPlanDestroy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: Both Terraform Plan and Terraform Plan Destroy cannot be true at the same time"
        exit 1
    }

    if ($ConvertedRunTerraformApply -eq $true -and $ConvertedRunTerraformDestroy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: Both Terraform Apply and Terraform Destroy cannot be true at the same time"
        exit 1
    }

    if ($ConvertedRunTerraformPlan -eq $false -and $ConvertedRunTerraformApply -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: You must run terraform plan and terraform apply together to use this script"
        exit 1
    }

    if ($ConvertedRunTerraformPlanDestroy -eq $false -and $ConvertedRunTerraformDestroy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: You must run terraform plan destroy and terraform destroy together to use this script"
        exit 1
    }

    try
    {
        # Initial Terraform setup
        Test-TenvExists
        Test-TerraformExists

        $WorkingDirectory = (Get-Location).Path

        $Workspace = Get-GitBranch
        if (-not$Workspace)
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Failed to determine Git branch for workspace."
        }

        # Terraform Init and Workspace Selection
        if ($ConvertedRunTerraformInit)
        {
            Invoke-TerraformInit `
                -WorkingDirectory $WorkingDirectory `
                -CloneSharedVars $ConvertedCloneSharedVars `
                -SharedVarsRepo $SharedVarsRepo `
                -BackendStorageAccountName $BackendStorageAccountName `
                -BackendStorageSubscriptionId $BackendStorageSubscriptionId `
                -Workspace $Workspace
            $InvokeTerraformInitSuccessful = ($LASTEXITCODE -eq 0)
        }
        else
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Terraform initialization failed."
        }

        if (-not(Select-TerraformWorkspace -Workspace $Workspace))
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Failed to select Terraform workspace."
        }

        # Conditional execution based on parameters
        if ($InvokeTerraformInitSuccessful -and $ConvertedRunTerraformPlan -and -not$ConvertedRunTerraformPlanDestroyonvRunTerraformPlanDestroy)
        {
            Invoke-TerraformPlan -WorkingDirectory $WorkingDirectory
            $InvokeTerraformPlanSuccessful = ($LASTEXITCODE -eq 0)
        }

        if ($InvokeTerraformInitSuccessful -and $ConvertedRunTerraformPlanDestroy -and -not$ConvertedRunTerraformPlan)
        {
            Invoke-TerraformPlanDestroy -WorkingDirectory $WorkingDirectory
            $InvokeTerraformPlanDestroySuccessful = ($LASTEXITCODE -eq 0)

        }

        if ($InvokeTerraformInitSuccessful -and $ConvertedRunTerraformApply -and $InvokeTerraformPlanSuccessful)
        {
            Invoke-TerraformApply
            $InvokeTerraformApplySuccessful = ($LASTEXITCODE -eq 0)
            if (-not$InvokeTerraformApplySuccessful)
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: An error occured during terraform apply command"
                exit 1
            }
        }

        if ($ConvertedRunTerraformDestroy -and $InvokeTerraformPlanDestroySuccessful)
        {
            Invoke-TerraformDestroy
            $InvokeTerraformDestroySuccessful = ($LASTEXITCODE -eq 0)

            if (-not$InvokeTerraformDestroySuccessful)
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: An error occured during terraform destroy command"
                exit 1
            }
        }
    }
    catch
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: in script execution: $_"
        exit 1
    }

}
catch
{
    throw "[$( $MyInvocation.MyCommand.Name )] Error: An error has occured in the script:  $_"
    exit 1
}

finally
{
    $SharedVarsRepoName = ((Split-Path -Leaf $SharedVarsRepo) -replace '\.git$', '')
    Remove-Item -Force $SharedVarsRepoName -Recurse -Confirm:$false
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Deleted $SharedVarsRepoName"
    Get-ChildItem -Path . -Filter *global.auto.tfvars -Recurse | Remove-Item -Force -Confirm:$false
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Deleted global.auto.tfvars files"

    if ($DeletePlanFiles -eq $true)
    {
        $planFile = "tfplan.plan"
        if (Test-Path $planFile)
        {
            Remove-Item -Path $planFile -Force -ErrorAction Stop
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Deleted $planFile"
        }
        $planJson = "tfplan.json"
        if (Test-Path $planJson)
        {
            Remove-Item -Path $planJson -Force -ErrorAction Stop
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Deleted $planJson"
        }
    }
    Set-Location $CurrentWorkingDirectory
}


