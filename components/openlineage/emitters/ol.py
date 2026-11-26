"""OpenLineage 事件构造与发送的最小工具。"""
import json
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

DEFAULT_URL = "http://localhost:15000/api/v1/lineage"
PRODUCER = "https://example.org/ontology-demo"
RUN_EVENT_SCHEMA = "https://openlineage.io/spec/2-0-2/OpenLineage.json#/$defs/RunEvent"


def now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def new_run_id() -> str:
    return str(uuid.uuid4())


def post(event: dict, url: str = DEFAULT_URL) -> tuple[int, str]:
    data = json.dumps(event, ensure_ascii=False).encode()
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    # 本机地址绕过系统代理，避免 localhost 请求被代理拦截
    host = urllib.parse.urlparse(url).hostname
    if host in ("localhost", "127.0.0.1"):
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(req, timeout=5) as resp:
            return resp.status, resp.read().decode()
    with urllib.request.urlopen(req, timeout=5) as resp:
        return resp.status, resp.read().decode()


def event(
    event_type: str,
    run_id: str,
    job: str,
    inputs: list | None = None,
    outputs: list | None = None,
    run_facets: dict | None = None,
    job_facets: dict | None = None,
) -> dict:
    return {
        "eventType": event_type,
        "eventTime": now(),
        "run": {"runId": run_id, "facets": run_facets or {}},
        "job": {
            "namespace": "ontology-demo",
            "name": job,
            "facets": job_facets or {},
        },
        "inputs": inputs or [],
        "outputs": outputs or [],
        "producer": PRODUCER,
        "schemaURL": RUN_EVENT_SCHEMA,
    }


def dataset(namespace: str, name: str, facets: dict | None = None) -> dict:
    return {"namespace": namespace, "name": name, "facets": facets or {}}


def schema_facet(fields: list[tuple[str, str]]) -> dict:
    return {
        "schema": {
            "_producer": PRODUCER,
            "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/SchemaDatasetFacet.json",
            "fields": [{"name": n, "type": t} for n, t in fields],
        }
    }


def sql_facet(query: str) -> dict:
    return {
        "sql": {
            "_producer": PRODUCER,
            "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/SQLJobFacet.json",
            "query": query,
        }
    }


def column_lineage(
    mapping: dict[str, list[str]], source_dataset: str = "raw_orders"
) -> dict:
    """mapping: 输出字段 -> 依赖的源字段列表。"""
    fields = {}
    for out_field, deps in mapping.items():
        fields[out_field] = {
            "inputFields": [
                {
                    "namespace": "postgres://demo",
                    "name": source_dataset,
                    "field": dep,
                }
                for dep in deps
            ],
            "transformationType": "DIRECT",
        }
    return {
        "columnLineage": {
            "_producer": PRODUCER,
            "_schemaURL": "https://openlineage.io/spec/facets/1-1-0/ColumnLineageDatasetFacet.json",
            "fields": fields,
        }
    }


def error_message_facet(message: str) -> dict:
    return {
        "errorMessage": {
            "_producer": PRODUCER,
            "_schemaURL": "https://openlineage.io/spec/facets/1-0-1/ErrorMessageRunFacet.json",
            "message": message,
            "programmingLanguage": "JAVA",
        }
    }
