#!/usr/bin/env bash

###############################################################################
# webjiver Installation Script
#
# Installs all required and optional tools for webjiver.sh
# Supports: Linux, macOS, and WSL (Windows Subsystem for Linux)
###############################################################################

set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# Colors
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
NC="\e[0m"

log_info()  { echo -e "${BLUE}[i]${NC} $*"; }
log_good()  { echo -e "${GREEN}[+]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[-]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[*]${NC} $*"; }

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if Go is installed
check_go() {
  if ! command_exists go; then
    log_error "Go is not installed!"
    log_info "Install Go from: https://golang.org/dl/"
    log_info "Or use your package manager:"
    log_info "  Ubuntu/Debian: sudo apt install golang-go"
    log_info "  macOS: brew install go"
    return 1
  fi
  
  local go_version=$(go version | awk '{print $3}')
  log_good "Go is installed: ${go_version}"
  
  # Check if GOPATH/bin is in PATH
  if [[ -n "${GOPATH:-}" ]]; then
    if [[ ":$PATH:" != *":${GOPATH}/bin:"* ]]; then
      log_warn "GOPATH/bin (${GOPATH}/bin) is not in your PATH"
      log_info "Add this to your ~/.bashrc or ~/.zshrc:"
      log_info "  export PATH=\$PATH:\$GOPATH/bin"
      log_info "Or if using Go 1.17+:"
      log_info "  export PATH=\$PATH:\$(go env GOPATH)/bin"
    else
      log_good "GOPATH/bin is in PATH"
    fi
  else
    # Go 1.17+ uses default GOPATH
    local default_gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
    if [[ ":$PATH:" != *":${default_gopath}/bin:"* ]]; then
      log_warn "Go bin directory (${default_gopath}/bin) is not in your PATH"
      log_info "Add this to your ~/.bashrc or ~/.zshrc:"
      log_info "  export PATH=\$PATH:\$(go env GOPATH)/bin"
    fi
  fi
  
  return 0
}

# Check if Python3 and pip are installed
check_python() {
  if ! command_exists python3; then
    log_error "Python3 is not installed!"
    log_info "Install Python3 from: https://www.python.org/downloads/"
    log_info "Or use your package manager:"
    log_info "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    log_info "  macOS: brew install python3"
    return 1
  fi
  
  local py_version=$(python3 --version)
  log_good "Python3 is installed: ${py_version}"
  
  if ! command_exists pip3 && ! command_exists pip; then
    log_error "pip is not installed!"
    log_info "Install pip: sudo apt install python3-pip (Linux) or python3 -m ensurepip (macOS)"
    return 1
  fi
  
  local pip_cmd="pip3"
  if command_exists pip && ! command_exists pip3; then
    pip_cmd="pip"
  fi
  log_good "pip is available: ${pip_cmd}"
  
  return 0
}

# Check if git is installed
check_git() {
  if ! command_exists git; then
    log_warn "Git is not installed (some tools may need it)"
    log_info "Install git: sudo apt install git (Linux) or brew install git (macOS)"
    return 1
  fi
  log_good "Git is installed: $(git --version)"
  return 0
}

# Install Go tool
install_go_tool() {
  local tool_name="$1"
  local tool_path="$2"
  apt install -y libpcap-dev
  if command_exists "$tool_name"; then
    log_info "${tool_name} is already installed: $(command -v ${tool_name})"
    return 0
  fi
  
  log_step "Installing ${tool_name}..."
  if go install "${tool_path}@latest" 2>/dev/null; then
    log_good "${tool_name} installed successfully"
    
    # Check if it's now in PATH
    if command_exists "$tool_name"; then
      log_good "${tool_name} is available in PATH"
    else
      log_warn "${tool_name} installed but not in PATH"
      log_info "Make sure $(go env GOPATH)/bin is in your PATH"
    fi
    return 0
  else
    log_error "Failed to install ${tool_name}"
    return 1
  fi
}

# Install Python tool
install_python_tool() {
  local tool_name="$1"
  local package_name="${2:-$1}"
  
  if command_exists "$tool_name"; then
    log_info "${tool_name} is already installed: $(command -v ${tool_name})"
    return 0
  fi
  
  log_step "Installing ${tool_name}..."
  local pip_cmd="pip3"
  if command_exists pip && ! command_exists pip3; then
    pip_cmd="pip"
  fi
  
  if $pip_cmd install --user "${package_name}" 2>/dev/null; then
    log_good "${tool_name} installed successfully"
    
    # Check if it's now in PATH
    if command_exists "$tool_name"; then
      log_good "${tool_name} is available in PATH"
    else
      log_warn "${tool_name} installed but not in PATH"
      local user_bin="$HOME/.local/bin"
      if [[ ":$PATH:" != *":${user_bin}:"* ]]; then
        log_info "Add this to your ~/.bashrc or ~/.zshrc:"
        log_info "  export PATH=\$PATH:\$HOME/.local/bin"
      fi
    fi
    return 0
  else
    log_error "Failed to install ${tool_name}"
    return 1
  fi
}

