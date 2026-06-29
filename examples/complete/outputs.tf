output "ids" {
  description = "Map of resource group name to id."
  value       = module.this.ids
}

output "names" {
  description = "Map of resource group name to name."
  value       = module.this.names
}
