param (
    [string]$RunTerraformInit = "true",
    [string]$RunTerraformValidate = "true",
    [string]$RunTerraformPlan = "true",
    [string]$RunTerraformPlanDestroy = "false",
    [string]$RunTerraformApply = "true",
    [string]$RunTerraformDestroy = "false",
    [string]$TerraformInitExtraArgsJson = '["-reconfigure", "-upgrade]',
    [string]$TerraformInitCreateBackendStateFileName = "true",
    [string]$TerraformInitCreateBackendStateFilePrefix = "",
    [string]$TerraformInitCreateBackendStateFileSuffix = "",
    [string]$TerraformPlanExtraArgsJson = '[]',
    [string]$TerraformPlanDestroyExtraArgsJson = '[]',
    [string]$TerraformApplyExtraArgsJson = '[]',
    [string]$TerraformDestroyExtraArgsJson = '[]',
    [string]$InstallTenvTerraform = "true",
    [string]$TerraformVersion = "latest",
    [string]$DebugMode = "false",
    [string]$DeletePlanFiles = "true",
    [string]$InstallCheckov = "false",
    [string]$RunCheckov = "false",
    [string]$CheckovSkipCheck = "CKV2_AZURE_31",
    [string]$CheckovSoftfail = "true",
    [string]$CheckovExtraArgsJson = '[]',
    [string]$TerraformPlanFileName = "tfplan.plan",
    [string]$TerraformDestroyPlanFileName = "tfplan-destroy.plan",
    [string]$TerraformCodeLocation = "examples",
    [string]$TerraformStackToRunJson = '["module-development"]', # JSON format Use 'all' to run 0_, 1_, etc and destroy in reverse order 1_, 0_ etc
    [string]$CreateTerraformWorkspace = "true",
    [string]$TerraformWorkspace = "dev",
    [string]$InstallAzureCli = "false",
    [string]$UseAzureServiceConnection = "true",
    [string]$AttemptAzureLogin = "false",
    [string]$UseAzureClientSecretLogin = "false",
    [string]$UseAzureOidcLogin = "false",
    [string]$UseAzureUserLogin = "true",
    [string]$UseAzureManagedIdentityLogin = "false"
)

$ErrorActionPreference = 'Stop'
$currentWorkingDirectory = (Get-Location).path
$fullTerraformCodePath = Join-Path -Path $currentWorkingDirectory -ChildPath $TerraformCodeLocation

# Get script directory
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

try
{

    Write-Host "→ Installing LibreDevOpsHelpers from PSGallery..."
    Install-Module LibreDevOpsHelpers -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Write-Host "→ Importing LibreDevOpsHelpers..."
    Import-Module LibreDevOpsHelpers -Force
}
catch
{
    Write-Host "Error installing LibreDevOpsHelpers from PSGallery: $( $_.Exception.Message )"
    exit 1
}

# Log that modules were loaded
_LogMessage -Level "INFO" -Message "[$( $MyInvocation.MyCommand.Name )] Modules loaded successfully" -InvocationName "$( $MyInvocation.MyCommand.Name )"

