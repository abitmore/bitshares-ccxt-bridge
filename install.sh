#!/bin/bash

# BitShares CCXT Bridge - Easy Installer
# Version 0.2.0
# This script helps non-technical users set up the BitShares CCXT adapter

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  BitShares CCXT Bridge Setup${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Node.js version
check_node_version() {
    if command_exists node; then
        local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -ge 20 ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Function to install Node.js
install_nodejs() {
    print_status "Installing Node.js 20..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        if command_exists apt-get; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        # CentOS/RHEL/Fedora
        elif command_exists yum; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo yum install -y nodejs npm
        elif command_exists dnf; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs npm
        else
            print_error "Unsupported Linux distribution. Please install Node.js 20+ manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            brew install node@20
        else
            print_error "Homebrew not found. Please install Node.js 20+ manually from https://nodejs.org"
            exit 1
        fi
    else
        print_error "Unsupported operating system. Please install Node.js 20+ manually."
        exit 1
    fi
}

# Function to validate BitShares account name
validate_account_name() {
    local account="$1"
    if [[ ! "$account" =~ ^[a-z][a-z0-9.-]*[a-z0-9]$ ]] || [ ${#account} -lt 3 ] || [ ${#account} -gt 63 ]; then
        return 1
    fi
    return 0
}

# Function to validate private key format
validate_private_key() {
    local key="$1"
    # BitShares WIF keys start with 5 and are typically 51 characters long
    # But allow some flexibility for different key formats
    if [[ "$key" =~ ^5[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{49,52}$ ]]; then
        return 0
    fi
    return 1
}

# Main installation function
main() {
    print_header
    
    print_status "Welcome to the BitShares CCXT Bridge installer!"
    echo "This wizard will help you set up everything you need."
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "package.json" ] || [ ! -f "README.md" ]; then
        print_error "Please run this script from the bitshares-ccxt-bridge directory."
        exit 1
    fi
    
    # Check Node.js
    print_status "Checking Node.js installation..."
    if ! check_node_version; then
        print_warning "Node.js 20+ is required but not found."
        echo "Would you like to install Node.js automatically? (y/n)"
        read -r install_node
        if [[ "$install_node" =~ ^[Yy]$ ]]; then
            install_nodejs
        else
            print_error "Please install Node.js 20+ manually and run this script again."
            exit 1
        fi
    else
        print_status "Node.js $(node --version) found ✓"
    fi
    
    # Install dependencies
    print_status "Installing project dependencies..."
    npm install
    
    # Build the project
    print_status "Building the project..."
    npm run build
    
    # Configuration wizard
    print_status "Starting configuration wizard..."
    echo ""
    
    # Create .env file
    if [ -f ".env" ]; then
        print_warning "Configuration file (.env) already exists."
        echo "Would you like to reconfigure? (y/n)"
        read -r reconfigure
        if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
            print_status "Skipping configuration. Using existing .env file."
            echo ""
            print_status "Installation complete!"
            echo ""
            echo "To start the server, run: ./start.sh"
            echo "To stop the server, run: ./stop.sh"
            exit 0
        fi
    fi
    
    echo "Let's configure your BitShares connection..."
    echo ""
    
    # BitShares Node
    echo "1. BitShares Node URL"
    echo "   This is the WebSocket endpoint to connect to the BitShares network."
    echo "   Default: wss://node.xbts.io/ws"
    echo ""
    echo "Enter BitShares node URL (or press Enter for default):"
    read -r bts_node
    if [ -z "$bts_node" ]; then
        bts_node="wss://node.xbts.io/ws"
    fi
    
    # BitShares Account
    echo ""
    echo "2. BitShares Account Name"
    echo "   This is your BitShares account name (e.g., 'myaccount123')"
    echo ""
    while true; do
        echo "Enter your BitShares account name:"
        read -r bts_account
        if [ -z "$bts_account" ]; then
            print_error "Account name cannot be empty."
            continue
        fi
        if validate_account_name "$bts_account"; then
            break
        else
            print_error "Invalid account name format. Must be 3-63 characters, lowercase letters, numbers, dots, and hyphens only."
        fi
    done
    
    # Private Key
    echo ""
    echo "3. Private Key"
    echo "   This is your BitShares ACTIVE private key (starts with '5')"
    echo "   ⚠️  IMPORTANT: This will be stored in plain text in .env file"
    echo "   ⚠️  Keep this file secure and never share it!"
    echo ""
    while true; do
        echo "Enter your BitShares active private key:"
        read -s bts_wif
        echo ""
        if [ -z "$bts_wif" ]; then
            print_error "Private key cannot be empty."
            continue
        fi
        if validate_private_key "$bts_wif"; then
            break
        else
            print_error "Invalid private key format. Must be a valid WIF key starting with '5'."
        fi
    done
    
    # Port
    echo ""
    echo "4. Server Port"
    echo "   The port where the API server will run."
    echo "   Default: 8787"
    echo ""
    echo "Enter port number (or press Enter for default):"
    read -r port
    if [ -z "$port" ]; then
        port="8787"
    fi
    
    # XBTS API
    echo ""
    echo "5. Market Data API"
    echo "   The XBTS API endpoint for market data."
    echo "   Default: https://cmc.xbts.io/v2"
    echo ""
    echo "Enter XBTS API URL (or press Enter for default):"
    read -r xbts_api
    if [ -z "$xbts_api" ]; then
        xbts_api="https://cmc.xbts.io/v2"
    fi
    
    # Create .env file
    print_status "Creating configuration file..."
    cat > .env << EOF
# BitShares CCXT Bridge Configuration
# Generated by installer on $(date)

# BitShares Network Settings
BTS_NODE=$bts_node
BTS_ACCOUNT=$bts_account
BTS_WIF=$bts_wif

# API Settings
XBTS_API=$xbts_api
PORT=$port

# Environment
NODE_ENV=production
EOF
    
    # Set secure permissions on .env file
    chmod 600 .env
    
    print_status "Configuration saved to .env file ✓"
    echo ""
    
    # Test connection
    print_status "Testing configuration..."
    echo "Would you like to test the connection now? (y/n)"
    read -r test_connection
    if [[ "$test_connection" =~ ^[Yy]$ ]]; then
        print_status "Starting test server..."
        timeout 10s npm start &
        server_pid=$!
        sleep 3
        
        # Test API endpoint
        if curl -s "http://localhost:$port/markets" > /dev/null; then
            print_status "✓ Server is running and responding!"
        else
            print_warning "Server started but API test failed. Check your configuration."
        fi
        
        # Stop test server
        kill $server_pid 2>/dev/null || true
        wait $server_pid 2>/dev/null || true
    fi
    
    echo ""
    print_status "🎉 Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  • Start the server: ./start.sh"
    echo "  • Stop the server: ./stop.sh"
    echo "  • View logs: ./logs.sh"
    echo "  • Test API: curl http://localhost:$port/markets"
    echo ""
    echo "API Endpoints:"
    echo "  • GET http://localhost:$port/markets"
    echo "  • GET http://localhost:$port/ticker?symbol=BTS/USDT"
    echo ""
    echo "For programmatic usage, see README.md"
    echo ""
    print_warning "Remember to keep your .env file secure!"
}

# Run main function
main "$@"
