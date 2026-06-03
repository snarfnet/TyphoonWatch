#!/usr/bin/env python3
import os
import time

from asc_helpers import api_json, fail, query


APP_ID = os.environ["APP_ID"]
BUILD_NUMBER = os.environ["BUILD_NUMBER"]
WAIT_SECONDS = int(os.environ.get("WAIT_SECONDS", "1800"))
POLL_SECONDS = int(os.environ.get("POLL_SECONDS", "30"))


def find_builds():
    params = query(
        {
            "filter[app]": APP_ID,
            "filter[version]": BUILD_NUMBER,
            "limit": "10",
            "sort": "-uploadedDate",
        }
    )
    return api_json("GET", f"/builds?{params}").get("data", [])


def main():
    deadline = time.time() + WAIT_SECONDS
    last_state = "not found"

    while time.time() < deadline:
        builds = find_builds()
        if builds:
            build = builds[0]
            attrs = build.get("attributes", {})
            state = attrs.get("processingState", "UNKNOWN")
            version = attrs.get("version")
            uploaded = attrs.get("uploadedDate")
            print(f"Build found: id={build['id']} version={version} state={state} uploaded={uploaded}")
            if state in {"VALID", "FAILED", "INVALID"}:
                if state != "VALID":
                    raise RuntimeError(f"Build processing ended with state={state}")
                return
            last_state = state
        else:
            print(f"Build {BUILD_NUMBER} is not visible yet.")

        time.sleep(POLL_SECONDS)

    raise RuntimeError(f"Timed out waiting for TestFlight build {BUILD_NUMBER}. Last state: {last_state}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail(error)
