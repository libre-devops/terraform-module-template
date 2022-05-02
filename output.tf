output "sa_id" {
  value       = azurerm_storage_account.sa.id
  description = "The ID of the storage account"
}

output "sa_name" {
  value       = azurerm_storage_account.sa.name
  description = "The name of the storage account"
}

output "sa_primary_access_key" {
  value       = azurerm_storage_account.sa.primary_access_key
  description = "The primary access key of the storage account"
  sensitive   = true
}

output "sa_primary_blob_endpoint" {
  value       = azurerm_storage_account.sa.primary_blob_endpoint
  description = "The primary blob endpoint of the storage account"
}

output "sa_primary_connection_string" {
  value       = azurerm_storage_account.sa.primary_blob_connection_string
  description = "The primary blob connection string of the storage account"
  sensitive   = true
}

output "sa_secondary_access_key" {
  value       = azurerm_storage_account.sa.secondary_access_key
  description = "The secondary access key of the storage account"
  sensitive   = true
}
