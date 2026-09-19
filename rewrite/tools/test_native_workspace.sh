#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$repo_root"

fail() {
  printf 'native workspace contract failed: %s\n' "$1" >&2
  exit 1
}

rust_count=$(rg -n '^rust = "1\.96\.1"$' mise.toml | wc -l | tr -d ' ')
[[ "$rust_count" == "1" ]] || fail "rust 1.96.1 must appear exactly once"

members=$(awk '
  /^members = \[/ { in_members = 1; next }
  in_members && /^\]/ { in_members = 0; exit }
  in_members {
    gsub(/[",[:space:]]/, "")
    if (length($0) > 0) print
  }
' native/Cargo.toml)
expected_members=$'crates/open2jam-core\ncrates/open2jam-cli'
[[ "$members" == "$expected_members" ]] || fail "workspace members differ"

[[ $(rg -c '^resolver = "3"$' native/Cargo.toml) == "1" ]] || fail "resolver differs"
[[ $(rg -c '^edition = "2024"$' native/Cargo.toml) == "1" ]] || fail "edition differs"
[[ -f native/Cargo.lock ]] || fail "Cargo.lock is missing"

for crate_root in \
  native/crates/open2jam-core/src/lib.rs \
  native/crates/open2jam-cli/src/main.rs; do
  head -n 1 "$crate_root" | rg -qx '#!\[forbid\(unsafe_code\)\]' \
    || fail "unsafe_code is not forbidden in $crate_root"
done

temp_base=${TMPDIR:-/tmp}
temp_root=""
temp_base=$(cd "$temp_base" && pwd -P) \
  || fail "temporary base is unavailable"
[[ -n "$temp_base" && "$temp_base" != "/" && "$temp_base" != "//" ]] \
  || fail "unsafe temporary base"
temp_root=$(mktemp -d "$temp_base/open2jam-native-workspace.XXXXXX") \
  || fail "temporary root creation failed"

cleanup() {
  case "$temp_root" in
    "$temp_base"/open2jam-native-workspace.*)
      rm -rf -- "$temp_root"
      ;;
    *)
      printf 'refusing unsafe temporary cleanup: %s\n' \
        "${temp_root:-<empty>}" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT

expected_stdout="$temp_root/version.expected.stdout"
actual_stdout="$temp_root/version.actual.stdout"
actual_stderr="$temp_root/version.actual.stderr"
printf '%s\n' \
  '{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":["O2JAM","OSU_MANIA","BUNDLE"],"bundleFormats":["O2JAM","OSU_MANIA","BUNDLE"]}' \
  >"$expected_stdout"

if ! mise exec -- cargo run --quiet --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked -- version \
  >"$actual_stdout" 2>"$actual_stderr"; then
  fail "version command failed"
fi
cmp -s "$expected_stdout" "$actual_stdout" \
  || fail "version stdout differs"
[[ ! -s "$actual_stderr" ]] \
  || fail "version stderr is not empty"

if ! LC_ALL=C awk '
  BEGIN {
    cargo_name = "cargo"
    rustc_name = "rustc"
    single_quote = sprintf("%c", 39)
    quoted_mask = sprintf("%c", 28)
    seen_file = 0
    shell_source = 0
    markdown_source = 0
    markdown_shell_fence = 0
    quote_state = ""
    heredoc_delimiter = ""
    heredoc_delimiter_quoted = 0
    heredoc_strip_tabs = 0
    logical_line = ""
    logical_line_number = 0
    invalid = 0
  }

  function trim(text) {
    sub(/^[[:space:]]+/, "", text)
    sub(/[[:space:]]+$/, "", text)
    return text
  }

  function command_basename(word) {
    sub(/^.*\//, "", word)
    return word
  }

  function is_tool_command(word) {
    word = command_basename(word)
    return word == cargo_name || word == rustc_name
  }

  function is_reserved_prefix(word) {
    return word == "if" || word == "then" || word == "elif" \
      || word == "while" || word == "until" || word == "do" \
      || word == "else" || word == "!" || word == "{" || word == "}"
  }

  function is_assignment(word) {
    return word ~ /^[[:alpha:]_][[:alnum:]_]*=/
  }

  function is_redirection(word) {
    return word ~ /^([[:digit:]]+)?(<>|>>|>|<<|<)/
  }

  function report_bare_command(file, line_number) {
    printf "%s:%d: Rust tool command is not launched by mise exec --\n", \
      file, line_number > "/dev/stderr"
    invalid = 1
  }

  function analyze_segment(segment, file, line_number,
      words, count, word_index, command, option, tool_index) {
    segment = trim(segment)
    if (segment == "") {
      return
    }

    count = split(segment, words, /[[:space:]]+/)
    word_index = 1
    while (word_index <= count) {
      if (words[word_index] == "" || is_reserved_prefix(words[word_index]) \
          || is_assignment(words[word_index])) {
        word_index++
        continue
      }
      if (is_redirection(words[word_index])) {
        if (words[word_index] ~ /^([[:digit:]]+)?(<>|>>|>|<<|<)$/) {
          word_index += 2
        } else {
          word_index++
        }
        continue
      }
      break
    }

    while (word_index <= count) {
      command = command_basename(words[word_index])
      if (command == "env") {
        word_index++
        while (word_index <= count) {
          option = words[word_index]
          if (is_assignment(option)) {
            word_index++
          } else if (option == "-u" || option == "--unset" \
              || option == "-C" || option == "--chdir") {
            word_index += 2
          } else if (option ~ /^-/) {
            word_index++
          } else {
            break
          }
        }
        continue
      }
      if (command == "command" || command == "exec" || command == "nohup") {
        word_index++
        while (word_index <= count && words[word_index] ~ /^-/) {
          word_index++
        }
        continue
      }
      break
    }

    if (word_index > count) {
      return
    }
    command = command_basename(words[word_index])
    if (is_tool_command(command)) {
      report_bare_command(file, line_number)
      return
    }
    if (command != "mise") {
      return
    }

    for (tool_index = word_index + 1; tool_index <= count; tool_index++) {
      if (!is_tool_command(words[tool_index])) {
        continue
      }
      if (tool_index != word_index + 3 \
          || words[word_index + 1] != "exec" \
          || words[word_index + 2] != "--" \
          || (words[tool_index] != cargo_name \
            && words[tool_index] != rustc_name)) {
        report_bare_command(file, line_number)
      }
    }
  }

  function analyze_line(text, file, line_number,
      segment, character, position) {
    segment = ""
    for (position = 1; position <= length(text); position++) {
      character = substr(text, position, 1)
      if (character ~ /[;|&()]/) {
        analyze_segment(segment, file, line_number)
        segment = ""
      } else {
        segment = segment character
      }
    }
    analyze_segment(segment, file, line_number)
  }

  function contains_tool_token(text) {
    return text ~ ("(^|[^[:alnum:]_.-])(" cargo_name "|" rustc_name \
      ")([^[:alnum:]_.-]|$)")
  }

  function clear_candidate() {
    candidate_kind = ""
    candidate_text = ""
  }

  function validate_candidate(file, line_number, remaining, allowed_prefix) {
    if (!contains_tool_token(candidate_text)) {
      clear_candidate()
      return
    }
    allowed_prefix = "^[[:space:]]*mise[[:space:]]+exec[[:space:]]+--" \
      "[[:space:]]+(cargo|rustc)([^[:alnum:]_.-]|$)"
    remaining = candidate_text
    if (candidate_text ~ allowed_prefix) {
      sub(allowed_prefix, "", remaining)
    }
    if (candidate_text ~ /[(`]/ || candidate_text !~ allowed_prefix \
        || contains_tool_token(remaining)) {
      report_bare_command(file, line_number)
    } else {
      analyze_line(candidate_text, file, line_number)
    }
    clear_candidate()
  }

  function start_candidate(kind) {
    candidate_kind = kind
    candidate_text = ""
    candidate_depth = kind == "dollar" ? 1 : 0
  }

  function feed_candidate(raw, start, file, line_number,
      position, character) {
    for (position = start; position <= length(raw); position++) {
      character = substr(raw, position, 1)
      if (character == "\\") {
        candidate_text = candidate_text character
        if (position < length(raw)) {
          position++
          candidate_text = candidate_text substr(raw, position, 1)
        }
        continue
      }
      if (candidate_kind == "dollar") {
        if (character == "(") {
          candidate_depth++
        } else if (character == ")") {
          candidate_depth--
          if (candidate_depth == 0) {
            validate_candidate(file, line_number)
            return position
          }
        }
      } else if (character == "`") {
        validate_candidate(file, line_number)
        return position
      }
      candidate_text = candidate_text character
    }
    candidate_text = candidate_text "\n"
    return 0
  }

  function consume_candidate(raw, position, file, line_number,
      character, start) {
    if (candidate_kind != "") {
      return feed_candidate(raw, position, file, line_number)
    }
    character = substr(raw, position, 1)
    if (character == "$" && substr(raw, position + 1, 1) == "(") {
      start_candidate("dollar")
      start = position + 2
    } else if (character == "`") {
      start_candidate("backtick")
      start = position + 1
    } else {
      return -1
    }
    return feed_candidate(raw, start, file, line_number)
  }

  function collect_heredoc_expansions(raw, file, line_number,
      position, character, closing) {
    for (position = 1; position <= length(raw); position++) {
      character = substr(raw, position, 1)
      if (character == "\\") {
        position++
        continue
      }
      closing = consume_candidate(raw, position, file, line_number)
      if (closing < 0) continue
      if (!closing) return
      position = closing
    }
  }

  function finish_candidate(file, line_number) {
    if (candidate_kind != "" && contains_tool_token(candidate_text)) {
      report_bare_command(file, line_number)
    }
    clear_candidate()
  }

  function mask_quoted_character(character) {
    if (character ~ /[[:space:];|&()#<]/) {
      return quoted_mask
    }
    return character
  }

  function sanitize_shell_line(raw, file, line_number,
      result, position, character, next_character, previous_character,
      started_in_quote, closing) {
    result = ""
    line_continues = 0
    heredoc_raw_position = 0
    started_in_quote = quote_state != ""
    if (started_in_quote) {
      result = "__quoted_continuation__ "
    }

    for (position = 1; position <= length(raw); position++) {
      character = substr(raw, position, 1)
      if (quote_state == "single") {
        if (character == single_quote) {
          quote_state = ""
        } else {
          result = result mask_quoted_character(character)
        }
        continue
      }
      if (quote_state == "double") {
        closing = consume_candidate(raw, position, file, line_number)
        if (closing >= 0) {
          result = result quoted_mask
          if (!closing) return result
          position = closing
        } else if (character == "\\") {
          if (position < length(raw)) {
            position++
            next_character = substr(raw, position, 1)
            result = result mask_quoted_character(next_character)
          }
        } else if (character == "\"") {
          quote_state = ""
        } else {
          result = result mask_quoted_character(character)
        }
        continue
      }

      closing = consume_candidate(raw, position, file, line_number)
      if (closing >= 0) {
        result = result quoted_mask
        if (!closing) return result
        position = closing
      } else if (character == single_quote) {
        quote_state = "single"
      } else if (character == "\"") {
        quote_state = "double"
      } else if (character == "#") {
        previous_character = position > 1 ? substr(raw, position - 1, 1) : ""
        if (position == 1 || previous_character ~ /[[:space:];|&()]/) {
          break
        }
        result = result character
      } else if (character == "\\") {
        if (position == length(raw)) {
          line_continues = 1
          break
        }
        position++
        next_character = substr(raw, position, 1)
        result = result mask_quoted_character(next_character)
      } else {
        if (heredoc_raw_position == 0 && character == "<" \
            && substr(raw, position + 1, 1) == "<" \
            && substr(raw, position + 2, 1) != "<") {
          heredoc_raw_position = position
        }
        result = result character
      }
    }
    return result
  }

  function detect_heredoc(text, raw,
      position, tail, candidate, parts, count, raw_tail, first) {
    position = index(text, "<<")
    if (position == 0 || substr(text, position + 2, 1) == "<") {
      return
    }
    tail = substr(text, position + 2)
    tail = trim(tail)
    heredoc_strip_tabs = 0
    if (substr(tail, 1, 1) == "-") {
      heredoc_strip_tabs = 1
      tail = trim(substr(tail, 2))
    }
    count = split(tail, parts, /[[:space:];|&()<>]+/)
    candidate = count > 0 ? parts[1] : ""
    if (candidate ~ /^[[:alpha:]_][[:alnum:]_]*$/) {
      heredoc_delimiter = candidate
      raw_tail = trim(substr(raw, heredoc_raw_position + 2))
      sub(/^-[[:space:]]*/, "", raw_tail)
      first = substr(raw_tail, 1, 1)
      heredoc_delimiter_quoted = first == single_quote \
        || first == "\"" || first == "\\"
    }
  }

  function finish_shell_content(file, line_number) {
    finish_candidate(file, line_number)
    if (logical_line != "") {
      analyze_line(logical_line, file, logical_line_number)
      logical_line = ""
    }
    if (quote_state != "" || heredoc_delimiter != "") {
      printf "%s:%d: unterminated shell data while checking Rust commands\n", \
        file, line_number > "/dev/stderr"
      invalid = 1
    }
    quote_state = ""
    heredoc_delimiter = ""
    heredoc_delimiter_quoted = 0
    heredoc_strip_tabs = 0
  }

  function process_shell_line(raw, file, line_number,
      comparable, clean) {
    if (heredoc_delimiter != "") {
      comparable = raw
      if (heredoc_strip_tabs) {
        sub(/^\t+/, "", comparable)
      }
      if (comparable == heredoc_delimiter) {
        finish_candidate(file, line_number)
        heredoc_delimiter = ""
        heredoc_delimiter_quoted = 0
        heredoc_strip_tabs = 0
      } else if (!heredoc_delimiter_quoted) {
        collect_heredoc_expansions(raw, file, line_number)
      }
      return
    }

    clean = sanitize_shell_line(raw, file, line_number)
    if (logical_line == "") {
      logical_line = clean
      logical_line_number = line_number
    } else {
      logical_line = logical_line " " clean
    }
    if (line_continues) {
      return
    }
    detect_heredoc(logical_line, raw)
    analyze_line(logical_line, file, logical_line_number)
    logical_line = ""
  }

  {
    if (FNR == 1) {
      if (seen_file) {
        finish_shell_content(previous_file, previous_line_number)
      }
      seen_file = 1
      previous_file = FILENAME
      previous_line_number = 1
      shell_source = FILENAME ~ /\.sh$/ \
        || $0 ~ /^#!.*([[:space:]\/])(ba|z|k)?sh([[:space:]]|$)/
      markdown_source = FILENAME ~ /\.md$/
      markdown_shell_fence = 0
      quote_state = ""
      heredoc_delimiter = ""
      heredoc_delimiter_quoted = 0
      heredoc_strip_tabs = 0
      logical_line = ""
    }
    previous_line_number = FNR

    if (markdown_source) {
      if (!markdown_shell_fence \
          && $0 ~ /^```(bash|sh|shell)[[:space:]]*$/) {
        markdown_shell_fence = 1
        next
      }
      if (markdown_shell_fence && $0 ~ /^```[[:space:]]*$/) {
        finish_shell_content(FILENAME, FNR)
        markdown_shell_fence = 0
        next
      }
      if (!markdown_shell_fence) {
        next
      }
      process_shell_line($0, FILENAME, FNR)
      next
    }

    if (shell_source) {
      process_shell_line($0, FILENAME, FNR)
    }
  }

  END {
    if (seen_file) {
      finish_shell_content(previous_file, previous_line_number)
    }
    if (invalid) {
      exit 1
    }
  }
' rewrite/tools/* native/README.md; then
  fail "bare Rust tool command found"
fi

printf 'native workspace contract passed\n'
