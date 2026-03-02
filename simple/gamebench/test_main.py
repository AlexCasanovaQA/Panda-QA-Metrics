import pathlib
import sys
import unittest
from unittest import mock

from google.api_core.exceptions import NotFound

# Make `main.py` and `bq.py` importable as top-level modules (as in Cloud Run runtime).
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import main  # noqa: E402


class _FakeClient:
    def query(self, *_args, **_kwargs):
        raise NotFound("Not found: Dataset demo:qa_metrics_simple was not found in location US")


class ExistingSessionIdsTest(unittest.TestCase):
    def test_existing_session_ids_raises_operational_message_on_location_mismatch(self):
        client = _FakeClient()
        with mock.patch.dict(
            "os.environ",
            {
                "BQ_PROJECT": "demo",
                "BQ_DATASET": "qa_metrics_simple",
                "BQ_LOCATION": "US",
            },
            clear=False,
        ):
            with self.assertRaises(RuntimeError) as ctx:
                main._existing_session_ids(client, lookback_days=7)

        message = str(ctx.exception)
        self.assertIn("dataset availability/location mismatch", message)
        self.assertIn("fallback_attempted=True", message)
        self.assertIn("fallback_dataset_failed", message)
        self.assertIn("BQ_PROJECT/BQ_DATASET/BQ_LOCATION", message)


class ValidateBqEnvCompatTest(unittest.TestCase):
    def test_skips_validation_when_helper_missing(self):
        with mock.patch.object(main.bq, "validate_bq_env", new=None, create=True):
            with self.assertLogs(main.logger, level="WARNING") as logs:
                result = main._validate_bq_env_compat()

        self.assertEqual(result, {})
        self.assertTrue(any("validation helper not found" in m for m in logs.output))


if __name__ == "__main__":
    unittest.main()
