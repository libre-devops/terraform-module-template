# Rename this to match the resources your module manages. The list(object) pattern keeps the
# interface stable: new optional attributes can be added with optional() defaults without
# breaking existing callers.
variable "resource_groups" {
  description = "List of resource groups to create."
  type = list(object({
    name     = string
    location = string
    tags     = optional(map(string), {})
  }))
  default = []

  validation {
    condition     = alltrue([for rg in var.resource_groups : length(rg.name) > 0])
    error_message = "Each resource_groups[*].name must be a non-empty string."
  }
}
