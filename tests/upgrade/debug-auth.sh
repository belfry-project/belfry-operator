#!/bin/bash
# Show why the API of an AWX instance might reject the admin user: the
# authentication settings, the admin user in the database, and whether the
# password from the admin password secret matches it.
# Usage: debug-auth.sh [INSTANCE]  (defaults to awx)
set -uo pipefail
instance="${1:-awx}"
password="$(tests/upgrade/admin-password.sh "$instance")"
echo "::add-mask::$password"
echo "$instance: admin password secret $(kubectl -n awx get awx "$instance" -o jsonpath='{.status.adminPasswordSecret}'), sha256 $(printf %s "$password" | sha256sum | cut -c1-12)"
kubectl -n awx exec "deployment/$instance-web" -c "$instance-web" -- env CHECK_PASSWORD="$password" awx-manage shell -c '
import os
from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
print("AUTH_BASIC_ENABLED:", settings.AUTH_BASIC_ENABLED)
print("authentication classes:", settings.REST_FRAMEWORK.get("DEFAULT_AUTHENTICATION_CLASSES"))
print("authentication backends:", settings.AUTHENTICATION_BACKENDS)
for user in User.objects.filter(username="admin"):
    print("admin user:", user.pk, "superuser", user.is_superuser, "active", user.is_active, "usable password", user.has_usable_password())
    print("password from the secret matches:", user.check_password(os.environ["CHECK_PASSWORD"]))
print("superusers:", list(User.objects.filter(is_superuser=True).values_list("username", flat=True)))
print("authenticate():", authenticate(username="admin", password=os.environ["CHECK_PASSWORD"]))
import base64, urllib.error, urllib.request
from django.test import Client
header = "Basic " + base64.b64encode(("admin:" + os.environ["CHECK_PASSWORD"]).encode()).decode()
response = Client().get("/api/v2/me/", HTTP_AUTHORIZATION=header, SERVER_NAME="localhost")
print("Django test client GET /api/v2/me/:", response.status_code, response.content[:200])
try:
    with urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:8052/api/v2/me/", headers={"Authorization": header}), timeout=30) as r:
        print("nginx GET /api/v2/me/:", r.status)
except urllib.error.HTTPError as e:
    print("nginx GET /api/v2/me/:", e.code, e.read()[:200], dict(e.headers))
except Exception as e:
    print("nginx GET /api/v2/me/:", repr(e))
'
