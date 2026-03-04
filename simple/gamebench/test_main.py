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


class CollectionFilteringModeTest(unittest.TestCase):
    def test_uses_local_mode_when_collection_filter_is_empty_in_search_api(self):
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
                                search_calls = []

                                def _search(self, **kwargs):  # noqa: ANN001
                                    search_calls.append(kwargs.get("collection_id"))
                                    if kwargs.get("collection_id"):
                                        return []
                                    return [
                                        {
                                            "sessionId": "s-1",
                                            "appInfo": {"package": "com.scopely.internal.wwedomination"},
                                        }
                                    ]

                                def _details(self, session_id):  # noqa: ANN001
                                    return {
                                        "sessionId": session_id,
                                        "appInfo": {
                                            "package": "com.scopely.internal.wwedomination",
                                            "collectionId": "collection-123",
                                        },
                                    }

                                with mock.patch.object(main.GameBenchClient, "advanced_search_sessions", new=_search):
                                    with mock.patch.object(main.GameBenchClient, "get_session_details", new=_details):
                                        with self.assertLogs(main.logger, level="INFO") as logs:
                                            inserted, skipped = main.ingest_gamebench()

        self.assertEqual((inserted, skipped), (1, 0))
        self.assertEqual(search_calls, ["collection-123", None])
        self.assertTrue(any("collection_filter_mode=local" in msg for msg in logs.output))
        self.assertFalse(hasattr(main, "_COLLECTION_FILTER_DISABLED"))

    def test_raises_clear_error_when_collection_has_no_matches_after_local_filter(self):
        with mock.patch.dict(
            "os.environ",
            {
                "GAMEBENCH_USER": "user@example.com",
                "GAMEBENCH_TOKEN": "secret",
                "GAMEBENCH_COLLECTION_ID": "collection-999",
                "GAMEBENCH_APP_PACKAGES": "com.scopely.internal.wwedomination",
                "GAMEBENCH_LOOKBACK_DAYS": "1",
            },
            clear=False,
        ):
            with mock.patch.object(main, "get_client", return_value=object()):
                with mock.patch.object(main, "_existing_session_ids", return_value=set()):
                    with mock.patch.object(main.GameBenchClient, "advanced_search_sessions") as search_mock:
                        with mock.patch.object(main.GameBenchClient, "get_session_details") as details_mock:
                            search_mock.side_effect = [
                                [],
                                [
                                    {
                                        "sessionId": "s-1",
                                        "appInfo": {"package": "com.scopely.internal.wwedomination"},
                                    }
                                ],
                            ]
                            details_mock.return_value = {
                                "sessionId": "s-1",
                                "appInfo": {
                                    "package": "com.scopely.internal.wwedomination",
                                    "collectionId": "collection-other",
                                },
                            }

                            with self.assertRaises(ValueError) as ctx:
                                main.ingest_gamebench()

        msg = str(ctx.exception)
        self.assertIn("No hay sesiones para collectionId=collection-999", msg)
        self.assertIn("mapping packages↔collection", msg)


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
                collection_id=None,
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
