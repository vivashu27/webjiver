#!/usr/bin/env bash

###############################################################################
# webjiver - Lightweight recon + endpoint collector
#
# Original project: `webjiver.sh` from `vivashu27/webjiver`
#   https://raw.githubusercontent.com/vivashu27/webjiver/main/webjiver.sh
#
# This version adds:
# - Non-interactive CLI flags (-d, -o, etc.)
# - Safer temp handling and output directories
# - Basic error handling and tool checks
# - Optional extra tooling integrations (amass, nuclei, dalfox, katana/hakrawler)
# - Colorful, structured logging
###############################################################################

set -euo pipefail

VERSION="1.1.0-improved"

SCRIPT_NAME="$(basename "$0")"
BASE_DIR="$(pwd)"
TMP_DIR="$(mktemp -d -p "${TMPDIR:-/tmp}" webjiver.XXXXXX)"
OUT_DIR="${BASE_DIR}/webjiver-output"

DOMAIN=""
OUTPUT_FILE=""
ENABLE_AMASS=false
ENABLE_KNOCKPY=false
ENABLE_NUCLEI=false
ENABLE_DALFOX=false
ENABLE_TECH_PROBE=true
ENABLE_PARAMSPIDER=true
ENABLE_HAKRAWLER=true
ENABLE_URLFINDER=true
HTTP_STATUS_CODES="200,301,302,403,404"
TOP_PORTS="1000"

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

log_info()  { echo -e "${BLUE}[i]${NC} $*"; }
log_good()  { echo -e "${GREEN}[+]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[-]${NC} $*" >&2; }

cleanup() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

usage() {
  cat <<EOF
${SCRIPT_NAME} v${VERSION}

Usage:
  ${SCRIPT_NAME} -d example.com -o results.txt [options]

Required:
  -d, --domain        Root domain to scan (e.g. example.com)
  -o, --output        Output file name (saved under ./webjiver-output/)

Discovery options:
  --no-tech           Disable httpx technology detection
  --no-paramspider    Disable ParamSpider parameter discovery
  --no-hakrawler      Disable Hakrawler crawling
  --no-urlfinder      Disable urlfinder extraction

Extra tools (if installed):
  --amass             Use amass for additional subdomains
  --knockpy           Use knockpy for subdomain bruteforce + passive recon
  --nuclei            Run nuclei against live HTTP targets
  --dalfox            Run dalfox on discovered URLs (can be noisy)

Other:
  --top-ports N       Use top N ports in naabu (default: ${TOP_PORTS})
  --status-codes CSV  HTTP status codes for httpx (default: ${HTTP_STATUS_CODES})
  -h, --help          Show this help and exit

Notes:
  - Output is written to: \${OUT_DIR}/\${OUTPUT_FILE}
  - This script expects the following tools on PATH:
    subfinder, assetfinder, naabu, httpx, uro
  - Optional: amass, knockpy, paramspider, hakrawler, urlfinder, nuclei, dalfox

Original source:
  https://raw.githubusercontent.com/vivashu27/webjiver/main/webjiver.sh
EOF
}

require_tool() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    log_error "Required tool '${bin}' is not installed or not in PATH."
    exit 1
  fi
}

check_optional_tool() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    log_warn "Optional tool '${bin}' not found; related functionality will be skipped."
    return 1
  fi
  return 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain)
        DOMAIN="$2"; shift 2;;
      -o|--output)
        OUTPUT_FILE="$2"; shift 2;;
      --amass)
        ENABLE_AMASS=true; shift;;
      --knockpy)
        ENABLE_KNOCKPY=true; shift;;
      --nuclei)
        ENABLE_NUCLEI=true; shift;;
      --dalfox)
        ENABLE_DALFOX=true; shift;;
      --no-tech)
        ENABLE_TECH_PROBE=false; shift;;
      --no-paramspider)
        ENABLE_PARAMSPIDER=false; shift;;
      --no-hakrawler)
        ENABLE_HAKRAWLER=false; shift;;
      --no-urlfinder)
        ENABLE_URLFINDER=false; shift;;
      --top-ports)
        TOP_PORTS="$2"; shift 2;;
      --status-codes)
        HTTP_STATUS_CODES="$2"; shift 2;;
      -h|--help)
        usage; exit 0;;
      *)
        log_error "Unknown argument: $1"
        usage
        exit 1;;
    esac
  done

  if [[ -z "${DOMAIN}" || -z "${OUTPUT_FILE}" ]]; then
    log_error "Both --domain and --output are required."
    echo
    usage
    exit 1
  fi
}

