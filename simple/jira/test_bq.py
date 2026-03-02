import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent))
import os
import unittest
from unittest.mock import Mock, patch

import bq


class ResolveQueryLocationTests(unittest.TestCase):
    def test_uses_explicit_location_when_set(self):
        client = Mock()
        with patch.dict(os.environ, {"BQ_LOCATION": "US"}, clear=False):
            self.assertEqual(bq.resolve_query_location(client), "US")
        client.get_dataset.assert_not_called()

    def test_uses_dataset_location_when_not_configured(self):
        client = Mock()
        dataset = Mock()
        dataset.location = "europe-west2"
        client.get_dataset.return_value = dataset

        env = {
            "BQ_PROJECT": "demo-proj",
            "BQ_DATASET": "qa_metrics_simple",
        }
        with patch.dict(os.environ, env, clear=True):
            self.assertEqual(bq.resolve_query_location(client), "europe-west2")
            client.get_dataset.assert_called_once_with("demo-proj.qa_metrics_simple")


if __name__ == "__main__":
    unittest.main()
