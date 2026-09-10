mock_provider "aws" {
  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      url            = "https://app.terraform.io"
      client_id_list = ["aws.workload.identity"]
    }
  }
}

variables {
  # Synthetic account value assembled only for an offline mock, never an inventory.
  oidc_provider_arn = join(":", ["arn", "aws", "iam", "", join("", ["111111", "111111"]), "oidc-provider/app.terraform.io"])
  name_prefix      = "example-hcp"
  hcp              = { organization = "example", project = "core", stack = "runtime", deployment = "test" }
}

run "exact_target_and_phase" {
  command = plan
  assert {
    condition     = jsondecode(aws_iam_role.phase["plan"].assume_role_policy).Statement[0].Condition.StringEquals["app.terraform.io:sub"] == "organization:example:project:core:stack:runtime:deployment:test:operation:plan"
    error_message = "Plan trust must exactly bind the target and phase."
  }
  assert {
    condition     = endswith(jsondecode(aws_iam_role.phase["apply"].assume_role_policy).Statement[0].Condition.StringEquals["app.terraform.io:sub"], ":operation:apply")
    error_message = "Apply must require an apply token."
  }
  assert {
    condition     = jsondecode(aws_iam_role.phase["plan"].assume_role_policy).Statement[0].Condition.StringEquals["app.terraform.io:aud"] == "aws.workload.identity"
    error_message = "Audience must be explicitly restricted."
  }
  assert {
    condition     = aws_iam_role.phase["plan"].name != aws_iam_role.phase["apply"].name
    error_message = "Execution phases must have separate identities."
  }
}

run "disable_new_assumptions" {
  command = plan
  variables { disabled = true }
  assert {
    condition     = jsondecode(aws_iam_role.phase["apply"].assume_role_policy).Statement[0].Effect == "Deny"
    error_message = "Incident mode must deny new role assumptions."
  }
}
