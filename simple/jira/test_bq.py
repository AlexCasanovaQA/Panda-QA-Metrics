import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

_BQ_PATH = Path(__file__).resolve().parent / "bq.py"
_SPEC = importlib.util.spec_from_file_location("jira_bq", _BQ_PATH)
bq = importlib.util.module_from_spec(_SPEC)
assert _SPEC and _SPEC.loader
_SPEC.loader.exec_module(bq)


class ResolveQueryLocationTests(unittest.TestCase):
    def test_uses_explicit_location_when_set(self):
        client = Mock()
        with patch.dict(os.environ, {"BQ_LOCATION": "EU"}, clear=False):
            self.assertEqual(bq.resolve_query_location(client), "EU")
        client.get_dataset.assert_not_called()

    def test_uses_dataset_location_when_not_configured(self):
        client = Mock()
        dataset = Mock()
        dataset.location = "europe-west2"
        client.get_dataset.return_value = dataset

        env = {
            "BQ_PROJECT": "demo-proj",
            "BQ_DATASET": "qa_metrics_simple",
            "BQ_LOCATION": "",
        }
        with patch.dict(os.environ, env, clear=True):
            self.assertEqual(bq.resolve_query_location(client), "europe-west2")
            client.get_dataset.assert_called_once_with("demo-proj.qa_metrics_simple")

    def test_validate_bq_env_allows_missing_location(self):
        env = {
            "BQ_PROJECT": "demo-proj",
            "BQ_DATASET": "qa_metrics_simple",
        }
        with patch.dict(os.environ, env, clear=True):
            self.assertEqual(
                bq.validate_bq_env(),
                {
                    "project": "demo-proj",
                    "dataset": "qa_metrics_simple",
                    "location": "",
                },
            )


if __name__ == "__main__":
    unittest.main()
