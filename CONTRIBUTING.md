# Contributing to Libre DevOps repositories

Your contributions mean a lot to us, and we welcome the community at every opportunity, whether
you are reporting an issue, reviewing code, proposing a fix, suggesting a feature, or interested
in becoming a maintainer.

## Development happens on GitHub

We use GitHub to host the code, track issues and feature requests, and review pull requests.
The most effective way to propose a change is a pull request following the
[GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow).

## Workflow

1. Fork the repository and branch from `main`.
2. Make your change, keeping it consistent with the
   [Libre DevOps standards](https://libredevops.org/docs/documents).
3. Verify your Terraform: `terraform fmt -check -recursive`, `terraform validate`, `tflint`, and
   a `trivy config` scan. The engine that the action runs is `Invoke-LdoTerraform.ps1`, which
   wraps this lifecycle using the
   [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers) module.
4. For Terraform module repositories, run `Sort-LdoTerraform.ps1` to sort variables and outputs,
   format, and regenerate the `terraform-docs` section of the README from `HEADER.md`.
5. Keep PowerShell clean: PSScriptAnalyzer and the Pester tests under `Tests/` must pass.
6. Follow the naming convention `terraform-${provider}-${purpose}` for module repositories, and
   the [Azure naming convention](https://libredevops.org/docs/documents/azure-naming-convention)
   for resources.

## Pull requests

- Keep changes focused and the history readable.
- Fill in the pull request template, including testing evidence.
- Ensure CI is green: format, validate, lint, scan, and tests all pass before review.

## Reporting issues

Open an issue using the bug report or feature request template. Include versions (terraform,
azurerm, the action, and LibreDevOpsHelpers) and clear reproduction steps.

## Licence

By contributing, you agree that your contributions are licensed under the
[MIT License](./LICENSE).