# Install Python tool via pipx
install_python_tool_pipx() {
  local tool_name="$1"
  local package_name="${2:-$1}"

  if command_exists "$tool_name"; then
    log_info "${tool_name} is already installed: $(command -v ${tool_name})"
    return 0
  fi

  if ! command_exists pipx; then
    log_error "pipx is not installed; cannot install ${tool_name} via pipx"
    log_info "Install pipx: python3 -m pip install --user pipx && python3 -m pipx ensurepath"
    return 1
  fi

  log_step "Installing ${tool_name} via pipx..."
  if pipx install "${package_name}" 2>/dev/null; then
    log_good "${tool_name} installed successfully via pipx"
    pipx ensurepath
    return 0
  else
    log_error "Failed to install ${tool_name} via pipx"
    return 1
  fi
}

# Install paramspider from source (requires git)
install_paramspider() {
  local repo_url="https://github.com/devanshbatham/paramspider"

  if command_exists "paramspider"; then
    log_info "paramspider is already installed: $(command -v paramspider)"
    return 0
  fi

  if ! command_exists git; then
    log_error "Git is required to install paramspider from source."
    return 1
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'paramspider')"
  if [[ -z "${tmp_dir}" || "${tmp_dir}" == "/" ]]; then
    log_error "Failed to create temporary directory for paramspider"
    return 1
  fi

  log_step "Installing paramspider from source..."
  local pip_cmd="pip3"
  if command_exists pip && ! command_exists pip3; then
    pip_cmd="pip"
  fi

  if (
    cd "${tmp_dir}" &&
    git clone "${repo_url}" &&
    cd paramspider &&
    ${pip_cmd} install --user .
  ); then
    log_good "paramspider installed successfully"
  else
    log_error "Failed to install paramspider"
    rm -rf "${tmp_dir}" || true
    return 1
  fi

  rm -rf "${tmp_dir}" || true

  if command_exists "paramspider"; then
    log_good "paramspider is available in PATH"
  else
    log_warn "paramspider installed but not in PATH"
    local user_bin="$HOME/.local/bin"
    if [[ ":$PATH:" != *":${user_bin}:"* ]]; then
      log_info "Add this to your ~/.bashrc or ~/.zshrc:"
      log_info "  export PATH=\$PATH:\$HOME/.local/bin"
    fi
  fi

  return 0
}

# Install knockpy from source (requires git + python3)
install_knockpy() {
  local repo_url="https://github.com/guelfoweb/knockpy.git"
  local install_dir="$HOME/.local/share/knockpy"
  local user_bin="$HOME/.local/bin"

  if command_exists "knockpy"; then
    log_info "knockpy is already installed: $(command -v knockpy)"
    return 0
  fi

  if ! command_exists git; then
    log_error "Git is required to install knockpy from source."
    return 1
  fi

  if ! command_exists python3; then
    log_error "Python3 is required to install knockpy."
    return 1
  fi

  log_step "Installing knockpy from source into ${install_dir}..."

  # Clean any previous partial install
  rm -rf "${install_dir}" 2>/dev/null || true

  if (
    git clone "${repo_url}" "${install_dir}" &&
    cd "${install_dir}" &&
    python3 -m venv .venv &&
    . .venv/bin/activate &&
    python3 -m pip install -U pip &&
    pip install .
  ); then
    log_good "knockpy installed successfully"
  else
    log_error "Failed to install knockpy"
    rm -rf "${install_dir}" || true
    return 1
  fi

  # Create a wrapper script so knockpy is accessible from PATH
  mkdir -p "${user_bin}"
  cat > "${user_bin}/knockpy" <<'WRAPPER'
#!/usr/bin/env bash
KNOCKPY_DIR="$HOME/.local/share/knockpy"
exec "${KNOCKPY_DIR}/.venv/bin/knockpy" "$@"
WRAPPER
  chmod +x "${user_bin}/knockpy"

  if command_exists "knockpy"; then
    log_good "knockpy is available in PATH"
  else
    log_warn "knockpy installed but not in PATH"
    if [[ ":$PATH:" != *":${user_bin}:"* ]]; then
      log_info "Add this to your ~/.bashrc or ~/.zshrc:"
      log_info "  export PATH=\$PATH:\$HOME/.local/bin"
    fi
  fi

  return 0
}

