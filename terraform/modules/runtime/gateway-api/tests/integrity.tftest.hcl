mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = <<-YAML
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: unverified-release
      YAML
    }
  }
}
mock_provider "kubernetes" {}

run "reject_unverified_release" {
  command         = plan
  expect_failures = [data.http.release]
}
