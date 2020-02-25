#!/bin/sh
set -e

. "$1"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, got: '"$state"'"}'
  exit -1
fi

if [ -z "$acl" ]; then
  echo '{"changed":false, "failed":true, "msg": "acl is required"}'
  exit -1
fi

if OUTPUT="$(oneacl create "$acl")"; then
  echo '{"changed":true}'
elif echo "$OUTPUT" | grep -q 'already exists'; then
  echo '{"changed":false}'
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi
