# Plan-time tests for the module. The azurerm provider is mocked, so no credentials, no
# features block, and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  resource_groups = [
    {
      name     = "rg-ldo-uks-tst-tmpl-01"
      location = "uksouth"
    },
  ]
}

run "creates_the_resource_group" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this["rg-ldo-uks-tst-tmpl-01"].location == "uksouth"
    error_message = "The resource group should be created in the requested location."
  }

  assert {
    condition     = length(azurerm_resource_group.this) == length(var.resource_groups)
    error_message = "One resource group should be created per list entry."
  }
}

run "tags_default_to_empty" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.this["rg-ldo-uks-tst-tmpl-01"].tags) == 0
    error_message = "tags should default to an empty map when not supplied."
  }
}
