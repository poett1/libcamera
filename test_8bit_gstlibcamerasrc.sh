#!/bin/bash

set -euo pipefail

# Run an 8-bit mode test pipeline with the locally built gstlibcamera plugin.
# Should get ~137 FPS with OV9281 at 1280x800 on a Pi 5
# Override defaults with environment variables, for example:
#   FPS=120 WIDTH=1280 HEIGHT=800 ./test_gstreamer.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

BUILD_DIR="${BUILD_DIR:-}"
if [[ -z "${BUILD_DIR}" ]]; then
	if [[ -f "${SCRIPT_DIR}/build-local/src/gstreamer/libgstlibcamera.so" && -d "${SCRIPT_DIR}/build-local/src/libcamera" ]]; then
		BUILD_DIR="${SCRIPT_DIR}/build-local"
	elif [[ -f "${SCRIPT_DIR}/build/src/gstreamer/libgstlibcamera.so" && -d "${SCRIPT_DIR}/build/src/libcamera" ]]; then
		BUILD_DIR="${SCRIPT_DIR}/build"
	else
		echo "No usable build directory found. Set BUILD_DIR or run meson setup + ninja first." >&2
		exit 1
	fi
fi

WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-800}"
FPS="${FPS:-143}"
SENSOR_MODE="${SENSOR_MODE:-1280:800:8:U}"
PIXEL_FORMAT="${PIXEL_FORMAT:-R8}"
STREAM_ROLE="${STREAM_ROLE:-raw}"
CAPS_FORMAT="${CAPS_FORMAT:-}"
LOCK_FPS="${LOCK_FPS:-1}"

# By default, use only the selected build output to avoid loading an older plugin.
if [[ "${APPEND_EXISTING_PATHS:-0}" == "1" ]]; then
	export GST_PLUGIN_PATH="${BUILD_DIR}/src/gstreamer${GST_PLUGIN_PATH:+:${GST_PLUGIN_PATH}}"
	export LD_LIBRARY_PATH="${BUILD_DIR}/src/libcamera${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
else
	export GST_PLUGIN_PATH="${BUILD_DIR}/src/gstreamer"
	export LD_LIBRARY_PATH="${BUILD_DIR}/src/libcamera"
fi
export GST_REGISTRY_1_0="${BUILD_DIR}/gst-registry-local.bin"

echo "Using build dir: ${BUILD_DIR}"
echo "GST_PLUGIN_PATH=${GST_PLUGIN_PATH}"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
gst-inspect-1.0 libcamerasrc | grep Filename || true

GST_DEBUG_VALUE="${GST_DEBUG:-libcamera*:4,libcamerasrc:6}"

CAPS="video/x-raw,width=${WIDTH},height=${HEIGHT}"
if [[ "${LOCK_FPS}" == "1" ]]; then
	CAPS="${CAPS},framerate=${FPS}/1"
fi
if [[ -n "${CAPS_FORMAT}" ]]; then
	CAPS="${CAPS},format=${CAPS_FORMAT}"
fi

echo "Requested preferred-pixel-format=${PIXEL_FORMAT}"
echo "Requested sensor-mode=${SENSOR_MODE}"
echo "Requested stream-role=${STREAM_ROLE}"
echo "LOCK_FPS=${LOCK_FPS} (set LOCK_FPS=1 to force framerate=${FPS}/1)"
echo "Caps filter=${CAPS}"


gst-launch-1.0 -ve \
	libcamerasrc src::stream-role="${STREAM_ROLE}" sensor-mode="${SENSOR_MODE}" preferred-pixel-format="${PIXEL_FORMAT}" ! \
	"${CAPS}" ! \
	fpsdisplaysink video-sink=fakesink sync=false text-overlay=false


