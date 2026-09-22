# Protected billing budget

This narrow module preserves a monthly project-filtered budget with explicit currency, mixed actual/forecast thresholds and Terraform `prevent_destroy`. It creates no project or billing association. Inputs contain no deployment defaults; threshold notifications are not a spend cap.

The reviewed Project Factory budget submodule 18.3.0 cannot express mixed spend bases and explicit currency. Google Cloud Foundation Fabric billing-account v58.0.0 handles those fields but lacks resource destroy protection. A wrapper cannot add lifecycle protection inside a child module, so this single-resource implementation is the recorded upstream gap.

References: [Project Factory inputs](https://github.com/terraform-google-modules/terraform-google-project-factory/blob/v18.3.0/modules/budget/variables.tf), [Fabric budgets](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v58.0.0/modules/billing-account). Reassess the exception when upstream lifecycle support changes.

Validate locally with the pinned provider and synthetic mock tests; live billing permissions and notification delivery require private acceptance. Removing the entire owning component also removes its configuration guard: review any component/module removal as a potentially destructive operation.
