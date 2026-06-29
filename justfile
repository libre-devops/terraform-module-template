# Libre DevOps Terraform module task runner. Run `just` to list recipes.
#
# Install just with either:
#   brew install just
#   uv tool add rust-just     # then call recipes as: uv run just <recipe>
#
# The recipes wrap the LibreDevOpsHelpers engine functions in PowerShell so local development
# mirrors the libre-devops/terraform-azure action. plan/apply/destroy use the remote azurerm
# backend and perform the same storage firewall "open before, close after" dance the action does,
# reading the state coordinates from the TFSTATE_* environment variables published by the tenant
# bootstrap:
#   export TFSTATE_RESOURCE_GROUP=...  TFSTATE_STORAGE_ACCOUNT=...  TFSTATE_BLOB_CONTAINER=...
# Authenticate first with `az login`. The workspace selects the environment (default dev, or set
# TF_WORKSPACE).

set shell := ["pwsh", "-NoProfile", "-Command"]

workspace := env_var_or_default("TF_WORKSPACE", "dev")

# List available recipes.
default:
    just --list

# Format every Terraform file in place.
fmt:
    terraform fmt -recursive

# Offline quality gates for the module and its examples: format check, validate, tflint, trivy.
validate:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    foreach ($path in @('.', 'examples/minimal', 'examples/complete')) {
        Write-Host "== $path =="
        Invoke-LdoTerraformFmtCheck -CodePath $path
        terraform -chdir=$path init -backend=false -input=false | Out-Null
        Invoke-LdoTerraformValidate -CodePath $path
        Invoke-LdoTfLint -CodePath $path
        Invoke-LdoTrivy -CodePath $path
    }

# Run the native terraform tests (plan-time, mocked provider, no cloud credentials).
test:
    terraform init -backend=false -input=false | Out-Null
    terraform test

# Sort variables/outputs, format, and regenerate the README from HEADER.md.
docs:
    ./Sort-LdoTerraform.ps1 -IncludeExamples

# Plan an example against the remote state. Example: just plan complete
plan stack="complete":
    just _run plan {{ stack }} {{ workspace }}

# Apply an example (plans first). Example: just apply complete
apply stack="complete":
    just _run apply {{ stack }} {{ workspace }}

# Destroy an example. Example: just destroy complete
destroy stack="complete":
    just _run destroy {{ stack }} {{ workspace }}

# Internal: run one Terraform operation against the remote backend with the storage firewall
# opened for this machine and always closed again afterwards, mirroring the action's engine.
_run op stack ws:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Set-LdoTraceContext -Generate

    $rg = $env:TFSTATE_RESOURCE_GROUP
    $sa = $env:TFSTATE_STORAGE_ACCOUNT
    $cn = $env:TFSTATE_BLOB_CONTAINER
    if (-not ($rg -and $sa -and $cn)) {
        throw 'Set TFSTATE_RESOURCE_GROUP, TFSTATE_STORAGE_ACCOUNT and TFSTATE_BLOB_CONTAINER (the values published by the tenant bootstrap).'
    }

    $path = 'examples/{{ stack }}'
    $key = 'terraform-module-template-{{ stack }}.tfstate'
    $added = $false
    try {
        Add-LdoStorageCurrentIpRule -ResourceGroup $rg -StorageAccountName $sa
        $added = $true

        Invoke-LdoTerraformFmtCheck -CodePath $path
        Invoke-LdoTerraformInit -CodePath $path -InitArgs @(
            '-reconfigure',
            "-backend-config=resource_group_name=$rg",
            "-backend-config=storage_account_name=$sa",
            "-backend-config=container_name=$cn",
            "-backend-config=key=$key"
        )
        Invoke-LdoTerraformWorkspaceSelect -CodePath $path -WorkspaceName '{{ ws }}'
        Invoke-LdoTerraformValidate -CodePath $path
        Invoke-LdoTfLint -CodePath $path
        Invoke-LdoTrivy -CodePath $path

        switch ('{{ op }}') {
            'plan' {
                Invoke-LdoTerraformPlan -CodePath $path
            }
            'apply' {
                Invoke-LdoTerraformPlan -CodePath $path
                Invoke-LdoTerraformApply -CodePath $path -SkipApprove
            }
            'destroy' {
                Invoke-LdoTerraformPlanDestroy -CodePath $path
                Invoke-LdoTerraformDestroy -CodePath $path -SkipApprove
            }
        }
    }
    finally {
        if ($added) { Remove-LdoStorageCurrentIpRule -ResourceGroup $rg -StorageAccountName $sa }
    }

# --- Release management -------------------------------------------------------------------
# Tags are semver vX.Y.Z and the Terraform Registry picks them up automatically. For repos that
# use a moving major alias (for example a GitHub Action's v1), move it after release with:
#   just force-push-tag v1

# Create and push an annotated tag. Example: just tag v1.2.3
tag version:
    git tag -a '{{ version }}' -m 'Release {{ version }}'
    git push origin '{{ version }}'

# Bump the latest vX.Y.Z tag and push the new tag. level = patch (default), minor, or major.
increment-tag level="patch":
    #!/usr/bin/env pwsh
    $tags = @(git tag --list | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
    $cur = if ($tags.Count -eq 0) { [version]'0.0.0' } else { ($tags | ForEach-Object { [version]($_.Substring(1)) } | Sort-Object)[-1] }
    switch ('{{ level }}') {
        'major' { $next = "v$($cur.Major + 1).0.0" }
        'minor' { $next = "v$($cur.Major).$($cur.Minor + 1).0" }
        'patch' { $next = "v$($cur.Major).$($cur.Minor).$($cur.Build + 1)" }
        default { throw "level must be patch, minor, or major" }
    }
    git tag -a $next -m "Release $next"
    git push origin $next
    Write-Host "Tagged and pushed $next"

# Create a GitHub release from an existing tag, with auto-generated notes. Example: just release v1.2.3
release version:
    gh release create '{{ version }}' --title '{{ version }}' --generate-notes

# Tag a specific version and release it. Example: just tag-and-release v1.2.3
tag-and-release version:
    #!/usr/bin/env pwsh
    git tag -a '{{ version }}' -m 'Release {{ version }}'
    git push origin '{{ version }}'
    gh release create '{{ version }}' --title '{{ version }}' --generate-notes

# Bump the latest tag, push it, and create a release. level = patch (default), minor, or major.
increment-release level="patch":
    #!/usr/bin/env pwsh
    $tags = @(git tag --list | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
    $cur = if ($tags.Count -eq 0) { [version]'0.0.0' } else { ($tags | ForEach-Object { [version]($_.Substring(1)) } | Sort-Object)[-1] }
    switch ('{{ level }}') {
        'major' { $next = "v$($cur.Major + 1).0.0" }
        'minor' { $next = "v$($cur.Major).$($cur.Minor + 1).0" }
        'patch' { $next = "v$($cur.Major).$($cur.Minor).$($cur.Build + 1)" }
        default { throw "level must be patch, minor, or major" }
    }
    git tag -a $next -m "Release $next"
    git push origin $next
    gh release create $next --title $next --generate-notes
    Write-Host "Released $next"

# Bump, tag, and release in one step (same as increment-release). Example: just increment-tag-and-release minor
increment-tag-and-release level="patch":
    just increment-release {{ level }}

# Force-update a tag to a ref and push it, for example to move a major alias. Example: just force-push-tag v1
force-push-tag tag ref="HEAD":
    git tag -f '{{ tag }}' '{{ ref }}'
    git push -f origin '{{ tag }}'
    @echo "Force-pushed {{ tag }} to {{ ref }}"
