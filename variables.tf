variable "location" {
  description = "The location for this resource to be put in"
  type        = string
  default     = "uksouth"
}

variable "name" {
  type        = string
  description = "The name of the resource"
  default     = "hello"
}

variable "rg_name" {
  description = "The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists"
  type        = string
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."
  default     = null
}
