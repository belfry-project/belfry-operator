#!/usr/bin/env python3
"""Create data in AWX before an upgrade, and verify it afterwards.

Usage: check.py seed [URL] | check.py verify [URL]

Talks to the AWX API at URL, or AWX_URL (default http://localhost:8080), as
admin with AWX_ADMIN_PASSWORD. seed writes upgrade-state.json, which verify
reads. verify can run against any instance that has the seeded data: the
upgraded one, or a new one restored from a backup made after seeding.
verify runs a job that updates the cached facts; to verify an instance again
after that (or a backup made after it), set FACTS_PHASE=after.

The data covers what users care about when upgrading: an organization, an
inventory with a host and cached facts, a credential with a secret, a project,
a job template, and a finished job with its output.
"""

import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get('AWX_URL', 'http://localhost:8080').rstrip('/')
PASSWORD = os.environ['AWX_ADMIN_PASSWORD']
PROJECT_URL = os.environ.get('PROJECT_URL', 'https://github.com/belfry-project/belfry-operator')
PROJECT_BRANCH = os.environ['PROJECT_BRANCH']  # a commit that contains tests/upgrade/playbooks/check.yml
SECRET = 's3cret-upgrade-token'
SECRET_HASH = hashlib.sha256(SECRET.encode()).hexdigest()
NAME = 'upgrade-test'
STATE = 'upgrade-state.json'


