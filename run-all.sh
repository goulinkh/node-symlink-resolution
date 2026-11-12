#!/bin/sh
# Runs every example and exits with an error if any outcome is unexpected.
cd "$(dirname "$0")" || exit 1
node --version

status=0
for script in */run.sh; do
  printf '\n=== %s ===\n' "${script%/run.sh}"
  sh "$script" || status=1
done

if [ "$status" -eq 0 ]; then
  printf '\nAll examples behaved as expected.\n'
else
  printf '\nSome examples did not behave as expected.\n'
fi
exit $status
