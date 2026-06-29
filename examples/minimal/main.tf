locals {
  location = lookup(var.regions, var.loc, "uksouth")
}

# Minimal call: one resource group, required inputs only. The environment comes from the
# Terraform workspace (terraform.workspace), not a variable.
module "this" {
  source = "../../"

  resource_groups = [
    {
      name     = "rg-${var.short}-${var.loc}-${terraform.workspace}-tmpl-min"
      location = local.location
    },
  ]
}
