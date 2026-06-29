# Replace these with the resources your module manages. The placeholder creates resource groups
# from a list(object), keyed into a map for a stable for_each (never count for named resources).
# Keep to the standard: resources in main.tf only, "this" as the label, for_each over a map.
locals {
  resource_group_map = { for rg in var.resource_groups : rg.name => rg }
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_group_map

  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags
}
