import json
from pathlib import Path
import tempfile
import unittest

from gcp import guard, verify_saved, plan_hashes


class BoundaryTests(unittest.TestCase):
    def setUp(self):
        self.binding = {"gitlab_project_id": "example", "gitlab_namespace_id": "example-group", "deploy_branch": "main"}
        self.env = {"GITLAB_CI": "true", "CI_PROJECT_ID": "example", "CI_PROJECT_NAMESPACE_ID": "example-group",
                    "CI_COMMIT_REF_PROTECTED": "true", "CI_COMMIT_BRANCH": "main", "CI_PIPELINE_SOURCE": "web"}

    def test_trusted_branch(self):
        guard(self.env, self.binding)

    def test_reject_untrusted_execution(self):
        for key, value in [("GITLAB_CI", "false"), ("CI_PROJECT_ID", "fork"), ("CI_PROJECT_NAMESPACE_ID", "other"),
                           ("CI_COMMIT_REF_PROTECTED", "false"), ("CI_COMMIT_BRANCH", "feature"),
                           ("CI_PIPELINE_SOURCE", "merge_request_event"), ("CI_PIPELINE_SOURCE", "parent_pipeline"),
                           ("CI_DEBUG_TRACE", "true")]:
            with self.subTest(key=key, value=value), self.assertRaises(RuntimeError):
                guard(dict(self.env, **{key: value}), self.binding)

    def test_saved_plan_integrity(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for index in range(8):
                (root / (str(index) + ".tfplan")).write_bytes(b"synthetic-plan")
            expected = {"commit": "reviewed", "pipeline": "same-run", "binding": "same-input"}
            context = {"execution": expected, "plans": plan_hashes(root)}
            verify_saved(context, expected, root)
            for key in expected:
                with self.subTest(key=key), self.assertRaises(RuntimeError):
                    verify_saved(context, dict(expected, **{key: "changed"}), root)
            (root / "0.tfplan").write_bytes(b"altered-plan")
            with self.assertRaises(RuntimeError):
                verify_saved(context, expected, root)
            (root / "0.tfplan").unlink()
            with self.assertRaises(RuntimeError):
                verify_saved(context, expected, root)
