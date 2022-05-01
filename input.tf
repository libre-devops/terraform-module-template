variable "access_tier" {
  type        = string
  description = "The access tier for the storage account, e.g hot"
}

variable "account_tier" {
  type        = string
  description = "The account tier of the storage account"
  default     = "Standard"
}

variable "allow_nested_items_to_be_public" {
  type        = bool
  description = "Whether nested blobs can be set to public from a private top level container"
  default     = false
}

variable "container_delete_retention_policy" {
  type        = map(any)
  description = "Are container delete retention policies needed? set variable to with a non empty value to use"
  default     = {}
}

variable "custom_domain" {
  type        = map(any)
  description = "Are customs domain needed? set variable to with a non empty value to use"
  default     = {}
}

variable "customer_managed_key" {
  type        = map(any)
  description = "Are customer managed needed? set variable to with a non empty value to use"
  default     = {}
}

variable "delete_retention_policy" {
  type        = map(any)
  description = "Are delete retention policies needed? set variable to with a non empty value to use"
  default     = {}
}

variable "enable_https_traffic_only" {
  type        = bool
  description = "Whether only HTTPS traffic is allowed"
  default     = true
}

variable "identity_ids" {
  description = "Specifies a list of user managed identity ids to be assigned to the VM."
  type        = list(string)
  default     = []
}

variable "identity_type" {
  description = "The Managed Service Identity Type of this Virtual Machine."
  type        = string
  default     = ""
}

variable "infrastructure_encryption_enabled" {
  type        = bool
  description = "Whether infrastructure encryption is enabled, default is false"
  default     = false
}

variable "is_hns_enabled" {
  type        = bool
  description = "Whehter HNS is enabled or not, default is false"
  default     = false
}

variable "large_file_share_enabled" {
  type        = bool
  description = "Whether large file transfers are enabled for storage account, default is false"
  default     = false
}

variable "location" {
  description = "The location for this resource to be put in"
  type        = string
}

variable "min_tls_version" {
  type        = string
  description = "The minimum TLS version for the storage account, default is TLS1_2"
  default     = "TLS1_2"
}

variable "network_rules" {
  type        = map(any)
  description = "Are network rules needed? set variable to with a non empty value to use"
  default     = {}
}

variable "nfsv3_enabled" {
  type        = bool
  description = "Whether nfsv3 is enabled, default is false"
  default     = "false"
}

variable "queue_encryption_key_type" {
  type        = string
  description = "The type of queue encryption key, default is Service"
  default     = "Service"
}

variable "replication_type" {
  type        = string
  description = "The replication type for the storage account"
  default     = "LRS"
}

variable "retention_policy" {
  type        = map(any)
  description = "Are retention policy settings needed? set variable to with a non empty value to use"
  default     = {}
}

variable "rg_name" {
  description = "The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists"
  type        = string
  validation {
    condition     = length(var.rg_name) > 1 && length(var.rg_name) <= 24
    error_message = "Resource group name is not valid."
  }
}

variable "share_properties" {
  type        = map(any)
  description = "Are share properties settings needed? set variable to with a non empty value to use"
  default     = {}
}

variable "shared_access_keys_enabled" {
  type        = bool
  description = "Whether shared access keys a.k.a storage keys are enabled"
  default     = true
}

variable "smb" {
  type        = map(any)
  description = "Are smb settings needed? set variable to with a non empty value to use"
  default     = {}
}

variable "storage_account_name" {
  type        = string
  description = "The name of the storage account"
}

variable "storage_account_properties" {
  type        = any
  description = "Variable used my module to export dynamic block values"
}

variable "table_encryption_key_type" {
  type        = string
  description = "The type of table encryption key, default is Service"
  default     = "Service"
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."

  default = {
    source = "terraform"
  }
}
