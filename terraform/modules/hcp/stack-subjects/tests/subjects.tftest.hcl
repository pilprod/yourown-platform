variables {
  hcp = { organization = "example", project = "core", stack = "runtime", deployment = "test" }
}

run "exact_phase_subjects" {
  command = plan
  assert {
    condition     = output.subjects.plan == "organization:example:project:core:stack:runtime:deployment:test:operation:plan"
    error_message = "Plan trust must include the complete target and phase."
  }
  assert {
    condition     = output.subjects.apply != output.subjects.plan && endswith(output.subjects.apply, ":operation:apply")
    error_message = "Apply and plan subjects must be distinct."
  }
}

run "reject_wildcard" {
  command = plan
  variables {
    hcp = { organization = "example", project = "core", stack = "*", deployment = "test" }
  }
  expect_failures = [var.hcp]
}

run "reject_delimiter_injection" {
  command = plan
  variables {
    hcp = { organization = "example", project = "core", stack = "runtime:deployment:other", deployment = "test" }
  }
  expect_failures = [var.hcp]
}

run "reject_long_subject" {
  command = plan
  variables {
    hcp = { organization = "example", project = "core", stack = join("", [for n in range(128) : "a"]), deployment = "test" }
  }
  expect_failures = [var.hcp]
}