# Main installation function
main() {
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║         webjiver Tool Installation Script v${VERSION}        ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  
  log_info "Checking prerequisites..."
  echo
  
  # Check prerequisites
  local has_go=false
  local has_python=false
  
  if check_go; then
    has_go=true
  else
    log_error "Go is required for most tools. Please install it first."
    exit 1
  fi
  
  if check_python; then
    has_python=true
  else
    log_warn "Python is required for some tools. Continuing anyway..."
  fi
  
  check_git || true
  
  echo
  log_info "Starting tool installation..."
  echo
  
  local failed_tools=()
  local installed_count=0
  
  # Required Go tools
  log_step "=== Installing Required Tools ==="
  echo
  
  if $has_go; then
    install_go_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" || failed_tools+=("subfinder")
    install_go_tool "assetfinder" "github.com/tomnomnom/assetfinder" || failed_tools+=("assetfinder")
    install_go_tool "naabu" "github.com/projectdiscovery/naabu/v2/cmd/naabu" || failed_tools+=("naabu")
    install_go_tool "httpx" "github.com/projectdiscovery/httpx/cmd/httpx" || failed_tools+=("httpx")
    installed_count=$((installed_count + 4))
  fi
  
  if $has_python; then
    install_python_tool_pipx "uro" "uro" || failed_tools+=("uro")
    installed_count=$((installed_count + 1))
  fi
  
  echo
  log_step "=== Installing Optional Tools ==="
  echo
  
  # Optional Go tools
  if $has_go; then
    install_go_tool "amass" "github.com/owasp-amass/amass/v4/..." || failed_tools+=("amass")
    install_go_tool "hakrawler" "github.com/hakluke/hakrawler" || failed_tools+=("hakrawler")
    install_go_tool "urlfinder" "github.com/projectdiscovery/urlfinder/cmd/urlfinder" || failed_tools+=("urlfinder")
    install_go_tool "nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei" || failed_tools+=("nuclei")
    install_go_tool "dalfox" "github.com/hahwul/dalfox/v2" || failed_tools+=("dalfox")
    installed_count=$((installed_count + 5))
  fi
  
  # Optional Python tools
  if $has_python; then
    install_paramspider || failed_tools+=("paramspider")
    install_knockpy || failed_tools+=("knockpy")
    installed_count=$((installed_count + 2))
  fi
  
  echo
  log_step "=== Installation Summary ==="
  echo
  
  if [[ ${#failed_tools[@]} -eq 0 ]]; then
    log_good "All tools installed successfully!"
  else
    log_warn "Some tools failed to install: ${failed_tools[*]}"
    log_info "You can try installing them manually or check the errors above."
  fi
  
  echo
  log_info "Verifying installed tools..."
  echo
  
  local required_tools=("subfinder" "assetfinder" "naabu" "httpx" "uro")
  local optional_tools=("amass" "knockpy" "paramspider" "hakrawler" "urlfinder" "nuclei" "dalfox")
  
  local missing_required=()
  local available_optional=()
  
  for tool in "${required_tools[@]}"; do
    if command_exists "$tool"; then
      log_good "✓ ${tool} - $(command -v ${tool})"
    else
      log_error "✗ ${tool} - NOT FOUND"
      missing_required+=("$tool")
    fi
  done
  
  echo
  log_info "Optional tools status:"
  for tool in "${optional_tools[@]}"; do
    if command_exists "$tool"; then
      log_good "✓ ${tool} - $(command -v ${tool})"
      available_optional+=("$tool")
    else
      log_warn "○ ${tool} - not installed (optional)"
    fi
  done
  
  echo
  if [[ ${#missing_required[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing_required[*]}"
    log_info "Please install them manually or fix the installation errors above."
    echo
    log_info "Common fixes:"
    log_info "1. Make sure Go bin directory is in PATH:"
    log_info "   export PATH=\$PATH:\$(go env GOPATH)/bin"
    log_info "2. Make sure Python user bin is in PATH:"
    log_info "   export PATH=\$PATH:\$HOME/.local/bin"
    log_info "3. Reload your shell: source ~/.bashrc (or ~/.zshrc)"
    exit 1
  else
    log_good "All required tools are installed and available!"
    echo
    log_info "Next steps:"
    log_info "1. Make sure your PATH includes:"
    log_info "   - \$(go env GOPATH)/bin (for Go tools)"
    log_info "   - \$HOME/.local/bin (for Python tools)"
    log_info "2. Reload your shell configuration:"
    log_info "   source ~/.bashrc  # or ~/.zshrc"
    log_info "3. Run webjiver.sh:"
    log_info "   bash webjiver.sh -d example.com -o results.txt"
    echo
    if [[ ${#available_optional[@]} -gt 0 ]]; then
      log_info "Optional tools available: ${available_optional[*]}"
      log_info "You can use them with flags like --amass, --nuclei, --dalfox"
    fi
  fi
}

main "$@"

