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


class CollectionFallbackTest(unittest.TestCase):
    def test_retries_without_collection_when_first_search_returns_empty(self):
        with mock.patch.dict(
            "os.environ",
            {
                "GAMEBENCH_USER": "user@example.com",
                "GAMEBENCH_TOKEN": "secret",
                "GAMEBENCH_COLLECTION_ID": "collection-123",
                "GAMEBENCH_APP_PACKAGES": "com.scopely.internal.wwedomination",
                "GAMEBENCH_LOOKBACK_DAYS": "1",
            },
            clear=False,
        ):
            with mock.patch.object(main, "get_client", return_value=object()):
                with mock.patch.object(main, "_existing_session_ids", return_value=set()):
                    with mock.patch.object(main, "insert_rows", return_value=1):
                        with mock.patch.object(main.GameBenchClient, "get_fps", return_value=[60.0]):
                            with mock.patch.object(main.GameBenchClient, "get_fps_stability", return_value=[95.0]):
                                calls = []

                                def _search(self, **kwargs):  # noqa: ANN001
                                    calls.append(kwargs.get("collection_id"))
                                    if kwargs.get("collection_id"):
                                        return []
                                    return [
                                        {
                                            "sessionId": "s-1",
                                            "appInfo": {"package": "com.scopely.internal.wwedomination"},
                                        }
                                    ]

                                with mock.patch.object(
                                    main.GameBenchClient,
                                    "advanced_search_sessions",
                                    new=_search,
                                ):
                                    with self.assertLogs(main.logger, level="WARNING") as logs:
                                        inserted, skipped = main.ingest_gamebench()

        self.assertEqual(inserted, 1)
        self.assertEqual(skipped, 0)
        self.assertEqual(calls, ["collection-123", None])
        self.assertTrue(any("GAMEBENCH_COLLECTION_FILTER_MISS" in msg for msg in logs.output))
        self.assertTrue(any("environment=dev" in msg for msg in logs.output))
        self.assertTrue(any("collection_id=collection-123" in msg for msg in logs.output))
        self.assertTrue(any("fallback_without_collection=True" in msg for msg in logs.output))


class CollectionOptionalTest(unittest.TestCase):
    def test_does_not_retry_when_collection_is_not_configured(self):
        with mock.patch.dict(
            "os.environ",
            {
                "GAMEBENCH_USER": "user@example.com",
                "GAMEBENCH_TOKEN": "secret",
                "GAMEBENCH_APP_PACKAGES": "com.scopely.internal.wwedomination",
                "GAMEBENCH_LOOKBACK_DAYS": "1",
            },
            clear=False,
        ):
            with mock.patch.object(main, "get_client", return_value=object()):
                with mock.patch.object(main, "_existing_session_ids", return_value=set()):
                    with mock.patch.object(main, "insert_rows", return_value=1):
                        with mock.patch.object(main.GameBenchClient, "get_fps", return_value=[60.0]):
                            with mock.patch.object(main.GameBenchClient, "get_fps_stability", return_value=[95.0]):
                                calls = []

                                def _search(self, **kwargs):  # noqa: ANN001
                                    calls.append(kwargs.get("collection_id"))
                                    return [
                                        {
                                            "sessionId": "s-1",
                                            "appInfo": {"package": "com.scopely.internal.wwedomination"},
                                        }
                                    ]

                                with mock.patch.object(
                                    main.GameBenchClient,
                                    "advanced_search_sessions",
                                    new=_search,
                                ):
                                    inserted, skipped = main.ingest_gamebench()

        self.assertEqual(inserted, 1)
        self.assertEqual(skipped, 0)
        self.assertEqual(calls, [None])


if __name__ == "__main__":
    unittest.main()