main() {
  parse_args "$@"

  mkdir -p "$OUT_DIR"
  local OUTPUT_PATH="${OUT_DIR}/${OUTPUT_FILE}"

  log_info "Using temp dir: ${TMP_DIR}"
  log_info "Output will be saved to: ${OUTPUT_PATH}"

  require_tool subfinder
  require_tool assetfinder
  require_tool naabu
  require_tool httpx
  require_tool uro

  if $ENABLE_PARAMSPIDER; then
    check_optional_tool paramspider || ENABLE_PARAMSPIDER=false
  fi
  if $ENABLE_HAKRAWLER; then
    check_optional_tool hakrawler || ENABLE_HAKRAWLER=false
  fi
  if $ENABLE_URLFINDER; then
    check_optional_tool urlfinder || ENABLE_URLFINDER=false
  fi
  if $ENABLE_AMASS; then
    check_optional_tool amass || ENABLE_AMASS=false
  fi
  if $ENABLE_KNOCKPY; then
    check_optional_tool knockpy || ENABLE_KNOCKPY=false
  fi
  if $ENABLE_NUCLEI; then
    check_optional_tool nuclei || ENABLE_NUCLEI=false
  fi
  if $ENABLE_DALFOX; then
    check_optional_tool dalfox || ENABLE_DALFOX=false
  fi

  local DOM_TMP="${TMP_DIR}/dom.tmp"
  local PORTS_TMP="${TMP_DIR}/ports.tmp"
  local HTTPS_TMP="${TMP_DIR}/https.tmp"
  local VALIDHTTP_TMP="${TMP_DIR}/validhttp.tmp"
  local OUTPUT_TMP="${TMP_DIR}/output.tmp"

  log_good "Finding subdomains for ${DOMAIN}..."
  subfinder -silent -d "${DOMAIN}" > "${TMP_DIR}/d.tmp"
  assetfinder "${DOMAIN}" >> "${TMP_DIR}/d.tmp"

  if $ENABLE_AMASS; then
    log_good "Running amass (this may take a while)..."
    amass enum -passive -d "${DOMAIN}" -nocolor -silent -o "${TMP_DIR}/amass.tmp" || true
    cat "${TMP_DIR}/amass.tmp" >> "${TMP_DIR}/d.tmp" 2>/dev/null || true
  fi

  if $ENABLE_KNOCKPY; then
    log_good "Running knockpy subdomain scan (recon + bruteforce)..."
    knockpy -d "${DOMAIN}" --recon --bruteforce --silent \
      --save "${OUT_DIR}/knockpy-report" > "${TMP_DIR}/knockpy.tmp" 2>/dev/null || true
    if [[ -s "${TMP_DIR}/knockpy.tmp" ]]; then
      # Extract subdomain hostnames from knockpy output
      grep -oP '[\w.-]+\.'"${DOMAIN}" "${TMP_DIR}/knockpy.tmp" >> "${TMP_DIR}/d.tmp" 2>/dev/null || true
    fi
    log_good "Knockpy report saved to: ${OUT_DIR}/knockpy-report/"
  fi

  sort -u "${TMP_DIR}/d.tmp" > "${DOM_TMP}"
  rm -f "${TMP_DIR}/d.tmp"

  if [[ ! -s "${DOM_TMP}" ]]; then
    log_error "No subdomains discovered. Exiting."
    exit 1
  fi

  log_good "Finding open ports with naabu (top ${TOP_PORTS} ports)..."
  naabu -silent -top-ports "${TOP_PORTS}" -list "${DOM_TMP}" -o "${PORTS_TMP}"

  if [[ ! -s "${PORTS_TMP}" ]]; then
    log_warn "No open ports discovered. Continuing with HTTP enumeration may yield no results."
  fi

  sed -e 's#^#https://#g' "${PORTS_TMP}" > "${HTTPS_TMP}"
  sed -e 's#^#http://#g' "${PORTS_TMP}" >> "${HTTPS_TMP}"

  log_good "Checking HTTP connectivity with httpx..."
  httpx -silent -mc "${HTTP_STATUS_CODES}" -nc -l "${HTTPS_TMP}" -o "${VALIDHTTP_TMP}"

  if [[ ! -s "${VALIDHTTP_TMP}" ]]; then
    log_warn "No live HTTP targets found by httpx."
  fi

  if $ENABLE_TECH_PROBE; then
    log_good "Running httpx technology detection on live targets..."
    httpx -silent -title -tech-detect -status-code -l "${VALIDHTTP_TMP}" -o "${OUT_DIR}/${DOMAIN}-httpx-tech.txt" || true
  fi

  log_good "Spidering and discovering endpoints..."

  if $ENABLE_PARAMSPIDER; then
    log_info "Running ParamSpider..."
    paramspider -l "${DOM_TMP}" -o "${TMP_DIR}/paramspider" >/dev/null 2>&1 || true
    if [[ -d "${TMP_DIR}/paramspider" ]]; then
      find "${TMP_DIR}/paramspider" -type f -name '*.txt' -exec cat {} + >> "${OUTPUT_TMP}" 2>/dev/null || true
    fi
  fi

  if $ENABLE_HAKRAWLER && [[ -s "${VALIDHTTP_TMP}" ]]; then
    log_info "Running hakrawler..."
    cat "${VALIDHTTP_TMP}" | hakrawler -insecure -u > "${TMP_DIR}/hakcraw.tmp" 2>/dev/null || true
    [[ -f "${TMP_DIR}/hakcraw.tmp" ]] && cat "${TMP_DIR}/hakcraw.tmp" >> "${OUTPUT_TMP}"
  fi

  if $ENABLE_URLFINDER && [[ -s "${VALIDHTTP_TMP}" ]]; then
    log_info "Running urlfinder..."
    urlfinder -d "${VALIDHTTP_TMP}" -o "${TMP_DIR}/urlfinder.tmp" >/dev/null 2>&1 || true
    [[ -f "${TMP_DIR}/urlfinder.tmp" ]] && cat "${TMP_DIR}/urlfinder.tmp" >> "${OUTPUT_TMP}"
  fi

  if $ENABLE_NUCLEI && [[ -s "${VALIDHTTP_TMP}" ]]; then
    log_good "Running nuclei on live HTTP targets..."
    nuclei -silent -l "${VALIDHTTP_TMP}" -o "${OUT_DIR}/${DOMAIN}-nuclei.txt" || true
  fi

  if $ENABLE_DALFOX && [[ -s "${OUTPUT_TMP}" ]]; then
    log_good "Running dalfox on discovered URLs (may be noisy)..."
    sort -u "${OUTPUT_TMP}" > "${TMP_DIR}/urls-for-dalfox.tmp"
    dalfox file "${TMP_DIR}/urls-for-dalfox.tmp" -o "${OUT_DIR}/${DOMAIN}-dalfox.txt" || true
  fi

  sort -u "${OUTPUT_TMP}" | uro > "${OUTPUT_PATH}" 2>/dev/null || true

  log_good "Saved consolidated endpoints to: ${OUTPUT_PATH}"
  log_info "Run with --help to see all options."
}

main "$@"



