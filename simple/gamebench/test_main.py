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
        raise NotFound("Not found: Dataset demo:qa_metrics_simple was not found in location EU")


class ExistingSessionIdsTest(unittest.TestCase):
    def test_existing_session_ids_raises_operational_message_on_location_mismatch(self):
        client = _FakeClient()
        with mock.patch.dict(
            "os.environ",
            {
                "BQ_PROJECT": "demo",
                "BQ_DATASET": "qa_metrics_simple",
                "BQ_LOCATION": "EU",
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


class EnvironmentEmptyFallbackTest(unittest.TestCase):
    def test_falls_back_without_environment_on_ok_empty_response(self):
        client = main.GameBenchClient("user@example.com", "secret", auth_mode="basic", company_id=None)

        def _resp(ok, status_code, payload):
            m = mock.Mock()
            m.ok = ok
            m.status_code = status_code
            m.text = str(payload)
            m.json.return_value = payload
            m.headers = {}
            return m

        with mock.patch.object(
            main,
            "_request_with_backoff",
            side_effect=[
                _resp(True, 200, {"results": []}),
                _resp(True, 200, {"results": [{"sessionId": "s-1"}]}),
            ],
        ) as req_mock:
            sessions = client.advanced_search_sessions(
                packages=["com.scopely.internal.wwedomination"],
                environment="dev",
                start_ms=1,
                end_ms=2,
                page_size=50,
                max_pages=1,
            )

        self.assertEqual(sessions, [{"sessionId": "s-1"}])
        first_body = req_mock.call_args_list[0].kwargs["json_body"]
        second_body = req_mock.call_args_list[1].kwargs["json_body"]
        self.assertEqual(first_body["appInfo"]["environment"], "dev")
        self.assertNotIn("environment", second_body["appInfo"])


if __name__ == "__main__":
    unittest.main()
