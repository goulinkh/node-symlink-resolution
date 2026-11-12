# Sourced by ../run.sh: builds one image per runtime, runs each example in a
# fresh container for each runtime, and prints the results side by side.

# Runtimes with stock module resolution first, as the reference.
default_runtimes='nodejs.org fedora-43 debian-13 ubuntu-26.04'

label_width=32
tab=$(printf '\t')
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

pick_engine() {
  engine=${CONTAINER_ENGINE:-}
  for candidate in podman docker; do
    [ -n "$engine" ] && break
    command -v "$candidate" >/dev/null 2>&1 && engine=$candidate
  done
  if [ -z "$engine" ]; then
    echo "This needs podman or docker." >&2
    exit 1
  fi
}

image() {
  printf 'node-resolution-examples:%s' "$1"
}

kind_of() {
  sed -n 's/^# kind: *//p' "runtimes/$1.Containerfile"
}

group_label() {
  case $1 in
    debian) printf 'Debian' ;;
    *) printf 'Upstream' ;;
  esac
}

in_container() {
  runtime=$1
  shift
  "$engine" run --rm --security-opt label=disable -v "$PWD:/examples:ro" \
    "$(image "$runtime")" sh /examples/lib/inside.sh "$@"
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
  kind=$(kind_of "$1")
  if [ -n "$previous_kind" ] && [ "$kind" != "$previous_kind" ]; then
    printf '%s|%s ' "$dim" "$reset"
  fi
  previous_kind=$kind
}

build_images() {
  for runtime in $runtimes; do
    printf '%sBuilding the %s image...%s\n' "$dim" "$runtime" "$reset" >&2
    if ! "$engine" build -t "$(image "$runtime")" \
      -f "runtimes/$runtime.Containerfile" runtimes >"$results/build.log" 2>&1; then
      cat "$results/build.log" >&2
      exit 1
    fi
  done
}

show_runtimes() {
  printf '\n%sRuntimes%s\n\n' "$bold" "$reset"
  printf '  %s%s%s%s%s%s\n' "$dim" "$(pad Runtime 15)" "$(pad Group 10)" "$(pad Node.js 11)" \
    "$(pad /usr/share/node_modules 25)" "require() also searches$reset"
  for runtime in $runtimes; do
    in_container "$runtime" about >"$results/about" 2>&1
    version=$(sed -n 1p "$results/about")
    link=$(sed -n 2p "$results/about")
    [ "$link" = none ] || link="-> $link"
    first=1
    for folder in $(sed -n 3p "$results/about"); do
      if [ "$first" = 1 ]; then
        printf '  %s%s%s%s%s\n' "$(pad "$runtime" 15)" "$(pad "$(group_label "$(kind_of "$runtime")")" 10)" \
          "$(pad "$version" 11)" "$(pad "$link" 25)" "$folder"
        first=0
      else
        printf '  %61s%s\n' '' "$folder"
      fi
    done
  done
  cat <<EOF

  Debian's nodejs package, which Ubuntu also uses, differs from the
  upstream build in two ways:

  - Node.js is patched so that require() also searches /usr/share/nodejs,
    from any directory. This is like a NODE_PATH that is always set.
  - The package ships the link /usr/share/node_modules -> nodejs.
EOF
}

run_example() {
  for runtime in $runtimes; do
    in_container "$runtime" "/examples/$1" \
      >"$results/$1.$runtime" 2>"$results/$1.$runtime.err"
  done
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
    for runtime in $runtimes; do
      kind=$(kind_of "$runtime")
      if [ "$kind" != "$previous_kind" ]; then
        if [ -n "$previous_kind" ]; then
          printf '%s%s|%s ' "$(pad "$label" "$group_width")" "$dim" "$reset"
        fi
        label="$bold$(group_label "$kind")$reset"
        group_width=$((${#bold} + ${#reset}))
      fi
      group_width=$((group_width + $(column_width "$runtime")))
      previous_kind=$kind
    done
    printf '%s\n' "$label"

    # Second line: the runtime names.
    printf '    %s' "$(pad '' "$label_width")"
    previous_kind=''
    for runtime in $runtimes; do
      separator "$runtime"
      printf '%s%s%s' "$dim" "$(pad "$runtime" "$(column_width "$runtime")")" "$reset"
    done
    printf '\n'
  }

  step() {
    header
    printf '    %s$ %s%s\n' "$dim" "$1" "$reset"
    if [ "$verbose" = 1 ] && [ "$2" != "$1" ]; then
      printf '      %s(runs: %s)%s\n' "$dim" "$2" "$reset"
    fi
  }

  check() {
    header
    index=$((index + 1))
    printf '    %s' "$(pad "$1" "$label_width")"
    previous_kind=''
    for runtime in $runtimes; do
      separator "$runtime"
      result=$(sed -n "${index}p" "$results/$example.$runtime")
      outcome=${result%%"$tab"*}
      [ -n "$outcome" ] || outcome=error
      expected=$(expected_for "$2" "$(kind_of "$runtime")")
      case $outcome in works) color=$green ;; *) color=$red ;; esac
      cell=$outcome
      if [ "$outcome" != "$expected" ]; then
        color=$yellow
        cell="$outcome !"
        mismatches=$((mismatches + 1))
      fi
      printf '%s%s%s' "$color" "$(pad "$cell" "$(column_width "$runtime")")" "$reset"
    done
    printf '\n'
    if [ "$verbose" = 1 ]; then
      printf '      %s$ %s%s\n' "$dim" "$3" "$reset"
      for runtime in $runtimes; do
        detail=$(sed -n "${index}p" "$results/$example.$runtime")
        printf '      %s%s%s%s\n' "$dim" "$(pad "$runtime" 15)" "${detail#*"$tab"}" "$reset"
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

  for runtime in $runtimes; do
    if [ -s "$results/$example.$runtime.err" ]; then
      printf '    %s%s: %s%s\n' "$yellow" "$runtime" "$(cat "$results/$example.$runtime.err")" "$reset"
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

  runtimes=${*:-$default_runtimes}
  for runtime in $runtimes; do
    if [ ! -f "runtimes/$runtime.Containerfile" ]; then
      echo "Unknown runtime: $runtime (see runtimes/)" >&2
      exit 2
    fi
  done

  pick_engine
  results=$(mktemp -d)
  trap 'rm -rf "$results"' EXIT

  build_images
  show_runtimes
  for example in [0-9]*/; do
    example=${example%/}
    run_example "$example"
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
