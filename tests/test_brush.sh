#!/usr/bin/env bash
#
# bash_unit tests for brush's shell behavior, exercised through the built
# container image (${IMAGE})
#
# Run via tests/run.sh, not directly - it needs $IMAGE and $CONTAINER_ENGINE

run_brush() {
  "${CONTAINER_ENGINE}" run --rm "${IMAGE}" -c "$1"
}

test_prints_version() {
  assert_matches "^brush [0-9]" "$("${CONTAINER_ENGINE}" run --rm --entrypoint /brush "${IMAGE}" --version)"
}

test_echo() {
  assert_equals "hello world" "$(run_brush 'echo hello world')"
}

test_exit_code_success() {
  assert_status_code 0 "run_brush 'exit 0'"
}

test_exit_code_propagates() {
  assert_status_code 42 "run_brush 'exit 42'"
}

test_variable_expansion() {
  assert_equals "foo-bar" "$(run_brush 'x=foo; echo "$x-bar"')"
}

test_command_substitution() {
  assert_equals "result: nested" "$(run_brush 'echo "result: $(echo nested)"')"
}

test_arithmetic_expansion() {
  assert_equals "14" "$(run_brush 'echo $((2 + 3 * 4))')"
}

test_builtin_pipeline() {
  assert_equals "read:hi" "$(run_brush 'echo hi | { read x; echo "read:$x"; }')"
}

test_if_conditional() {
  assert_equals "yes" "$(run_brush 'if [ 1 -eq 1 ]; then echo yes; else echo no; fi')"
}

test_string_comparison() {
  assert_equals "match" "$(run_brush '[ "abc" = "abc" ] && echo match')"
}

test_for_loop() {
  assert_equals "$(printf 'n=1\nn=2\nn=3')" "$(run_brush 'for i in 1 2 3; do echo "n=$i"; done')"
}

test_function_definition_and_call() {
  assert_equals "hi world" "$(run_brush 'greet() { echo "hi $1"; }; greet world')"
}

test_last_status_variable() {
  assert_equals "after:1" "$(run_brush 'false; echo "after:$?"')"
}
