#!/usr/bin/env python3
import base64
import hashlib
import os
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from asc_helpers import api, api_json, fail, json_body


KEYCHAIN = os.environ.get("BUILD_KEYCHAIN", "build.keychain")
REPLACE_DISTRIBUTION_CERTIFICATE = os.environ.get("REPLACE_DISTRIBUTION_CERTIFICATE", "").lower() in {
    "1",
    "true",
    "yes",
}
REPLACE_OLDEST_DISTRIBUTION_CERTIFICATE = os.environ.get(
    "REPLACE_OLDEST_DISTRIBUTION_CERTIFICATE", ""
).lower() in {"1", "true", "yes"}
WORK_DIR = Path("/tmp/typhoon-watch-signing")
KEY_PATH = WORK_DIR / "distribution.key"
CSR_PATH = WORK_DIR / "distribution.csr"
CERT_PATH = WORK_DIR / "distribution.cer"
INVALID_SERIALS = {
    "797262360B421323CA2A52F022C3F0BF",
}
CI_CERT_MARKERS = ("typhoonwatch", "typhoon watch")


def run(args):
    print("+", " ".join(str(arg) for arg in args), flush=True)
    subprocess.run(args, check=True)


def generate_csr():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    run(["openssl", "genrsa", "-out", str(KEY_PATH), "2048"])
    run(
        [
            "openssl",
            "req",
            "-new",
            "-key",
            str(KEY_PATH),
            "-out",
            str(CSR_PATH),
            "-subj",
            "/CN=TyphoonWatch CI Distribution/O=TokyoNasu/C=JP",
        ]
    )


def certificate_lists():
    seen = set()
    certificates = []
    for cert_type in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
        data = api_json("GET", f"/certificates?filter[certificateType]={cert_type}&limit=200").get("data", [])
        for certificate in data:
            if certificate["id"] not in seen:
                seen.add(certificate["id"])
                certificates.append(certificate)
    if not certificates:
        for certificate in api_json("GET", "/certificates?limit=200").get("data", []):
            if certificate["id"] not in seen:
                certificates.append(certificate)
    return certificates


