# Sourced by ../run.sh: sets up the runtimes, runs each example once per
# runtime in a fresh root directory, and prints the results side by side.

label_width=32
name_width=7
tab=$(printf '\t')
count=0
mismatches=0
verbose=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  bold=$(printf '\033[1m') dim=$(printf '\033[2m') reset=$(printf '\033[0m')
  green=$(printf '\033[32m') red=$(printf '\033[31m') yellow=$(printf '\033[33m')
else
  bold='' dim='' reset='' green='' red='' yellow=''
fi

usage() {
  sed -n '2,/^$/s/^# \{0,1\}//p' run.sh
}

# Details of runtime N are stored as files in $work/runtimeN/.
get() {
  cat "$work/runtime$1/$2"
}

add_runtime() {
  case $1 in
    nodejs.org)
      if [ ! -x runtimes/nodejs.org/bin/node ]; then
        sh lib/download-nodejs-org.sh runtimes/nodejs.org || exit 1
      fi
      name=nodejs.org
      binary=$PWD/runtimes/nodejs.org/bin/node
      ;;
    *=*)
      name=${1%%=*}
      binary=${1#*=}
      ;;
    *)
      name=''
      binary=$1
      ;;
  esac
  if [ "$name" != nodejs.org ]; then
    if [ ! -f "$binary" ] || [ ! -x "$binary" ]; then
      echo "Not a node binary: $binary" >&2
      exit 2
    fi
    path=$binary
    binary=$(readlink -f "$path")
    if [ -z "$name" ] && [ "$path" = /usr/bin/node ] && [ -r /etc/os-release ]; then
      name=$(. /etc/os-release && printf '%s-%s' "$ID" "$VERSION_ID")
    fi
    if [ -z "$name" ]; then
      name=node-$("$binary" --version)
    fi
  fi

  # Debian's patch adds a build setting that upstream Node.js doesn't have.
  if ! kind=$("$binary" -p "process.config.variables.node_relative_path ? 'debian' : 'upstream'" 2>&1); then
    printf 'Cannot run %s:\n%s\n' "$binary" "$kind" >&2
    exit 1
  fi

  [ "${#name}" -gt "$name_width" ] && name_width=${#name}
  count=$((count + 1))
  mkdir "$work/runtime$count"
  printf '%s' "$name" >"$work/runtime$count/name"
  printf '%s' "$binary" >"$work/runtime$count/binary"
  printf '%s' "$kind" >"$work/runtime$count/kind"

  # Debian's node finds the folders it searches from its own location, so it
  # has to be a real file in each root, not a symbolic link. Hard links to
  # this copy are cheap.
  if [ "$kind" = debian ]; then
    cp "$binary" "$work/runtime$count/node"
  fi
}

# Prepares a fresh root directory for runtime N and EXAMPLE, in $root.
prepare_root() {
  root=$work/runtime$1/$2
  mkdir -p "$root/usr/bin"
  if [ "$(get "$1" kind)" = debian ]; then
    ln "$work/runtime$1/node" "$root/usr/bin/node"
    # Debian's nodejs package installs this link.
    mkdir -p "$root/usr/share"
    ln -s nodejs "$root/usr/share/node_modules"
  else
    ln -s "$(get "$1" binary)" "$root/usr/bin/node"
  fi
  if [ -d "$2/files" ]; then
    cp -R "$2/files/." "$root/"
  fi
}

run_checks() {
  prepare_root "$1" "$2"
  env -u NODE_PATH -u NODE_OPTIONS ROOT="$root" HOME="$work/home" PATH="$root/usr/bin:$PATH" \
    sh lib/run-checks.sh "$2" >"$work/runtime$1/$2.out" 2>"$work/runtime$1/$2.err"
}

group_label() {
  case $1 in
    debian) printf 'Debian' ;;
    *) printf 'Upstream' ;;
  esac
}

pad() {
  printf "%-${2}s" "$1"
}

column_width() {
  width=${#1}
  [ "$width" -lt 7 ] && width=7
  echo $((width + 2))
}

# Prints a separator before the first column of each group but the first.
separator() {
  kind=$(get "$1" kind)
  if [ -n "$previous_kind" ] && [ "$kind" != "$previous_kind" ]; then
    printf '%s|%s ' "$dim" "$reset"
  fi
  previous_kind=$kind
}

show_runtimes() {
  printf '\n%sRuntimes%s\n\n' "$bold" "$reset"
  name_column=$((name_width + 2))
  printf '  %s%s%s%s%s\n' "$dim" "$(pad Runtime "$name_column")" "$(pad Group 10)" "$(pad Node.js 11)" "Binary$reset"
  for n in $order; do
    run_checks "$n" about
    binary=$(get "$n" binary)
    printf '  %s%s%s%s\n' "$(pad "$(get "$n" name)" "$name_column")" "$(pad "$(group_label "$(get "$n" kind)")" 10)" \
      "$(pad "$(sed -n 1p "$work/runtime$n/about.out")" 11)" "${binary#"$PWD/"}"
  done

  printf '\n  Folders that require() searches as a last resort:\n\n'
  for n in $order; do
    first=1
    for folder in $(sed -n 2p "$work/runtime$n/about.out"); do
      if [ "$first" = 1 ]; then
        printf '  %s%s\n' "$(pad "$(get "$n" name)" "$name_column")" "$folder"
        first=0
      else
        printf "  %${name_column}s%s\\n" '' "$folder"
      fi
    done
  done

  cat <<'EOF'

  Each example runs in a fresh root directory, $ROOT, which stands in for /.
  The runtime's node is $ROOT/usr/bin/node.

  Debian's nodejs package, which Ubuntu also uses, differs from upstream
  Node.js in two ways:

  - Node.js is patched so that require() also searches /usr/share/nodejs,
    relative to the node binary. That's why the Debian runtime's folders
    above are under $ROOT.
  - The package installs the link /usr/share/node_modules -> nodejs. Roots
    for Debian runtimes get this link too.
EOF

  if [ -z "$debian_order" ]; then
    printf '\n  %sNo Debian runtime: run this on Debian or Ubuntu, with the nodejs\n' "$yellow"
    printf '  package installed, to compare with Debian'"'"'s Node.js.%s\n' "$reset"
  fi
}

expected_for() {
  case $1 in
    *=*)
      for pair in $1; do
        case $pair in "$2="*) printf '%s' "${pair#*=}" ;; esac
      done
      ;;
    *) printf '%s' "$1" ;;
  esac
}

