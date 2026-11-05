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
'
