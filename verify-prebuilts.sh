#!/bin/sh
# Verify every prebuilt blob against the values recorded for TB305FU.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
sha256sum -c prebuilt/SHA256SUMS
