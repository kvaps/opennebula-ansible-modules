#!/bin/sh
#args: <name> <template> [state] [chmod] [user] [group]
set -e

fix_permissions() {
  if [ -n "$chmod" ]; then
    onetemplate chmod "$ID" "$chmod"
  fi

  if [ -n "$user" ]; then
    if OUTPUT="$(onetemplate chown "$ID" "$user")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi

  if [ -n "$group" ]; then
    if OUTPUT="$(onetemplate chgrp "$ID" "$group")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi
}

. "$1"
CONFIG="$_ansible_tmpdir/template.conf"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search template
if OUTPUT="$(onetemplate list -lID,USER,NAME --csv -fNAME="$name" ${user})"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete template
    onetemplate delete "$ID"
    echo '{"changed":true}'
  else
    # Template is not exist
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
  # New template
  echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
  if OUTPUT="$(onetemplate create "$CONFIG")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  fix_permissions
  onetemplate rename "$ID" "$name"
  echo '{"changed":true}'
else
  # Existing template
  BEFORE="$(onetemplate show -x "$ID" | sha256sum )"
  onetemplate update "$ID" "$CONFIG"
  fix_permissions
  AFTER="$(onetemplate show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
