```hcl
module "plan" {
  source = "registry.terraform.io/libre-devops/service-plan/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags
  
  app_service_plan_name          = "plan-${var.short}-${var.loc}-${terraform.workspace}-01"
  add_to_app_service_environment = false
  
  os_type  = "Linux"
  sku_name = "Y1"
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
| [azurerm_service_plan.plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_to_app_service_environment"></a> [add\_to\_app\_service\_environment](#input\_add\_to\_app\_service\_environment) | Whether or not this app service plan should be added to an app service environment | `bool` | `false` | no |
| <a name="input_app_service_environment_id"></a> [app\_service\_environment\_id](#input\_app\_service\_environment\_id) | If an ASE is used, supply the ID to it here | `string` | `""` | no |
| <a name="input_app_service_plan_name"></a> [app\_service\_plan\_name](#input\_app\_service\_plan\_name) | The name for the App service plan | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure location. | `string` | n/a | yes |
| <a name="input_maximum_elastic_worker_count"></a> [maximum\_elastic\_worker\_count](#input\_maximum\_elastic\_worker\_count) | If ElasticScaleEnabled app service plan is used, the max number of nodes | `number` | `null` | no |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | The OS type of the app service plan | `string` | n/a | yes |
| <a name="input_per_site_scaling"></a> [per\_site\_scaling](#input\_per\_site\_scaling) | Should per site scaling be used? | `bool` | `false` | no |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | Resource group name | `string` | n/a | yes |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | A new SKU name | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of the tags to use on the resources that are deployed with this module. | `map(string)` | <pre>{<br>  "source": "terraform"<br>}</pre> | no |
| <a name="input_zone_balancing_enabled"></a> [zone\_balancing\_enabled](#input\_zone\_balancing\_enabled) | Should the ASP be zone redundant? | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_plan_id"></a> [service\_plan\_id](#output\_service\_plan\_id) | Id of the created App Service Plan |
| <a name="output_service_plan_is_reserved"></a> [service\_plan\_is\_reserved](#output\_service\_plan\_is\_reserved) | If the instance is reserved |
| <a name="output_service_plan_kind"></a> [service\_plan\_kind](#output\_service\_plan\_kind) | The kind of the plan |
| <a name="output_service_plan_location"></a> [service\_plan\_location](#output\_service\_plan\_location) | Azure location of the created App Service Plan |
| <a name="output_service_plan_name"></a> [service\_plan\_name](#output\_service\_plan\_name) | Name of the created App Service Plan |
