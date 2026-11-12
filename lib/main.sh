# Sourced by ../run.sh: sets up the runtimes, runs each example once per
# runtime in a fresh root directory, $ROOT, and prints the results side by
# side.
#
# Each example directory has files/, copied into $ROOT, and checks.sh, which
# uses these commands:
#
#   title TEXT                     the heading, followed by what the example
#                                  installs: each directory in files/ and the
#                                  packages its code loads
#   step TEXT COMMAND              changes the files; TEXT is what is shown
#   check LABEL EXPECTED COMMAND   runs COMMAND, which works or fails.
#                                  EXPECTED is one outcome for every runtime,
#                                  or one per group: 'debian=works upstream=fails'
#   note TEXT                      a line of the explanation after the results

label_width=32
name_width=7
tab=$(printf '\t')
count=0
mismatches=0
verbose=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  color=1
  esc=$(printf '\033')
  reset="$esc[0m" bold="$esc[1m" dim="$esc[2m" reverse="$esc[7m"
  red="$esc[31m" green="$esc[32m" yellow="$esc[33m" blue="$esc[34m" magenta="$esc[35m" cyan="$esc[36m"
else
  color=0
  reset='' bold='' dim='' reverse='' red='' green='' yellow='' blue='' magenta='' cyan=''
fi

usage() {
  sed -n '2,/^$/s/^# \{0,1\}//p' run.sh
}

# The packages that the examples install, as a pattern: foo|bar|...
packages=$(for package in [0-9]*/files/usr/share/nodejs/*/; do basename "$package"; done |
  sort -u | paste -s -d '|' -)

# Colors the code in a line of text: paths in blue, require and import in
# magenta, package names in cyan, and NODE_PATH and options in bold.
highlight() {
  if [ "$color" = 0 ]; then
    printf '%s\n' "$1"
    return
  fi
  printf '%s\n' "$1" | sed -E \
    -e "s#(^|[ (])([[:alnum:]_.\$@-]*/[[:alnum:]_./@-]*[[:alnum:]_@-])#\\1$blue\\2$reset#g" \
    -e "s#(^|[ (])(\\\$ROOT)([^/[:alnum:]]|\$)#\\1$blue\\2$reset\\3#g" \
    -e "s#(^|[ (])('[^' ]*')#\\1$cyan\\2$reset#g" \
    -e "s#(^|[^[:alnum:]_])(require|import)([^[:alnum:]_]|\$)#\\1$magenta\\2$reset\\3#g" \
    -e "s#(^|[ (])(NODE_PATH|--[a-z-]+)#\\1$bold\\2$reset#g" \
    -e "s#(^|[^[:alnum:]_'/.\$-])($packages)([^[:alnum:]_/-]|\$)#\\1$cyan\\2$reset\\3#g"
}

# Details of runtime N are stored as files in $work/runtimeN/.
get() {
  cat "$work/runtime$1/$2"
}