show_example() {
  example=$1
  index=0
  header_pending=1
  notes_started=0

  title() {
    printf '\n%s%s  %s%s\n' "$bold" "${example%%-*}" "$1" "$reset"
  }

  intro() {
    printf '    %s\n' "$1"
  }

  header() {
    [ "$header_pending" = 1 ] || return 0
    header_pending=0

    # First line: one label per group of runtimes.
    printf '\n    %s' "$(pad '' "$label_width")"
    previous_kind=''
    group_width=0
    for n in $order; do
      kind=$(get "$n" kind)
      if [ "$kind" != "$previous_kind" ]; then
        if [ -n "$previous_kind" ]; then
          printf '%s%s|%s ' "$(pad "$label" "$group_width")" "$dim" "$reset"
        fi
        label="$bold$(group_label "$kind")$reset"
        group_width=$((${#bold} + ${#reset}))
      fi
      group_width=$((group_width + $(column_width "$(get "$n" name)")))
      previous_kind=$kind
    done
    printf '%s\n' "$label"

    # Second line: the runtime names.
    printf '    %s' "$(pad '' "$label_width")"
    previous_kind=''
    for n in $order; do
      separator "$n"
      name=$(get "$n" name)
      printf '%s%s%s' "$dim" "$(pad "$name" "$(column_width "$name")")" "$reset"
    done
    printf '\n'
  }

  step() {
    header
    printf '    %s$ %s%s\n' "$dim" "$1" "$reset"
    if [ "$verbose" = 1 ]; then
      printf '      %s(runs: %s)%s\n' "$dim" "$2" "$reset"
    fi
  }

  check() {
    header
    index=$((index + 1))
    printf '    %s' "$(pad "$1" "$label_width")"
    previous_kind=''
    for n in $order; do
      separator "$n"
      result=$(sed -n "${index}p" "$work/runtime$n/$example.out")
      outcome=${result%%"$tab"*}
      [ -n "$outcome" ] || outcome=error
      expected=$(expected_for "$2" "$(get "$n" kind)")
      case $outcome in works) color=$green ;; *) color=$red ;; esac
      cell=$outcome
      if [ "$outcome" != "$expected" ]; then
        color=$yellow
        cell="$outcome !"
        mismatches=$((mismatches + 1))
      fi
      printf '%s%s%s' "$color" "$(pad "$cell" "$(column_width "$(get "$n" name)")")" "$reset"
    done
    printf '\n'
    if [ "$verbose" = 1 ]; then
      printf '      %s$ %s%s\n' "$dim" "$3" "$reset"
      for n in $order; do
        detail=$(sed -n "${index}p" "$work/runtime$n/$example.out")
        printf '      %s%s%s%s\n' "$dim" "$(pad "$(get "$n" name)" "$((name_width + 2))")" "${detail#*"$tab"}" "$reset"
      done
    fi
  }

  note() {
    if [ "$notes_started" = 0 ]; then
      printf '\n'
      notes_started=1
    fi
    printf '    %s\n' "$1"
  }

  . "./$example/checks.sh"

  for n in $order; do
    if [ -s "$work/runtime$n/$example.err" ]; then
      printf '    %s%s: %s%s\n' "$yellow" "$(get "$n" name)" "$(cat "$work/runtime$n/$example.err")" "$reset"
    fi
  done
}

main() {
  while [ $# -gt 0 ]; do
    case $1 in
      -v) verbose=1 ;;
      -h | --help) usage; exit 0 ;;
      -*) usage >&2; exit 2 ;;
      *) break ;;
    esac
    shift
  done

  if [ $# -eq 0 ]; then
    set -- nodejs.org
    [ -x /usr/bin/node ] && set -- "$@" /usr/bin/node
  fi

  # Under /tmp, and without spaces, so that the commands can use $ROOT
  # unquoted.
  work=$(mktemp -d /tmp/node-resolution.XXXXXX)
  trap 'rm -rf "$work"' EXIT
  mkdir "$work/home"

  for runtime in "$@"; do
    add_runtime "$runtime"
  done

  # Upstream runtimes first, as the reference.
  upstream_order='' debian_order=''
  n=1
  while [ "$n" -le "$count" ]; do
    case $(get "$n" kind) in
      debian) debian_order="$debian_order $n" ;;
      *) upstream_order="$upstream_order $n" ;;
    esac
    n=$((n + 1))
  done
  order="$upstream_order $debian_order"

  show_runtimes
  for example in [0-9]*/; do
    example=${example%/}
    for n in $order; do
      run_checks "$n" "$example"
    done
    show_example "$example"
  done

  printf '\n'
  if [ "$mismatches" -eq 0 ]; then
    printf 'Every result matches what the examples expect.\n'
  else
    printf '%s%s result(s), marked with !, differ from what the examples expect.%s\n' \
      "$yellow" "$mismatches" "$reset"
    exit 1
  fi
}
