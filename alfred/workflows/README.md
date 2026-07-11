# Alfred Workflows

This directory contains reviewed, importable `.alfredworkflow` archives. The live
Alfred workflow directory remains ignored because it includes caches, bundled
dependencies, and local workflow state.

## Export

Review the workflow first. Do not export a workflow that embeds tokens, API keys,
passwords, private paths, or machine-specific settings.

```shell
fish alfred/export-workflow.fish <workflow-id> <export-name>
```

For example, the local Pomodoro workflow can be exported with:

```shell
fish alfred/export-workflow.fish user.workflow.6E8AFCEC-6AD8-4B67-A2D9-BEAFC0401716 pomo
```

The script rejects unexpected workflow IDs and names, checks text files for common
secret patterns when `rg` is installed, and refuses to overwrite an existing
archive. Its scan is a guardrail, not a substitute for reviewing the workflow.

After reviewing the generated archive, add it to Git:

```shell
git add alfred/workflows/<export-name>.alfredworkflow
```

## Import

On a new Mac, double-click an archive in this directory or use Alfred's workflow
import action. Re-enter any machine-specific configuration in Alfred after import.

## Current Local Inventory

The following local workflows were found when this structure was created. They are
not exported or tracked yet.

| Workflow | Local ID |
| --- | --- |
| Audio Switcher | `user.workflow.071FF99E-43D5-407F-A41F-9CB1523757E1` |
| Banner Be Gone | `user.workflow.07C4DDF5-513C-4067-AD6D-E48A84679520` |
| Movie and TV Show Search | `user.workflow.0C26DDB0-5E7B-427D-9E3D-0A476E1595C9` |
| 1Password | `user.workflow.236CE380-FF0A-4957-9422-2D25F6EBD56D` |
| Pretty JSON | `user.workflow.3D8B7812-1690-4C00-A6EB-CE0CDF40BD58` |
| HEIC to JPEG | `user.workflow.48AD71C1-C3E6-4997-83F2-9E0F94BD55AA` |
| Device Battery | `user.workflow.527BB3B8-6E13-43AE-955F-E5E4990CBE47` |
| Currency Converter | `user.workflow.5F0F1DA4-6E21-435D-8FE0-81A0820EBA33` |
| Utility | `user.workflow.682AE729-0B98-417C-B292-7D4874F41EA8` |
| pomo | `user.workflow.6E8AFCEC-6AD8-4B67-A2D9-BEAFC0401716` |
| Color Picker | `user.workflow.6F97F5B0-A4AF-47AD-8193-D09B2D4AD4D7` |
| System Settings | `user.workflow.820AC883-8ABA-4F39-83C4-B7F017A4AA3A` |
| Tailwind CSS Docs | `user.workflow.88271F0C-27F3-4DA6-A1A2-1B830FDE6C23` |
| BTT | `user.workflow.94B16933-F8C7-4DBC-A470-AFC3C0AC7AA0` |
| Bluetooth Connector | `user.workflow.A00F3D4A-4D20-4564-A348-E437C31BCED7` |
| output: airplay | `user.workflow.AA8CCACE-A87D-490E-8651-9324BEA55A1A` |
| Homebrew | `user.workflow.C5F3979E-15AB-43CF-A205-47F943D12A77` |
| TerminalFinder | `user.workflow.CCECC0A9-25E5-46D8-8553-19C32F1715EC` |
| String multitool | `user.workflow.D7E35B9F-9307-481B-B9D4-C01185175D2F` |
| Emoji search | `user.workflow.E4C30B26-85AD-4044-A214-1201D695D022` |
| Clipboard History Extender | `user.workflow.F0D7F129-3193-4D9A-ACBF-B64501991CB7` |
