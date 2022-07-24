#!/usr/bin/env python3
'''
Simple script to generate a github runner token
'''
import json
import logging
import sys
import time
from argparse import ArgumentParser
from base64 import urlsafe_b64encode
from pathlib import PosixPath
from typing import Optional

import requests
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_private_key

logger = logging.getLogger(__name__)


def _generate_bearer_token(app_id: int, app_key: PosixPath) -> str:
    unix_now = int(time.time())

    header = json.dumps({'typ': 'JWT', 'alg': 'RS256'},
                        separators=(",", ":")).encode("utf-8")
    payload = json.dumps({'iat': unix_now - 60, 'exp': unix_now + 600, 'iss': app_id},
                         separators=(",", ":")).encode("utf-8")

    data = '.'.join([
        urlsafe_b64encode(header).decode('utf-8').replace("=", ""),
        urlsafe_b64encode(payload).decode('utf-8').replace("=", "")
    ])

    with app_key.open('rb') as fh:
        key = load_pem_private_key(fh.read(), password=None, backend=default_backend())

    signature = key.sign(data.encode('utf-8'), padding.PKCS1v15(), hashes.SHA256())
    data += f'.{urlsafe_b64encode(signature).decode("utf-8").replace("=", "")}'
    return data


def _find_installation_id(bearer_token: str, org: str) -> Optional[int]:
    r = requests.get(
        f'https://api.github.com/orgs/{org}/installation',
        headers={'Authorization': f'Bearer {bearer_token}'},
    )
    if r.status_code == 404:
        return None

    r.raise_for_status()
    return int(r.json()['id'])


def _generate_access_key(bearer_token: str, installation_id: int) -> str:
    r = requests.post(
        f'https://api.github.com/app/installations/{installation_id}/access_tokens',
        headers={'Authorization': f'Bearer {bearer_token}'},
    )
    r.raise_for_status()
    return r.json()['token']


def main():
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    parser = ArgumentParser()
    parser.add_argument('--app-id', type=int, required=True)
    parser.add_argument('--app-key', type=str, required=True)
    parser.add_argument('--github-org', type=str, required=True)
    options = parser.parse_args()

    app_key = PosixPath(options.app_key)
    if not app_key.is_file():
        print(f'Invalid app-key: {app_key.as_posix()}')
        return

    bearer_token = _generate_bearer_token(options.app_id, app_key)
    installation_id = _find_installation_id(bearer_token, options.github_org)
    if installation_id:
        print(_generate_access_key(bearer_token, installation_id))


if __name__ == '__main__':
    main()
