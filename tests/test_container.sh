#!/usr/bin/env bash
#
# bash_unit tests asserting the built container image (${IMAGE}) stays
# minimal: nothing but the static brush binary, no shell, no package
# manager, no Alpine userland left over from the builder stage.
#
# Run via tests/run.sh, not directly - it needs $IMAGE and $CONTAINER_ENGINE
# set up first (image build, engine detection).

# Max acceptable image size, in bytes. brush itself is ~6MB; this leaves
# headroom for binary growth while still catching an accidental regression
# back to a full Alpine base layered underneath (which would be 10x+ this).
MAX_IMAGE_SIZE_BYTES=10485760

image_files() {
  local cid
  cid="$("${CONTAINER_ENGINE}" create "${IMAGE}" -c true)"
  "${CONTAINER_ENGINE}" export "${cid}" | tar -tf -
  "${CONTAINER_ENGINE}" rm "${cid}" >/dev/null
}

test_entrypoint_is_brush() {
  assert_equals '["/brush"]' \
    "$("${CONTAINER_ENGINE}" inspect --format '{{json .Config.Entrypoint}}' "${IMAGE}")"
}

test_image_contains_only_brush_binary() {
  assert_equals "brush" "$(image_files)"
}

test_no_shell_present() {
  assert_status_code 127 \
    "${CONTAINER_ENGINE} run --rm --entrypoint /bin/sh ${IMAGE} -c true"
}

test_image_is_small() {
  local size
  size="$("${CONTAINER_ENGINE}" inspect --format '{{.Size}}' "${IMAGE}")"
  assert "[ ${size} -le ${MAX_IMAGE_SIZE_BYTES} ]" \
    "image is ${size} bytes, expected <= ${MAX_IMAGE_SIZE_BYTES}"
}
