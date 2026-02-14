# webjiver

A lightweight reconnaissance and endpoint discovery tool that combines multiple subdomain enumeration, port scanning, and web crawling tools into a single automated workflow.

## Features

- **Subdomain Discovery**: Uses `subfinder` and `assetfinder` (with optional `amass` and `knockpy` support)
- **Port Scanning**: Fast port scanning with `naabu` on discovered subdomains
- **HTTP Enumeration**: Validates live HTTP/HTTPS endpoints with `httpx`
- **Technology Detection**: Identifies technologies running on discovered endpoints
- **Endpoint Discovery**: Combines results from `paramspider`, `hakrawler`, and `urlfinder`
- **Vulnerability Scanning**: Optional integration with `nuclei` and `dalfox`
- **Clean Output**: Deduplicates and normalizes URLs using `uro`

## Installation

### Quick Install

Run the installation script to install all required and optional tools:

```bash
bash install.sh
```

The script will:
- Check for prerequisites (Go, Python3, pip)
- Install all required tools
- Install optional tools for extended functionality
- Verify installations and provide PATH configuration instructions

### Manual Installation

If you prefer to install tools manually:

#### Required Tools (Go)
```bash
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
```

#### Required Tools (Python via pipx)
```bash
pipx install uro
pipx ensurepath  # ensure pipx shims are on PATH
```

#### Optional Tools (Go)
```bash
go install github.com/owasp-amass/amass/v4/...@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/projectdiscovery/urlfinder/cmd/urlfinder@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/hahwul/dalfox/v2@latest
```

#### Optional Tools (Python)
```bash
# ParamSpider is installed from source in install.sh; manual steps:
git clone https://github.com/devanshbatham/paramspider
cd paramspider
pip install .
```

#### Knockpy (Subdomain Scanner)
```bash
git clone https://github.com/guelfoweb/knock.git
cd knock
pip install .
```

### PATH Configuration

Make sure your PATH includes:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH=$PATH:$(go env GOPATH)/bin
export PATH=$PATH:$HOME/.local/bin

# Then reload
source ~/.bashrc  # or source ~/.zshrc
```

## Usage

### Basic Usage

```bash
bash webjiver.sh -d example.com -o results.txt
```

### Advanced Usage

```bash
# Full scan with all optional tools
bash webjiver.sh \
  -d example.com \
  -o endpoints.txt \
  --amass \
  --nuclei \
  --dalfox \
  --top-ports 2000

# Minimal scan (disable optional tools)
bash webjiver.sh \
  -d example.com \
  -o results.txt \
  --no-paramspider \
  --no-hakrawler \
  --no-urlfinder \
  --no-tech
```

### Options

#### Required
- `-d, --domain`: Root domain to scan (e.g., `example.com`)
- `-o, --output`: Output file name (saved under `./webjiver-output/`)

#### Discovery Options
- `--no-tech`: Disable httpx technology detection
- `--no-paramspider`: Disable ParamSpider parameter discovery
- `--no-hakrawler`: Disable Hakrawler crawling
- `--no-urlfinder`: Disable urlfinder extraction

#### Extra Tools (if installed)
- `--amass`: Use amass for additional subdomain enumeration
- `--knockpy`: Use knockpy for subdomain bruteforce and passive recon
- `--nuclei`: Run nuclei vulnerability scanner on live HTTP targets
- `--dalfox`: Run dalfox XSS scanner on discovered URLs (can be noisy)

#### Tuning
- `--top-ports N`: Use top N ports in naabu (default: `1000`)
- `--status-codes CSV`: HTTP status codes for httpx (default: `200,301,302,403,404`)

#### Help
- `-h, --help`: Show help message

## Output

All results are saved in the `./webjiver-output/` directory:

- `{output}.txt`: Main consolidated endpoints file (deduplicated and normalized)
- `{domain}-httpx-tech.txt`: Technology detection results (if `--no-tech` not used)
- `{domain}-nuclei.txt`: Nuclei scan results (if `--nuclei` used)
- `{domain}-dalfox.txt`: Dalfox XSS scan results (if `--dalfox` used)
- `knockpy-report/`: Knockpy JSON report with full subdomain scan results (if `--knockpy` used)

## Workflow

1. **Subdomain Discovery**: Finds subdomains using subfinder, assetfinder, and optionally amass and knockpy
2. **Port Scanning**: Scans top ports on discovered subdomains using naabu
3. **HTTP Validation**: Checks which endpoints are live using ProjectDiscovery httpx
4. **Technology Detection**: Identifies technologies on live endpoints (optional)
5. **Endpoint Discovery**: Crawls and discovers endpoints using paramspider, hakrawler, and ProjectDiscovery urlfinder
6. **Vulnerability Scanning**: Runs nuclei and/or dalfox on discovered targets (optional)
7. **Output**: Consolidates, deduplicates, and normalizes all discovered URLs

## Requirements

### Required Tools
- `subfinder` - Subdomain enumeration
- `assetfinder` - Additional subdomain discovery
- `naabu` - Fast port scanner
- `httpx` - HTTP probe and validation
- `uro` - URL normalization and deduplication

### Optional Tools
- `amass` - Advanced subdomain enumeration
- `knockpy` - Subdomain bruteforce and passive recon ([source](https://github.com/guelfoweb/knock))
- `paramspider` - Parameter discovery
- `hakrawler` - Web crawling
- `urlfinder` - URL extraction
- `nuclei` - Vulnerability scanner
- `dalfox` - XSS scanner

### Prerequisites
- **Go** 1.17+ (for Go-based tools)
- **Python 3** (for Python-based tools)
- **pip** (for Python package installation)
- **git** (recommended, for some tool installations)

## Troubleshooting

### Tools not found after installation

1. **Check PATH**: Ensure `$(go env GOPATH)/bin` and `$HOME/.local/bin` are in your PATH
2. **Reload shell**: Run `source ~/.bashrc` or `source ~/.zshrc`
3. **Verify installation**: Run `which toolname` to check if tool is in PATH

### Installation failures

- **Go tools**: Make sure Go is properly installed and GOPATH is set
- **Python tools**: Ensure pip3 is installed and working
- **Permission errors**: Use `--user` flag for pip installations or run with appropriate permissions

### No subdomains found

- Check if the domain is valid and accessible
- Try using `--amass` flag for more comprehensive enumeration
- Verify API keys are configured for subfinder (if required)

### No live HTTP targets

- The domain may not have any web services running
- Try increasing `--top-ports` value
- Check if firewalls are blocking port scans

## Original Source

This is an improved version of the original `webjiver.sh` from:
- Repository: https://github.com/vivashu27/webjiver
- Original script: https://raw.githubusercontent.com/vivashu27/webjiver/main/webjiver.sh

## Improvements Over Original

- ✅ Non-interactive CLI with flags instead of prompts
- ✅ Better error handling and tool validation
- ✅ Safer temporary file handling with automatic cleanup
- ✅ Organized output directory structure
- ✅ Optional tool integrations (amass, nuclei, dalfox)
- ✅ Technology detection with httpx
- ✅ Configurable port scanning and status code filtering
- ✅ Comprehensive installation script
- ✅ Better logging and progress indicators

## License

This project is based on the original webjiver.sh. Please refer to the original repository for licensing information.

## Disclaimer

This tool is for authorized security testing and educational purposes only. Only use it on systems you own or have explicit permission to test. Unauthorized access to computer systems is illegal.

