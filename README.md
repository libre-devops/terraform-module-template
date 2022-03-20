# Run Commmand in Azure VM

Uses the VM agent to run PowerShell scripts (Windows) or shell scripts (Linux) within an Azure VM. It can be used to bootstrap/install software or run administrative tasks.

The module version matches the version of terraform it is intended to work with.

This means this script is purely to bootstrap something where you want a one time execution, e.g. `sudo yum update -y`, or to install a tool or open a firewall port after the VM has been built.

## Tips

- Ensure you always include some form of logging into your script, such as the `--log-file` paramter to `chocolatey`
- Try to create a failure state where you always exit with exit 1 for a failure or exit 0 for success, this will help the module not return false positives.

## Example Usage

### Install cURL (Linux)

```hcl
module "run_command" {
  source   = "./PostInstall"
  location = "US East"
  rg_name  = "myResourceGroup"
  vm_name  = "MyVMName"
  os_type  = "linux"

  command = "touch /it-works.txt && echo 'it works!' >> /it-works.txt && exit 0"
}
```

### Install Chocolatey (Windows)

```hcl
resource "azurerm_resource_group" "vm-rg" {
  name     = "vm-rg"
  location = "UK South"
}

resource "azurerm_windows_virtual_machine" "win_vm" {
  
  name                  = var.vm_name
  resource_group_name   = azurerm_resource_group.vm_rg.name
  location              = azurerm_resource_group.vm_rg.location
  ......
  
module "run_command" {
  source               = "craigthackerx/terraform-azurerm-vm-run-command/PostInstall"
  rg_name              = azurerm_resource_group.win_vm.name
  vm_name              = azurerm_windows_virtual_machine.win_vm.name
  location             = azurerm_resource_group.win_vm.name
  os_type              = "windows"

  command = "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) ; choco install -y git"
}
```

### Install Git (Linux)

```hcl
resource "azurerm_resource_group" "vm-rg" {
  name     = "vm-rg"
  location = "UK West"
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  
  name                  = "MyVM"
  resource_group_name   = azurerm_resource_group.vm_rg.name
  location              = azurerm_resource_group.vm_rg.location
  ......
  

module "run_command" {
  source               = "https://github.com/craigthackerx/terraform-azurerm-vm-run-command/PostInstall"
  rg_name              = azurerm_resource_group.vm-rg.name
  vm_name              = azurerm_linux_virtual_machine.linux_vm.name
  os_type              = "linux"

  command = "apt-get update && apt-get install -y git && exit 0"
}
```

### Install Updates (Windows)

```hcl
module "run_command" {
  source               = "craigthackerx/terraform-azurerm-vm-run-command/PostInstall"
  rg_name              = azurerm_resource_group.main.name
  vm_name              = azurerm_windows_virtual_machine.main.name
  location             = "US West"
  os_type              = "windows"

  command = "Get-WUInstall -MicrosoftUpdate -AcceptAll -IgnoreUserInput -IgnoreReboot ; Install-WindowsFeature -name Web-Server -IncludeManagementTools"
}
```

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_virtual_machine_extension.linux_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) | resource |
| [azurerm_virtual_machine_extension.windows_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) | resource |
| [azurerm_resource_group.target_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_virtual_machine.azure_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_machine) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_command"></a> [command](#input\_command) | A string Command to be executed. | `string` | `""` | no |
| <a name="input_location"></a> [location](#input\_location) | Location of resources | `string` | n/a | yes |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | Specifies the operating system type. | `string` | n/a | yes |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | The name of the resource group. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign to the extension. | `map(any)` | `{}` | no |
| <a name="input_timestamp"></a> [timestamp](#input\_timestamp) | Intended to trigger re-execution of the script when changed. | `string` | `""` | no |
| <a name="input_vm_name"></a> [vm\_name](#input\_vm\_name) | The name of the virtual machine. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | The ID of the VM you use in the module. |
