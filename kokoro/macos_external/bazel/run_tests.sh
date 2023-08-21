#!/bin/bash
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

# The user may specify TINK_BASE_DIR for setting the base folder where the
# script should look for the dependencies of tink-py.

set -euo pipefail

# If we are running on Kokoro cd into the repository.
if [[ -n "${KOKORO_ROOT:-}" ]]; then
  TINK_BASE_DIR="$(echo "${KOKORO_ARTIFACTS_DIR}"/git*)"
  cd "${TINK_BASE_DIR}/tink_py"
fi

: "${TINK_BASE_DIR:=$(cd .. && pwd)}"

# Check for dependencies in TINK_BASE_DIR. Any that aren't present will be
# downloaded.
readonly GITHUB_ORG="https://github.com/tink-crypto"
./kokoro/testutils/fetch_git_repo_if_not_present.sh "${TINK_BASE_DIR}" \
  "${GITHUB_ORG}/tink-cc"

./kokoro/testutils/copy_credentials.sh "testdata" "all"

# TODO(b/276277854) It is not clear why this is needed.
pip3 install protobuf==3.20.3 --user
pip3 install google-cloud-kms==2.15.0 --user

TINK_PY_MANUAL_TARGETS=()
# These tests require valid credentials to access KMS services.
if [[ -n "${KOKORO_ROOT:-}" ]]; then
  TINK_PY_MANUAL_TARGETS+=(
    "//tink/integration/awskms:_aws_kms_integration_test"
    "//tink/integration/gcpkms:_gcp_kms_client_integration_test"
    "//tink/integration/gcpkms:_gcp_kms_integration_test"
  )
fi
readonly TINK_PY_MANUAL_TARGETS

cp "WORKSPACE" "WORKSPACE.bak"
sed -i '.bak' 's~# Placeholder for tink-cc override.~\
local_repository(\
    name = "tink_cc",\
    path = "../tink_cc",\
)~' WORKSPACE

./kokoro/testutils/run_bazel_tests.sh . "${TINK_PY_MANUAL_TARGETS[@]}"
mv "WORKSPACE.bak" "WORKSPACE"