def api(method, path, data=None, ok=(200, 201, 202, 204), text=False):
    request = urllib.request.Request(
        URL + path,
        data=json.dumps(data).encode() if data is not None else None,
        method=method,
        headers={
            'Authorization': 'Basic ' + base64.b64encode(f'admin:{PASSWORD}'.encode()).decode(),
            'Content-Type': 'application/json',
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read().decode()
            if response.status not in ok:
                raise RuntimeError(f'{method} {path}: HTTP {response.status} {body[:500]}')
            return body if text or not body else json.loads(body)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{method} {path}: HTTP {e.code} {e.read().decode()[:1000]}') from None


def wait_for_api(timeout=1200):
    deadline = time.time() + timeout
    rejected_since = None
    while True:
        try:
            ping = api('GET', '/api/v2/ping/')
            api('GET', '/api/v2/me/')
            # The API answers before the task instance is ready, and creating objects
            # such as hosts schedules background tasks that need one
            instances = api('GET', '/api/v2/instances/')['results']
            if not any(i['node_state'] == 'ready' and i['enabled'] and i['capacity'] > 0 for i in instances):
                raise RuntimeError(f'no ready instance yet: {[(i["hostname"], i["node_state"], i["capacity"]) for i in instances]}')
            return ping
        except Exception as e:  # noqa: BLE001 - keep polling until the deadline
            if time.time() > deadline:
                raise RuntimeError(f'AWX API not ready after {timeout}s: {e}') from None
            # The API answers, but keeps rejecting the admin credentials
            if 'HTTP 401' in str(e):
                rejected_since = rejected_since or time.time()
                if time.time() - rejected_since > 300:
                    raise RuntimeError(f'AWX API rejected the admin credentials for 300s: {e}') from None
            else:
                rejected_since = None
            time.sleep(10)


def get_one(path, name):
    results = api('GET', f'{path}?name={urllib.request.quote(name)}')['results']
    if len(results) != 1:
        raise RuntimeError(f'Expected one {path} named {name!r}, found {len(results)}')
    return results[0]


def wait_for(path, timeout=900):
    deadline = time.time() + timeout
    while True:
        item = api('GET', path)
        if item['status'] in ('successful', 'failed', 'error', 'canceled'):
            return item
        if time.time() > deadline:
            raise RuntimeError(f'{path} still {item["status"]} after {timeout}s')
        time.sleep(5)


def run_job(template_id, phase):
    job = api('POST', f'/api/v2/job_templates/{template_id}/launch/', {'extra_vars': {'phase': phase}})
    job = wait_for(f'/api/v2/jobs/{job["job"]}/')
    # Job events are saved asynchronously, so the output can lag behind the
    # job's status; wait until the play recap is in
    deadline = time.time() + 120
    while True:
        stdout = api('GET', f'/api/v2/jobs/{job["id"]}/stdout/?format=txt', text=True)
        if 'PLAY RECAP' in stdout or time.time() > deadline:
            break
        time.sleep(5)
    if job['status'] != 'successful':
        raise RuntimeError(f'Job {job["id"]} ({phase}) ended {job["status"]}:\n{stdout}')
    if f'secret-sha256={SECRET_HASH}' not in stdout:
        raise RuntimeError(f'Job {job["id"]} ({phase}) did not receive the credential secret:\n{stdout}')
    return job


def host_facts(inventory_id):
    host = api('GET', f'/api/v2/inventories/{inventory_id}/hosts/?name=localhost')['results'][0]
    return host, api('GET', f'/api/v2/hosts/{host["id"]}/ansible_facts/')


def seed():
    ping = wait_for_api()
    print(f'AWX {ping["version"]} is up')
    org = api('POST', '/api/v2/organizations/', {'name': NAME})
    inventory = api('POST', '/api/v2/inventories/', {'name': NAME, 'organization': org['id']})
    api(
        'POST',
        '/api/v2/hosts/',
        {
            'name': 'localhost',
            'inventory': inventory['id'],
            'variables': json.dumps({'ansible_connection': 'local', 'ansible_python_interpreter': '{{ ansible_playbook_python }}'}),
        },
    )
    credential_type = api(
        'POST',
        '/api/v2/credential_types/',
        {
            'name': NAME,
            'kind': 'cloud',
            'inputs': {'fields': [{'id': 'token', 'label': 'Token', 'type': 'string', 'secret': True}]},
            'injectors': {'env': {'BELFRY_UPGRADE_SECRET': '{{ token }}'}},
        },
    )
    credential = api(
        'POST', '/api/v2/credentials/', {'name': NAME, 'organization': org['id'], 'credential_type': credential_type['id'], 'inputs': {'token': SECRET}}
    )
    project = api(
        'POST', '/api/v2/projects/', {'name': NAME, 'organization': org['id'], 'scm_type': 'git', 'scm_url': PROJECT_URL, 'scm_branch': PROJECT_BRANCH}
    )
    project = wait_for(f'/api/v2/projects/{project["id"]}/')
    if project['status'] != 'successful':
        raise RuntimeError(f'Project update ended {project["status"]}')
    template = api(
        'POST',
        '/api/v2/job_templates/',
        {
            'name': NAME,
            'inventory': inventory['id'],
            'project': project['id'],
            'playbook': 'tests/upgrade/playbooks/check.yml',
            'use_fact_cache': True,
            'ask_variables_on_launch': True,
        },
    )
    api('POST', f'/api/v2/job_templates/{template["id"]}/credentials/', {'id': credential['id']})
    job = run_job(template['id'], 'before')
    host, facts = host_facts(inventory['id'])
    if facts.get('upgrade_test_phase') != 'before' or 'ansible_distribution' not in facts:
        raise RuntimeError(f'Facts were not cached before the upgrade: {sorted(facts)[:20]}')
    state = {'version': ping['version'], 'job': job['id'], 'facts_modified': host['ansible_facts_modified'], 'distribution': facts['ansible_distribution']}
    with open(STATE, 'w') as f:
        json.dump(state, f, indent=2)
    print(f'Seeded AWX {ping["version"]}: job {job["id"]} successful, facts cached for localhost')


def verify():
    with open(STATE) as f:
        state = json.load(f)
    ping = wait_for_api()
    print(f'Upgraded from {state["version"]} to {ping["version"]}')
    if ping['version'] == state['version']:
        raise RuntimeError('The version did not change, so the upgrade did not happen')

    # The data from before the upgrade is still there
    org = get_one('/api/v2/organizations/', NAME)
    inventory = get_one('/api/v2/inventories/', NAME)
    template = get_one('/api/v2/job_templates/', NAME)
    get_one('/api/v2/credentials/', NAME)
    get_one('/api/v2/projects/', NAME)
    old_job = api('GET', f'/api/v2/jobs/{state["job"]}/')
    if old_job['status'] != 'successful' or f'secret-sha256={SECRET_HASH}' not in api('GET', f'/api/v2/jobs/{old_job["id"]}/stdout/?format=txt', text=True):
        raise RuntimeError('The job from before the upgrade, or its output, did not survive')
    host, facts = host_facts(inventory['id'])
    if facts.get('upgrade_test_phase') != os.environ.get('FACTS_PHASE', 'before') or facts.get('ansible_distribution') != state['distribution']:
        raise RuntimeError(f'Facts from before the upgrade did not survive: {sorted(facts)[:20]}')
    print(f'Organization {org["id"]}, inventory, credential, project, job template and job {old_job["id"]} survived, with cached facts')

    # A new job runs in the Belfry execution environment, can decrypt the
    # credential from before the upgrade, and updates the cached facts
    job = run_job(template['id'], 'after')
    environment = api('GET', f'/api/v2/execution_environments/{job["execution_environment"]}/')
    if 'belfry-ee' not in environment['image']:
        raise RuntimeError(f'Job {job["id"]} ran in {environment["image"]}, not the Belfry execution environment')
    host, facts = host_facts(inventory['id'])
    if facts.get('upgrade_test_phase') != 'after' or host['ansible_facts_modified'] == state['facts_modified']:
        raise RuntimeError(f'Facts were not updated by the job after the upgrade: phase={facts.get("upgrade_test_phase")}')
    print(f'Job {job["id"]} ran in {environment["image"]}, decrypted the credential and updated the cached facts')


if __name__ == '__main__':
    if len(sys.argv) > 2:
        URL = sys.argv[2].rstrip('/')
    print(f'Using {URL}')
    {'seed': seed, 'verify': verify}[sys.argv[1]]()