$convertedDebugMode = ConvertTo-Boolean $DebugMode
_LogMessage -Level 'DEBUG' -Message "DebugMode: `"$DebugMode`" → $convertedDebugMode" -InvocationName "$( $MyInvocation.MyCommand.Name )"

# Enable debug mode if DebugMode is set to $true
if ($true -eq $convertedDebugMode)
{
    $Global:DebugPreference = 'Continue'     # module functions see this
    $Env:TF_LOG = 'DEBUG'         # Terraform debug
}
else
{
    $Global:DebugPreference = 'SilentlyContinue'
}

try
{

    $TerraformStackToRun = $TerraformStackToRunJson | ConvertFrom-Json
    if (-not ($TerraformStackToRun -is [System.Collections.IEnumerable]))
    {
        throw "Parsed value of TerraformStackToRunJson is not an array."
    }
    $TerraformInitExtraArgs = $TerraformInitExtraArgsJson | ConvertFrom-Json
    $TerraformPlanExtraArgs = $TerraformPlanExtraArgsJson | ConvertFrom-Json
    $TerraformPlanDestroyExtraArgs = $TerraformPlanDestroyExtraArgsJson | ConvertFrom-Json
    $TerraformApplyExtraArgs = $TerraformApplyExtraArgsJson | ConvertFrom-Json
    $TerraformDestroyExtraArgs = $TerraformDestroyExtraArgsJson | ConvertFrom-Json
    $CheckovExtraArgs = $CheckovExtraArgsJson | ConvertFrom-Json

    $convertedInstallTenvTerraform = ConvertTo-Boolean $InstallTenvTerraform
    _LogMessage -Level 'DEBUG' -Message "InstallTenvTerraform   `"$InstallTenvTerraform`"   → $convertedInstallTenvTerraform"  -InvocationName $MyInvocation.MyCommand.Name

    if ($convertedInstallTenvTerraform)
    {
        Invoke-InstallTenv
        Test-TenvExists
        Invoke-TenvTfInstall -TerraformVersion $TerraformVersion
    }

    Get-InstalledPrograms -Programs @("terraform")

    $convertedUseAzureServiceConnection = ConvertTo-Boolean $UseAzureServiceConnection
    _LogMessage -Level 'DEBUG' -Message "UseAzureServiceConnection:   `"$UseAzureServiceConnection`"   → $convertedUseAzureServiceConnection"  -InvocationName $MyInvocation.MyCommand.Name

    # Convert the string flags to Boolean and log the results at DEBUG level
    $convertedInstallAzureCli = ConvertTo-Boolean $InstallAzureCli
    _LogMessage -Level 'DEBUG' -Message "InstallAzureCli:   `"$InstallAzureCli`"   → $convertedInstallAzureCli"   -InvocationName $MyInvocation.MyCommand.Name

    $convertedAttemptAzureLogin = ConvertTo-Boolean $AttemptAzureLogin
    _LogMessage -Level 'DEBUG' -Message "AttemptAzureLogin:   `"$AttemptAzureLogin`"   → $convertedAttemptAzureLogin"   -InvocationName $MyInvocation.MyCommand.Name

    $convertedUseAzureClientSecretLogin = ConvertTo-Boolean $UseAzureClientSecretLogin
    _LogMessage -Level 'DEBUG' -Message "UseAzureClientSecretLogin:   `"$UseAzureClientSecretLogin`"   → $convertedUseAzureClientSecretLogin"   -InvocationName $MyInvocation.MyCommand.Name

    $convertedUseAzureOidcLogin = ConvertTo-Boolean $UseAzureOidcLogin
    _LogMessage -Level 'DEBUG' -Message "UseAzureOidcLogin:           `"$UseAzureOidcLogin`"           → $convertedUseAzureOidcLogin"           -InvocationName $MyInvocation.MyCommand.Name

    $convertedUseAzureUserLogin = ConvertTo-Boolean $UseAzureUserLogin
    _LogMessage -Level 'DEBUG' -Message "UseAzureUserLogin:           `"$UseAzureUserLogin`"           → $convertedUseAzureUserLogin"           -InvocationName $MyInvocation.MyCommand.Name

    $convertedUseAzureManagedIdentityLogin = ConvertTo-Boolean $UseAzureManagedIdentityLogin
    _LogMessage -Level 'DEBUG' -Message "UseAzureManagedIdentityLogin: `"$UseAzureManagedIdentityLogin`" → $convertedUseAzureManagedIdentityLogin" -InvocationName $MyInvocation.MyCommand.Name

    $convertedRunTerraformInit = ConvertTo-Boolean $RunTerraformInit
    _LogMessage -Level 'DEBUG' -Message "RunTerraformInit: `"$RunTerraformInit`" → $convertedRunTerraformInit" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedRunTerraformValidate = ConvertTo-Boolean $RunTerraformValiate
    _LogMessage -Level 'DEBUG' -Message "RunTerraformValidate: `"$RunTerraformValidate`" → $convertedRunTerraformValidate" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedTerraformInitCreateBackendStateFileName = ConvertTo-Boolean $TerraformInitCreateBackendStateFileName
    _LogMessage -Level 'DEBUG' -Message "TerraformInitCreateBackendStateFileName: `"$TerraformInitCreateBackendStateFileName`" → $convertedTerraformInitCreateBackendStateFileName" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedTerraformInitCreateBackendStateFilePrefix = ConvertTo-Null $TerraformInitCreateBackendStateFilePrefix
    _LogMessage -Level 'DEBUG' -Message "TerraformInitCreateBackendStateFilePrefix: `"$TerraformInitCreateBackendStateFilePrefix`" → $convertedTerraformInitCreateBackendStateFilePrefix" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedTerraformInitCreateBackendStateFileSuffix = ConvertTo-Null $TerraformInitCreateBackendStateFileSuffix
    _LogMessage -Level 'DEBUG' -Message "TerraformInitCreateBackendStateFileSuffix: `"$TerraformInitCreateBackendStateFilePrefix`" → $convertedTerraformInitCreateBackendStateFileSuffix" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedRunTerraformPlan = ConvertTo-Boolean $RunTerraformPlan
    _LogMessage -Level 'DEBUG' -Message "RunTerraformPlan: `"$RunTerraformPlan`" → $convertedRunTerraformPlan" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedRunTerraformPlanDestroy = ConvertTo-Boolean $RunTerraformPlanDestroy
    _LogMessage -Level 'DEBUG' -Message "RunTerraformPlanDestroy: `"$RunTerraformPlanDestroy`" → $convertedRunTerraformPlanDestroy" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedRunTerraformApply = ConvertTo-Boolean $RunTerraformApply
    _LogMessage -Level 'DEBUG' -Message "RunTerraformApply: `"$RunTerraformApply`" → $convertedRunTerraformApply" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedRunTerraformDestroy = ConvertTo-Boolean $RunTerraformDestroy
    _LogMessage -Level 'DEBUG' -Message "RunTerraformDestroy: `"$RunTerraformDestroy`" → $convertedRunTerraformDestroy" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedDeletePlanFiles = ConvertTo-Boolean $DeletePlanFiles
    _LogMessage -Level 'DEBUG' -Message "DeletePlanFiles: `"$DeletePlanFiles`" → $convertedDeletePlanFiles" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedInstallCheckov = ConvertTo-Boolean $InstallCheckov
    _LogMessage -Level 'DEBUG' -Message "InstallCheckov: `"$InstallCheckov`" → $convertedRunCheckov" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedRunCheckov = ConvertTo-Boolean $RunCheckov
    _LogMessage -Level 'DEBUG' -Message "RunCheckov: `"$RunCheckov`" → $convertedRunCheckov" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedCheckovSoftfail = ConvertTo-Boolean $CheckovSoftfail
    _LogMessage -Level 'DEBUG' -Message "CheckovSoftfail: `"$CheckovSoftfail`" → $convertedCheckovSoftfail" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    $convertedCreateTerraformWorkspace = ConvertTo-Boolean $CreateTerraformWorkspace
    _LogMessage -Level 'DEBUG' -Message "CreateTerraformWorkspace: `"$CreateTerraformWorkspace`" → $convertedCreateTerraformWorkspace" -InvocationName "$( $MyInvocation.MyCommand.Name )"

    if ($convertedAttemptAzureLogin -and $convertedUseAzureServiceConnection)
    {
        $msg = "This script doesn't support the use of both authentication mechanism. Setting AzureCliLogin to false because of this."
        _LogMessage -Level 'WARN' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        $convertedAttemptAzureLogin = $false
    }

    # ── Chicken-and-egg / mutual exclusivity checks ───────────────────────────────

    if (-not $convertedRunTerraformInit -and (
    $convertedRunTerraformPlan -or
            $convertedRunTerraformPlanDestroy -or
            $convertedRunTerraformApply -or
            $convertedRunTerraformDestroy))
    {
        $msg = 'Terraform init must be run before plan / apply / destroy operations.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if ($convertedRunTerraformPlan -and $convertedRunTerraformPlanDestroy)
    {
        $msg = 'Both Terraform Plan and Terraform Plan-Destroy cannot be true at the same time.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if ($convertedRunTerraformApply -and $convertedRunTerraformDestroy)
    {
        $msg = 'Both Terraform Apply and Terraform Destroy cannot be true at the same time.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if (-not $convertedRunTerraformPlan -and $convertedRunTerraformApply)
    {
        $msg = 'You must run terraform **plan** together with **apply** when using this script.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if (-not $convertedRunTerraformPlanDestroy -and $convertedRunTerraformDestroy)
    {
        $msg = 'You must run terraform **plan destroy** together with **destroy** when using this script.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }


    $processedStacks = @()
    try
    {
        if ($convertedInstallAzureCli -and $convertedAttemptAzureLogin)
        {
            _LogMessage -Level 'INFO' -Message "Installing Azure CLI…" -InvocationName $MyInvocation.MyCommand.Name

            Invoke-InstallAzureCli
        }

        if ($convertedInstallCheckov -and $convertedRunCheckov)
        {
            _LogMessage -Level 'INFO' -Message "Installing Checkov…" -InvocationName $MyInvocation.MyCommand.Name

            Invoke-InstallCheckov
        }

        if ($convertedAttemptAzureLogin)
        {
            Get-InstalledPrograms -Programs @("az")

            Connect-AzureCli `
            -UseClientSecret $convertedUseAzureClientSecretLogin `
            -UseOidc $convertedUseAzureOidcLogin `
            -UseUserDeviceCode $convertedUseAzureUserLogin `
            -UseManagedIdentity $convertedUseAzureManagedIdentityLogin
        }

        $stackFolders = Get-TerraformStackFolders `
                    -CodeRoot $fullTerraformCodePath `
                    -StacksToRun $TerraformStackToRun

        # ──────────────────── REVERSE execution order for destroys ────────────────
        if ($convertedRunTerraformPlanDestroy -or $convertedRunTerraformDestroy) {
            _LogMessage -Level 'DEBUG' -Message "Begin reverse‐order logic for destroy" -InvocationName $MyInvocation.MyCommand.Name
            _LogMessage -Level 'DEBUG' -Message "Original stackFolders: $($stackFolders -join ', ')" -InvocationName $MyInvocation.MyCommand.Name

            # Pick out those folders whose name starts with digits_, sort them descending by that leading number
            $numericFolders = $stackFolders |
                    Where-Object { ($_ -split '[\\/]+')[-1] -match '^\d+_' } |
                    Sort-Object { [int](($_ -split '[\\/]+')[-1] -replace '^(\d+)_.*','$1') } -Descending

            # Everything else stays in original order
            $otherFolders = $stackFolders | Where-Object { $_ -notin $numericFolders }

            # Recombine
            $stackFolders = $numericFolders + $otherFolders

            _LogMessage -Level 'DEBUG' -Message "Reordered stackFolders: $($stackFolders -join ', ')" -InvocationName $MyInvocation.MyCommand.Name
        }


        foreach ($folder in $stackFolders)
        {
            $processedStacks += $folder
            _LogMessage -Level 'INFO' -Message "Resolved stack folders: $( $stackFolders -join ', ' )" -InvocationName $MyInvocation.MyCommand.Name

            # terraform fmt – always safe
            Invoke-TerraformFmtCheck  -CodePath $folder

            # ── INIT ──────────────────────────────────────────────────────────────
            if ($convertedRunTerraformInit)
            {
                if ($convertedTerraformInitCreateBackendStateFileName)
                {
                    Invoke-TerraformInit `
                        -CodePath $folder `
                        -InitArgs $TerraformInitExtraArgs `
                        -CreateBackendKey $convertedTerraformInitCreateBackendStateFileName `
                        -StackFolderName $folder `
                        -BackendKeyPrefix $convertedTerraformInitCreateBackendStateFilePrefix `
                        -BackendKeySuffix $convertedTerraformInitCreateBackendStateFileSuffix
                }
                else
                {
                    Invoke-TerraformInit `
                        -CodePath $folder `
                        -InitArgs $TerraformInitExtraArgs
                }
            }

            # workspace (needs an init first)
            if ($convertedRunTerraformInit -and
                    $convertedCreateTerraformWorkspace -and
                    -not [string]::IsNullOrWhiteSpace($TerraformWorkspace))
            {

                Invoke-TerraformWorkspaceSelect -CodePath $folder -WorkspaceName $TerraformWorkspace
            }

            # ── VALIDATE ──────────────────────────────────────────────────────────
            if ($convertedRunTerraformInit -and $convertedRunTerraformValidate)
            {
                Invoke-TerraformValidate -CodePath $folder
            }

            # ── PLAN / PLAN-DESTROY ───────────────────────────────────────────────
            if ($convertedRunTerraformPlan)
            {
                Invoke-TerraformPlan -CodePath $folder -PlanArgs $TerraformPlanExtraArgs -PlanFile $TerraformPlanFileName
            }
            elseif ($convertedRunTerraformPlanDestroy)
            {
                Invoke-TerraformPlanDestroy -CodePath $folder -PlanArgs $TerraformPlanDestroyExtraArgs -PlanFile $TerraformDestroyPlanFileName
            }

            # JSON + Checkov need a plan file
            if ($convertedRunTerraformPlan -or $convertedRunTerraformPlanDestroy)
            {

                if ($convertedRunTerraformPlan)
                {
                    $TfPlanFileName = $TerraformPlanFileName
                }

                if ($convertedRunTerraformPlanDestroy)
                {
                    $TfPlanFileName = $TerraformDestroyPlanFileName
                }

                if ($convertedRunCheckov -and $convertedRunTerraformPlan)
                {
                    Convert-TerraformPlanToJson -CodePath $folder -PlanFile $TfPlanFileName

                    Invoke-Checkov `
                        -CodePath           $folder `
                        -CheckovSkipChecks  $CheckovSkipCheck `
                        -ExtraArgs          $CheckovExtraArgs `
                        -SoftFail:          $convertedCheckovSoftfail
                }
            }

            # ── APPLY / DESTROY ───────────────────────────────────────────────────
            if ($convertedRunTerraformApply)
            {
                Invoke-TerraformApply -CodePath $folder -SkipApprove -ApplyArgs $TerraformApplyExtraArgs
            }
            elseif ($convertedRunTerraformDestroy)
            {
                Invoke-TerraformDestroy -CodePath $folder -SkipApprove -DestroyArgs $TerraformDestroyExtraArgs
            }
        }

    }
    catch
    {
        _LogMessage -Level 'ERROR' -Message "Script execution error: $( $_.Exception.Message )" -InvocationName $MyInvocation.MyCommand.Name
        throw
    }
}
catch
{
    _LogMessage -Level "ERROR" -Message "Error: $( $_.Exception.Message )" -InvocationName "$( $MyInvocation.MyCommand.Name )"
    exit 1
}

finally
{
    if ($convertedDeletePlanFiles)
    {

        $patterns = @(
            $TfPlanFileName,
            "${TfPlanFileName}.json",
            "${TfPlanFileName}-destroy.tfplan",
            "${TfPlanFileName}-destroy.tfplan.json"
        )

        foreach ($folder in $processedStacks)
        {
            foreach ($pat in $patterns)
            {

                $file = Join-Path $folder $pat
                if (Test-Path $file)
                {
                    try
                    {
                        Remove-Item $file -Force -ErrorAction Stop
                        _LogMessage -Level DEBUG -Message "Deleted $file" `
                                    -InvocationName $MyInvocation.MyCommand.Name
                    }
                    catch
                    {
                        _LogMessage -Level WARN -Message "Failed to delete $file – $( $_.Exception.Message )" `
                                    -InvocationName $MyInvocation.MyCommand.Name
                    }
                }
                else
                {
                    _LogMessage -Level DEBUG -Message "No file to delete: $file" `
                                -InvocationName $MyInvocation.MyCommand.Name
                }
            }
        }
    }
    else
    {
        _LogMessage -Level DEBUG -Message 'DeletePlanFiles is false – leaving plan files in place.' `
                    -InvocationName $MyInvocation.MyCommand.Name
    }

    if ($convertedUseAzureUserLogin -and $convertedAttemptAzureLogin)
    {
        Disconnect-AzureCli -IsUserDeviceLogin $true
    }

    $Env:TF_LOG = $null
    Set-Location $currentWorkingDirectory
}
