#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 ASSET.age AGE_IDENTITY OUTPUT_DIRECTORY" >&2
  exit 64
fi

asset=$1
identity=$2
output_directory=$3
repository_root=$(cd -- "$(diname -- "${BASH_SOURCE[0]}")/.." && pwd)
checksums="${repository_root}/SHA256SUMS"
encrypted_name=$(basename -- "${asset}")
plain_name=${encrypted_name%.age}
plain_path="${output_directory}/${plain_name}"

[[ -f "${asset}" ]] || { echo "Encrypted asset not found: ${asset}" >&2; exit 1; }
[[ -f "${identity}" ]] || { echo "age identity not found: ${identity}" >&2; exit 1; }
[[ ! -e "${plain_path}" ]] || { echo "Refusing to overwrite: ${plain_path}" >&2; exit 1; }

mkdir -p -- "${output_directory}"
(
  cd -- "$(diname -- "${asset}")"
  grep -F "  ${encrypted_name}" "${checksums}" | sha256sum --check --strict
)

age --decrypt --identity "${identity}" --output "${plain_path}" "${asset}"
(
  cd -- "${output_directory}"
  grep -F "  ${plain_name}" "${checksums}" | sha256sum --check --strict
)
tar -xzf "${plain_path}" -C "${output_directory}"
echo "Verified and extracted release into ${output_directory}"

