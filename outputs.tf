output "ids" {
  description = "Map of resource group name to its id."
  value       = { for k, v in azurerm_resource_group.this : k => v.id }
}

output "names" {
  description = "Map of resource group name to its name."
  value       = { for k, v in azurerm_resource_group.this : k => v.name }
}