# Downloads runtime NAME into runtimes/NAME/ on first use.
add_runtime() {
  name=$1
  dir=runtimes/$name
  if [ ! -d "$dir" ]; then
    python3 lib/download.py "$name" || exit $?
  fi

  # A Debian runtime is a set of extracted packages, a nodejs.org runtime
  # is the release tarball.
  if [ -f "$dir/usr/bin/node" ]; then
    binary=$dir/usr/bin/node
  else
    binary=$dir/bin/node
  fi
  libraries=''
  for libraries_dir in "$dir"/usr/lib/*-linux-gnu; do
    [ -d "$libraries_dir" ] && libraries=$PWD/$libraries_dir
  done

  [ "${#name}" -gt "$name_width" ] && name_width=${#name}
  count=$((count + 1))
  mkdir "$work/runtime$count"
  printf '%s' "$name" >"$work/runtime$count/name"
  printf '%s' "$dir" >"$work/runtime$count/dir"
  printf '%s' "$binary" >"$work/runtime$count/binary"
  printf '%s' "$libraries" >"$work/runtime$count/libraries"

  run_checks "$count" about
  if [ -s "$work/runtime$count/about.err" ] || [ ! -s "$work/runtime$count/about.out" ]; then
    printf 'Cannot run %s:\n%s\n' "$binary" "$(cat "$work/runtime$count/about.err")" >&2
    exit 1
  fi
  sed -n 1p "$work/runtime$count/about.out" >"$work/runtime$count/kind"
}

# Prepares a fresh root directory for runtime N and EXAMPLE, in $root.
prepare_root() {
  root=$work/runtime$1/$2
  dir=$(get "$1" dir)
  mkdir -p "$root/usr/bin"
  if [ -f "$dir/usr/bin/node" ]; then
    # Debian's node finds the folders it searches from its own location, so
    # it has to be a real file in the root, not a symbolic link. usr/share
    # has the node_modules link and the files of node's built-in modules.
    cp "$dir/usr/bin/node" "$root/usr/bin/node"
    cp -RP "$dir/usr/share" "$root/usr/"
  else
    ln -s "$PWD/$dir/bin/node" "$root/usr/bin/node"
  fi
  if [ -d "$2/files" ]; then
    cp -R "$2/files/." "$root/"
  fi
}

run_checks() {
  prepare_root "$1" "$2"
  env -u NODE_PATH -u NODE_OPTIONS ROOT="$root" HOME="$work/home" PATH="$root/usr/bin:$PATH" \
    LD_LIBRARY_PATH="$(get "$1" libraries)" \
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

# Prints N horizontal line characters.
line() {
  i=0
  while [ "$i" -lt "$1" ]; do
    printf '─'
    i=$((i + 1))
  done
}

# Each result column fits the runtime name and the longest cell, "✓ works !".
column_width() {
  width=${#1}
  [ "$width" -lt 9 ] && width=9
  echo $((width + 2))
}

# Prints a separator before the first column of each group but the first.
separator() {
  kind=$(get "$1" kind)
  if [ -n "$previous_kind" ] && [ "$kind" != "$previous_kind" ]; then
    printf '%s│%s ' "$dim" "$reset"
  fi
  previous_kind=$kind
}

# Prints a heading: " TEXT " in reverse video, or "TEXT" without colors.
heading() {
  if [ "$color" = 1 ]; then
    printf '\n%s%s %s %s %s%s%s\n' "$reverse" "$bold" "$1" "$reset" "$bold" "$2" "$reset"
  else
    printf '\n%s\n' "$1${2:+  $2}"
  fi
}

# An explanation: a line of text after a bar.
explain() {
  printf '    %s│%s%s\n' "$dim" "$reset" "${1:+ $(highlight "$1")}"
}

show_runtimes() {
  heading Runtimes ''
  name_column=$((name_width + 2))
  printf '\n    %s%s%s%s%s%s\n' "$dim" "$(pad Runtime "$name_column")" "$(pad Group 10)" "$(pad Node.js 11)" Binary "$reset"
  for n in $order; do
    printf '    %s%s%s%s%s%s%s\n' "$(pad "$(get "$n" name)" "$name_column")" \
      "$bold" "$(pad "$(group_label "$(get "$n" kind)")" 10)" "$reset" \
      "$(pad "$(sed -n 2p "$work/runtime$n/about.out")" 11)" "$blue$(get "$n" binary)" "$reset"
  done

  printf '\n    %s\n\n' "$(highlight 'Folders that require() searches as a last resort:')"
  for n in $order; do
    label=$(get "$n" name)
    for folder in $(sed -n 3p "$work/runtime$n/about.out"); do
      printf '    %s%s%s%s\n' "$(pad "$label" "$name_column")" "$blue" "$folder" "$reset"
      label=''
    done
  done

  printf '\n'
  explain 'Each example runs in a fresh root directory, $ROOT, which stands in'
  explain 'for /. The runtime'"'"'s node is $ROOT/usr/bin/node.'
  explain ''
  explain 'Debian'"'"'s nodejs package, which Ubuntu also uses, differs from'
  explain 'upstream Node.js in two ways:'
  explain '• Node.js is patched so that require() also searches'
  explain '  /usr/share/nodejs, relative to the node binary. That'"'"'s why the'
  explain '  Debian runtime'"'"'s folders above are under $ROOT.'
  explain '• The package installs the link /usr/share/node_modules -> nodejs,'
  explain '  so roots for Debian runtimes have it too.'

  if [ -z "$debian_order" ]; then
    printf '\n    %sNo Debian runtime: add debian-13, which needs Linux.%s\n' "$yellow" "$reset"
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

# Prints one line per package or application in EXAMPLE/files, with the
# packages its code loads, tab-separated: packages before applications, and
# those that load nothing first.
layout() {
  (cd "$1/files" && find . -type f \( -name '*.js' -o -name '*.cjs' -o -name '*.mjs' \)) |
    while read -r file; do
      path=${file#.}
      case $path in
        /usr/share/nodejs/*)
          package=${path#/usr/share/nodejs/}
          directory=/usr/share/nodejs/${package%%/*}
          ;;
        *) directory=${path%/*} ;;
      esac
      printf '%s\t\n' "$directory"
      grep -oE "require\('[^']+'\)|from '[^']+'|import\('[^']+'\)" "$1/files$path" |
        sed -E "s/.*'([^']+)'.*/\1/" | sed "s|^|$directory$tab|"
    done |
    sort -u |
    awk -F '\t' '
      !($1 in loads) { loads[$1] = ""; order[++count] = $1 }
      $2 != "" { loads[$1] = loads[$1] (loads[$1] == "" ? "" : ", ") $2 }
      END {
        for (i = 1; i <= count; i++) {
          d = order[i]
          printf "%d%d\t%s\t%s\n", d !~ /^\/usr\/share\/nodejs\//, loads[d] != "", d, loads[d]
        }
      }' |
    sort | cut -f 2-
}

