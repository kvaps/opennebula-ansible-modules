#!/bin/sh
#args: <name> <template> [ar_uniq_key]
set -e

. "$1"
CONFIG="$_ansible_tmpdir/vnetar.conf"
AR_UNIQ_KEY=${ar_uniq_key:-IP}

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search vnet
if OUTPUT="$(onevnet list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ -z "$template" ]; then
  echo '{"changed":false, "failed":true, "msg": "template is required"}'
  exit -1
fi

# Write template
echo "$template" > "$CONFIG"

# Search unique value for AR_UNIQ_KEY
AR_UNIQ_VAL="$(sed -n 's/.*'"${AR_UNIQ_KEY}"' *= *"\?\([^",]\+\)"\?.*/\1/p' "$CONFIG")"
if [ -z "$AR_UNIQ_VAL" ]; then
  echo "" >&2
  echo '{"changed":false, "failed":true, "msg": "Template have no $AR_UNIQ_KEY attribute"}'
  exit -1
fi

# Search address range
if OUTPUT="$(onevnet show -x "$ID")"; then
  AR_ID="$(echo "$OUTPUT" | ruby -r rexml/document -e 'include REXML; p XPath.first(Document.new($stdin), "/VNET/AR_POOL/AR['"${AR_UNIQ_KEY}"'=\"'"${AR_UNIQ_VAL}"'\"]/AR_ID/text()")' | grep -o '[0-9]\+' || true)"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$AR_ID" ]; then
    # Delete address range
    onevnet rmar "$ID" "$AR_ID"
    echo '{"changed":true}'
  else
    # Address range is not exist
    echo '{"changed":false}'
  fi
  exit 0
elif [ -n "$state" ] && [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, absent, got: '"$state"'"}'
  exit -1
fi

if [ -z "$AR_ID" ]; then
  # New address range
  onevnet addar "$ID" "$TEMPLATE"
  echo '{"changed":true}'
else
  # Existing address range
  BEFORE="$(onevnet show -x "$ID" | sha256sum )"
  sed -zi "s/\(AR *= *\[\)/\1 AR_ID=$AR_ID, /" "$CONFIG"
  onevnet updatear "$ID" "$AR_ID" "$CONFIG"
  AFTER="$(onevnet show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
