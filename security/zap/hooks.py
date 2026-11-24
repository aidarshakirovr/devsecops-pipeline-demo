"""Baseline hooks: request the API directly and import its OpenAPI document.

The traditional spider only follows links from /. These routes are not linked.
"""

import os


def _paths():
    raw = os.environ.get("ZAP_PATHS", "/,/health,/items,/openapi.json")
    return [item.strip() for item in raw.split(",") if item.strip()]


def zap_spider(zap, target):
    base = target.rstrip("/")
    for path in _paths():
        url = path if path.startswith("http") else base + path
        try:
            zap.urlopen(url)
            print("ACCESSED " + url)
        except Exception as exc:
            print("ACCESS_FAILED " + url + " " + str(exc))
    if os.environ.get("ZAP_OPENAPI", "1") == "1":
        spec = base + "/openapi.json"
        try:
            zap.openapi.import_url(spec, base)
            print("OPENAPI_IMPORTED " + spec)
        except Exception as exc:
            print("OPENAPI_SKIPPED " + spec + " " + str(exc))
    return zap, target


def zap_pre_shutdown(zap):
    print("SCANNED_URLS_BEGIN")
    try:
        urls = zap.core.urls()
    except Exception as exc:
        print("URL_LIST_FAILED " + str(exc))
        urls = []
    if isinstance(urls, dict):
        urls = urls.get("urls") or []
    for url in urls:
        print(url)
    print("SCANNED_URLS_END")