show_layout() {
  layout "$1" >"$work/layout"
  width=0
  while IFS=$tab read -r directory loads; do
    [ "${#directory}" -gt "$width" ] && width=${#directory}
  done <"$work/layout"
  printf '\n'
  while IFS=$tab read -r directory loads; do
    if [ -n "$loads" ]; then
      printf '    %s%s%s%sloads%s %s%s%s\n' "$blue" "$(pad "$directory" $((width + 4)))" "$reset" \
        "$dim" "$reset" "$cyan" "$loads" "$reset"
    else
      printf '    %s%s%s\n' "$blue" "$directory" "$reset"
    fi
  done <"$work/layout"
}

show_example() {
  example=$1
  index=0
  header_pending=1
  notes_started=0

  title() {
    heading "${example%%-*}" "$1"
    show_layout "$example"
  }

  # The column headings: one label per group of runtimes, then the runtime
  # names. Printed before the first check or step.
  header() {
    [ "$header_pending" = 1 ] || return 0
    header_pending=0

    table_width=$label_width
    printf '\n    %s' "$(pad '' "$label_width")"
    previous_kind=''
    group_width=0
    for n in $order; do
      kind=$(get "$n" kind)
      if [ "$kind" != "$previous_kind" ]; then
        if [ -n "$previous_kind" ]; then
          printf '%s%s│%s ' "$(pad "$label" "$group_width")" "$dim" "$reset"
          table_width=$((table_width + 2))
        fi
        label="$bold$(group_label "$kind")$reset"
        group_width=$((${#bold} + ${#reset}))
      fi
      width=$(column_width "$(get "$n" name)")
      group_width=$((group_width + width))
      table_width=$((table_width + width))
      previous_kind=$kind
    done
    printf '%s\n' "$label"

    printf '    %s' "$(pad '' "$label_width")"
    previous_kind=''
    for n in $order; do
      separator "$n"
      name=$(get "$n" name)
      printf '%s%s%s' "$dim" "$(pad "$name" "$(column_width "$name")")" "$reset"
    done
    printf '\n'
  }

  # A step changes the files: a line between the checks before and after.
  step() {
    header
    fill=$((table_width - ${#1} - 6))
    [ "$fill" -lt 2 ] && fill=2
    printf '    %s── $%s %s %s%s%s\n' "$dim" "$reset" "$(highlight "$1")" "$dim" "$(line "$fill")" "$reset"
    if [ "$verbose" = 1 ]; then
      printf '      %s(runs: %s)%s\n' "$dim" "$2" "$reset"
    fi
  }

  check() {
    header
    index=$((index + 1))

    # "bar: import 'foo' (no link)": where the code runs is dimmed, and so is
    # a remark in parentheses at the end.
    case $1 in
      *': '*) where="${1%%: *}: " what=${1#*: } ;;
      *) where='' what=$1 ;;
    esac
    remark=''
    case $what in
      *' ('*')') remark=" (${what##* (}" what=${what% (*} ;;
    esac
    printf '    %s%s%s%s%s%s%s%s' "$dim" "$where" "$reset" "$(highlight "$what")" "$dim" "$remark" "$reset" \
      "$(pad '' $((label_width - ${#where} - ${#what} - ${#remark})))"

    previous_kind=''
    for n in $order; do
      separator "$n"
      result=$(sed -n "${index}p" "$work/runtime$n/$example.out")
      outcome=${result%%"$tab"*}
      [ -n "$outcome" ] || outcome=error
      expected=$(expected_for "$2" "$(get "$n" kind)")
      case $outcome in
        works) mark='✓' cell_color=$green ;;
        *) mark='✗' cell_color=$red ;;
      esac
      cell=$outcome
      if [ "$outcome" != "$expected" ]; then
        cell_color=$bold$yellow
        cell="$outcome !"
        mismatches=$((mismatches + 1))
      fi
      printf '%s%s %s%s' "$cell_color" "$mark" "$(pad "$cell" $(($(column_width "$(get "$n" name)") - 2)))" "$reset"
    done
    printf '\n'

    if [ "$verbose" = 1 ]; then
      printf '      %s$ %s%s\n' "$dim" "$3" "$reset"
      for n in $order; do
        detail=$(sed -n "${index}p" "$work/runtime$n/$example.out")
        case $detail in works*) detail_color=$green ;; *) detail_color=$red ;; esac
        printf '      %s%s%s%s%s\n' "$dim" "$(pad "$(get "$n" name)" "$((name_width + 2))")" \
          "$detail_color" "${detail#*"$tab"}" "$reset"
      done
    fi
  }

  note() {
    if [ "$notes_started" = 0 ]; then
      printf '\n'
      notes_started=1
    fi
    explain "$1"
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
    [ "$(uname -s)" = Linux ] && set -- "$@" debian-13
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
    printf '%s✓ Every result matches what the examples expect.%s\n' "$green" "$reset"
  else
    printf '%s! %s result(s), marked with !, differ from what the examples expect.%s\n' \
      "$bold$yellow" "$mismatches" "$reset"
    exit 1
  fi
}
