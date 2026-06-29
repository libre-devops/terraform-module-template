locals {
  location = lookup(var.regions, var.loc, "uksouth")

  tags = {
    environment = terraform.workspace
    application = "terraform-module-template"
    managedBy   = "terraform"
  }
}

# Complete call: multiple resource groups with tags, demonstrating the list(object) interface.
# The environment comes from the Terraform workspace (terraform.workspace), not a variable.
module "this" {
  source = "../../"

  resource_groups = [
    {
      name     = "rg-${var.short}-${var.loc}-${terraform.workspace}-tmpl-cmp-01"
      location = local.location
      tags     = local.tags
    },
    {
      name     = "rg-${var.short}-${var.loc}-${terraform.workspace}-tmpl-cmp-02"
      location = local.location
      tags     = local.tags
    },
  ]
}
