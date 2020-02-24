#!/bin/sh
#args: <name> <template> [state] [clusters] [chmod] [user] [group]
set -e

. "$1"
CONFIG="$_ansible_tmpdir/hook.conf"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search hook
if OUTPUT="$(onehook list -lID,NAME --csv -fNAME="$name")"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete hook
    onehook delete "$ID"
    echo '{"changed":true}'
  else
    # Hook is not exist
    echo '{"changed":false}'
  fi
  exit 0
elif [ -n "$state" ] && [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, absent, got: '"$state"'"}'
  exit -1
fi

if [ -z "$template" ]; then
  echo '{"changed":false, "failed":true, "msg": "template is required"}'
  exit -1
fi

# Write template
echo "$template" > "$CONFIG"

if [ -z "$ID" ]; then
  # New hook
  echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
  if OUTPUT="$(onehook create "$CONFIG")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  onehook rename "$ID" "$name"
  echo '{"changed":true}'
else
  # Existing hook
  BEFORE="$(onehook show -x "$ID" | sha256sum )"
  onehook update "$ID" "$CONFIG"
  AFTER="$(onehook show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