def parse_expiration(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def serial_from_certificate_content(certificate):
    content = certificate.get("attributes", {}).get("certificateContent")
    if not content:
        detail = api_json("GET", f"/certificates/{certificate['id']}").get("data", certificate)
        content = detail.get("attributes", {}).get("certificateContent")
    if not content:
        return ""
    with tempfile.NamedTemporaryFile(suffix=".cer") as temp_cert:
        temp_cert.write(base64.b64decode(content))
        temp_cert.flush()
        result = subprocess.run(
            ["openssl", "x509", "-inform", "DER", "-in", temp_cert.name, "-noout", "-serial"],
            check=True,
            capture_output=True,
            text=True,
        )
    return result.stdout.strip().replace("serial=", "").replace(":", "").upper()


def certificate_detail(certificate):
    detail = api_json("GET", f"/certificates/{certificate['id']}").get("data", certificate)
    attrs = dict(certificate.get("attributes", {}))
    attrs.update(detail.get("attributes", {}))
    return attrs


def delete_known_invalid_certificates():
    now = datetime.now(timezone.utc)
    deleted = 0
    inspected = []
    certificates = certificate_lists()
    print(f"Found {len(certificates)} distribution certificate(s) to inspect.")
    for certificate in certificates:
        attrs = certificate_detail(certificate)
        serial = (attrs.get("serialNumber") or "").replace(":", "").upper()
        if not serial:
            serial = serial_from_certificate_content({"id": certificate["id"], "attributes": attrs})
        expiration = parse_expiration(attrs.get("expirationDate"))
        names = " ".join(str(attrs.get(key) or "") for key in ("name", "displayName", "commonName")).lower()
        is_typhoon_watch_ci_cert = any(marker in names for marker in CI_CERT_MARKERS)
        has_certificate_content = bool(attrs.get("certificateContent"))
        is_pending_request = not serial and not expiration and not has_certificate_content
        reason = ""
        if REPLACE_DISTRIBUTION_CERTIFICATE:
            reason = "replace requested"
        elif serial in INVALID_SERIALS:
            reason = "known invalid serial"
        elif is_typhoon_watch_ci_cert:
            reason = "TyphoonWatch CI certificate"
        elif expiration is not None and expiration < now:
            reason = "expired certificate"
        elif is_pending_request:
            reason = "pending certificate request"
        print(
            "Inspecting distribution certificate "
            f"{certificate['id']} serial={serial or 'none'} "
            f"expires={attrs.get('expirationDate') or 'none'} "
            f"has_content={'yes' if has_certificate_content else 'no'} "
            f"reason={reason or 'keep'}"
        )
        should_delete = (
            REPLACE_DISTRIBUTION_CERTIFICATE
            or serial in INVALID_SERIALS
            or is_typhoon_watch_ci_cert
            or (expiration is not None and expiration < now)
            or is_pending_request
        )
        if not should_delete:
            if expiration is not None:
                inspected.append((expiration, certificate, serial))
            continue
        response = api("DELETE", f"/certificates/{certificate['id']}")
        print(
            f"Deleted stale distribution certificate {certificate['id']} "
            f"serial={serial or 'unknown'} status={response.status_code}"
        )
        if response.status_code in (200, 204):
            deleted += 1
    if deleted == 0 and REPLACE_OLDEST_DISTRIBUTION_CERTIFICATE and inspected:
        expiration, certificate, serial = sorted(inspected, key=lambda item: item[0])[0]
        response = api("DELETE", f"/certificates/{certificate['id']}")
        print(
            f"Deleted oldest active distribution certificate {certificate['id']} "
            f"serial={serial or 'unknown'} expires={expiration.isoformat()} "
            f"status={response.status_code}"
        )
        if response.status_code in (200, 204):
            deleted += 1
    return deleted


def create_certificate_once(certificate_type):
    csr_content = CSR_PATH.read_text(encoding="utf-8")
    payload = {
        "data": {
            "type": "certificates",
            "attributes": {
                "certificateType": certificate_type,
                "csrContent": csr_content,
            },
        }
    }
    return api_json("POST", "/certificates", data=json_body(payload))["data"]


def should_clear_stale_certificates(error):
    text = str(error).lower()
    return (
        "maximum" in text
        or "max" in text
        or "limit" in text
        or "reached" in text
        or "already have a current" in text
        or "pending certificate request" in text
    )


def create_certificate():
    last_error = None
    cleaned = False
    for attempt in range(2):
        for certificate_type in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
            try:
                certificate = create_certificate_once(certificate_type)
                print(f"Created certificate: {certificate['id']} ({certificate_type})")
                return certificate
            except Exception as error:
                last_error = error
                print(f"Certificate create failed for {certificate_type}: {error}")
        if not cleaned and last_error and should_clear_stale_certificates(last_error):
            cleaned = True
            deleted = delete_known_invalid_certificates()
            if deleted:
                print(f"Retrying certificate creation after deleting {deleted} stale certificate(s).")
                continue
        break
    raise RuntimeError(last_error)


def import_certificate(certificate):
    content = certificate.get("attributes", {}).get("certificateContent")
    if not content:
        raise RuntimeError("Created certificate did not include certificateContent.")

    CERT_PATH.write_bytes(base64.b64decode(content))
    run(["security", "import", str(KEY_PATH), "-k", KEYCHAIN, "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    run(["security", "import", str(CERT_PATH), "-k", KEYCHAIN, "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    run(
        [
            "security",
            "set-key-partition-list",
            "-S",
            "apple-tool:,apple:",
            "-s",
            "-k",
            os.environ["KEYCHAIN_PASSWORD"],
            KEYCHAIN,
        ]
    )

    sha1 = hashlib.sha1(CERT_PATH.read_bytes()).hexdigest().upper()
    print(f"IOS_DISTRIBUTION_CERT_SHA1={sha1}")
    print(f"ASC_CERTIFICATE_ID={certificate['id']}")


def main():
    generate_csr()
    certificate = create_certificate()
    import_certificate(certificate)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail(error)
