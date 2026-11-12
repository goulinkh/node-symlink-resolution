# Shared helper for the run.sh scripts. Not meant to be run on its own.

failures=0

# check EXPECTED COMMAND
#
# Prints COMMAND, runs it, and shows its first line of output (or the error
# line, if it failed). EXPECTED is "works" or "fails"; a different outcome is
# reported and makes the script exit with an error at the end.
check() {
  expected=$1
  command=$2

  printf '\n$ %s\n' "$command"
  if output=$(sh -c "$command" 2>&1); then
    outcome=works
    line=$(printf '%s\n' "$output" | head -n 1)
  else
    outcome=fails
    line=$(printf '%s\n' "$output" | grep -m 1 '^Error' || printf '%s\n' "$output" | head -n 1)
  fi
  printf '  %s\n' "$line"

  if [ "$outcome" = "$expected" ]; then
    printf '  => %s, as expected\n' "$outcome"
  else
    printf '  => %s, but it was expected to %s\n' "$outcome" "${expected%s}"
    failures=$((failures + 1))
  fi
}

finish() {
  [ "$failures" -eq 0 ]
}
