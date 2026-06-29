# check blocks run after every plan and apply and emit a warning (without blocking) when an
# invariant is violated. They are the place to enforce module-wide consistency. Keep at least one
# meaningful check in every module and extend it as the module grows.

# Catches the classic list(object) -> map for_each pitfall: two entries sharing a name silently
# collapse into one, so fewer resources are created than were requested.
check "no_duplicate_resource_group_names" {
  assert {
    condition     = length(azurerm_resource_group.this) == length(var.resource_groups)
    error_message = "resource_groups contains duplicate names; each name must be unique (the for_each map collapses duplicates)."
  }
}

# Example: enforce the Libre DevOps naming convention on created resources. Uncomment and adapt
# the regex per module.
#
# check "resource_group_naming" {
#   assert {
#     condition = alltrue([
#       for rg in azurerm_resource_group.this :
#       can(regex("^rg-[a-z0-9]{2,4}-[a-z]{2,3}-[a-z0-9]+", rg.name))
#     ])
#     error_message = "Resource group names should follow rg-<infix>-<region>-<workspace>... ."
#   }
# }
