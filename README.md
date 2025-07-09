# oscal-content

This repository serves as a centralized location for managing and storing security compliance content in the [Open Security Controls Assessment Language](https://pages.nist.gov/OSCAL/) (OSCAL) format. The primary purpose of this repository is to manage OSCAL content, with a current focus on Red Hat (RH) products.

## Overview
The repository was initialized by the [complyscribe](https://github.com/complytime/complyscribe). It provides three GitHub Actions, [sync-comp](.github/workflows/sync-comp.yml), [sync-controls](.github/workflows/sync-controls.yml) and [sync-oscal-cac](.github/workflows/sync-oscal-cac.yml). The first two could consume the data of upstream [ComplianceAsCode/content](https://github.com/ComplianceAsCode/content) to generate related OSCAL content. The sync-oscal-cac could sync the OSCAL content updates to [ComplianceAsCode/content](https://github.com/ComplianceAsCode/content). It is paired with the CI [sync-cac-oscal](https://github.com/ComplianceAsCode/content/blob/master/.github/workflows/sync-cac-oscal.yml) which could sync the CAC content updates to OSCAL content. The `sync-oscal-cac` and `sync-cac-oscal` are designed for a bi-directional synchronization workflow that allows both projects to consume updates from each other.

## How do the CIs sync content between CAC and OSCAL work
> WARNING: The CI systems are currently in development. The user experience will be refined as we gather feedback from ongoing use.
### Content Transformation: CAC to OSCAL
The `sync-cac-oscal` workflow handles the transformation from ComplianceAsCode/content into the OSCAL format. This process is powered by the `complyscribe` command-line tool.

The workflow operates in several stages:

- **Detect Changes:** The workflow first identifies relevant updates in the source content directories (controls, profiles, rules, and vars).

- **Prepare for Transformation:** It gathers the necessary arguments required by the Complyscribe CLI.

- **Transform Content:** It then runs `complyscribe` to convert the source files into their corresponding OSCAL formats.

- **Propose Updates:** Finally, the workflow automatically creates a pull request with the newly generated OSCAL content, making it available for review and merging.

As a recent example of a successful [run](https://github.com/ComplianceAsCode/content/actions/runs/15688668981/job/44198205023), the merge of ComplianceAsCode/content PR [#13580](https://github.com/ComplianceAsCode/content/pull/13580) triggered this workflow, which in turn automatically created oscal-content PR [#28](https://github.com/ComplianceAsCode/oscal-content/pull/28) to sync the changes.

### Content Transformation: OSCAL to CAC
The `sync-oscal-cac` workflow handles the reverse synchronization, ensuring that updates to OSCAL content are reflected back in the ComplianceAsCode/content repository.

This workflow is triggered upon the merge of a pull request containing OSCAL file changes and operates as follows:

- **Detect OSCAL Updates:** The workflow identifies which OSCAL files (catalogs, profiles, and component-definitions) were updated.

- **Sync with ComplyScribe:** It calls the Complyscribe CLI to transform the OSCAL updates back into the standard format for controls and product profiles.

- **Create Upstream PR:** The workflow automatically creates a new pull request in the ComplianceAsCode/content repository.

As a recent example of a successful [run](https://github.com/ComplianceAsCode/oscal-content/actions/runs/16161128581/job/45612912892), the PR [#49](https://github.com/ComplianceAsCode/oscal-content/pull/49) triggered this workflow, generated a ComplianceAsCode/content PR [#13680](https://github.com/ComplianceAsCode/content/pull/13680) to contribute the changes back to CAC.

## Tooling
We utilize ComplyScribe to help author and manage the OSCAL content, ensuring it adheres to the required standards and formats.

[Learn more about ComplyScribe](https://github.com/complytime/complyscribe)

## Contributing

**Authoring Content:** Maintainers can contribute by authoring or editing OSCAL content files in a forked repository and then opening a pull request. Once the pull request is reviewed and merged, the sync-oscal-cac synchronization workflow will be triggered automatically.
