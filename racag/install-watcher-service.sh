#!/bin/bash
#
# RACAG Watcher - System Service Manager
# ======================================
# Installs RACAG watcher as a macOS launchd service
# that auto-starts on boot and restarts on crash
#
# Usage:
#   ./install-watcher-service.sh install    # Install and start service
#   ./install-watcher-service.sh uninstall  # Stop and remove service
#   ./install-watcher-service.sh status     # Check service status
#   ./install-watcher-service.sh logs       # Show recent logs
#   ./install-watcher-service.sh restart    # Restart service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PLIST_FILE="$SCRIPT_DIR/com.kairos.racag.watcher.plist"
INSTALL_PATH="$HOME/Library/LaunchAgents/com.kairos.racag.watcher.plist"
SERVICE_NAME="com.kairos.racag.watcher"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  RACAG Watcher Service Manager${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check if plist file exists
    if [ ! -f "$PLIST_FILE" ]; then
        echo -e "${RED}❌ Error: $PLIST_FILE not found!${NC}"
        exit 1
    fi
    
    # Check if virtual environment exists
    if [ ! -d "$REPO_ROOT/racag_env" ]; then
        echo -e "${RED}❌ Error: racag_env not found at $REPO_ROOT${NC}"
        exit 1
    fi
    
    # Check if API key file exists
    if [ ! -f "$REPO_ROOT/.copilot/.secrets" ]; then
        echo -e "${RED}❌ Error: .copilot/.secrets not found!${NC}"
        exit 1
    fi
    
    # Create logs directory
    mkdir -p "$SCRIPT_DIR/logs"
    
    echo -e "${GREEN}✅ Prerequisites OK${NC}"
}

install_service() {
    print_header
    check_prerequisites
    
    echo "📦 Installing RACAG watcher service..."
    
    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$HOME/Library/LaunchAgents"
    
    # Copy plist to LaunchAgents
    cp "$PLIST_FILE" "$INSTALL_PATH"
    echo "   → Copied plist to $INSTALL_PATH"
    
    # Load service
    launchctl load "$INSTALL_PATH"
    echo -e "${GREEN}✅ Service loaded${NC}"
    
    # Start service
    launchctl start "$SERVICE_NAME"
    echo -e "${GREEN}✅ Service started${NC}"
    
    echo ""
    echo -e "${GREEN}🎉 RACAG watcher service installed successfully!${NC}"
    echo ""
    echo "Service will:"
    echo "  • Auto-start on system boot"
    echo "  • Auto-restart if it crashes"
    echo "  • Monitor changes in /docs, /ios, /android, /.github, /infra"
    echo "  • Reindex automatically after 5 seconds of inactivity"
    echo ""
    echo "Useful commands:"
    echo "  Status:   ./install-watcher-service.sh status"
    echo "  Logs:     ./install-watcher-service.sh logs"
    echo "  Restart:  ./install-watcher-service.sh restart"
    echo "  Stop:     ./install-watcher-service.sh uninstall"
    echo ""
}

uninstall_service() {
    print_header
    echo "🗑️  Uninstalling RACAG watcher service..."
    
    if [ ! -f "$INSTALL_PATH" ]; then
        echo -e "${YELLOW}⚠️  Service not installed${NC}"
        exit 0
    fi
    
    # Stop service
    launchctl stop "$SERVICE_NAME" 2>/dev/null || true
    echo "   → Service stopped"
    
    # Unload service
    launchctl unload "$INSTALL_PATH" 2>/dev/null || true
    echo "   → Service unloaded"
    
    # Remove plist
    rm -f "$INSTALL_PATH"
    echo "   → Plist removed"
    
    echo -e "${GREEN}✅ Service uninstalled${NC}"
    echo ""
}

service_status() {
    print_header
    echo "📊 RACAG Watcher Service Status"
    echo ""
    
    if [ ! -f "$INSTALL_PATH" ]; then
        echo -e "${YELLOW}⚠️  Service not installed${NC}"
        echo ""
        echo "Install with: ./install-watcher-service.sh install"
        exit 0
    fi
    
    # Check if service is running
    if launchctl list | grep -q "$SERVICE_NAME"; then
        echo -e "${GREEN}✅ Service is RUNNING${NC}"
        echo ""
        
        # Show service info
        launchctl list | grep "$SERVICE_NAME"
        echo ""
        
        # Check log file timestamps
        if [ -f "$SCRIPT_DIR/logs/watcher.out.log" ]; then
            echo "📝 Recent activity:"
            echo "   Last output: $(stat -f "%Sm" "$SCRIPT_DIR/logs/watcher.out.log")"
            echo ""
            echo "   Last 5 lines:"
            tail -5 "$SCRIPT_DIR/logs/watcher.out.log" | sed 's/^/   /'
        fi
    else
        echo -e "${RED}❌ Service is NOT running${NC}"
        echo ""
        echo "Start with: launchctl start $SERVICE_NAME"
        echo "Or reinstall with: ./install-watcher-service.sh install"
    fi
    echo ""
}

show_logs() {
    print_header
    echo "📋 RACAG Watcher Logs"
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/logs/watcher.out.log" ]; then
        echo -e "${YELLOW}⚠️  No logs found${NC}"
        exit 0
    fi
    
    echo "=== STDOUT (last 30 lines) ==="
    tail -30 "$SCRIPT_DIR/logs/watcher.out.log"
    echo ""
    
    if [ -f "$SCRIPT_DIR/logs/watcher.err.log" ] && [ -s "$SCRIPT_DIR/logs/watcher.err.log" ]; then
        echo "=== STDERR (last 30 lines) ==="
        tail -30 "$SCRIPT_DIR/logs/watcher.err.log"
        echo ""
    fi
    
    echo "Full logs:"
    echo "  STDOUT: $SCRIPT_DIR/logs/watcher.out.log"
    echo "  STDERR: $SCRIPT_DIR/logs/watcher.err.log"
    echo ""
    echo "Watch live: tail -f $SCRIPT_DIR/logs/watcher.out.log"
    echo ""
}

restart_service() {
    print_header
    echo "🔄 Restarting RACAG watcher service..."
    
    if [ ! -f "$INSTALL_PATH" ]; then
        echo -e "${RED}❌ Service not installed${NC}"
        exit 1
    fi
    
    launchctl stop "$SERVICE_NAME"
    sleep 2
    launchctl start "$SERVICE_NAME"
    
    echo -e "${GREEN}✅ Service restarted${NC}"
    echo ""
    sleep 2
    service_status
}

# Main
case "${1:-}" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    status)
        service_status
        ;;
    logs)
        show_logs
        ;;
    restart)
        restart_service
        ;;
    *)
        print_header
        echo "Usage: $0 {install|uninstall|status|logs|restart}"
        echo ""
        echo "Commands:"
        echo "  install    - Install and start RACAG watcher service"
        echo "  uninstall  - Stop and remove RACAG watcher service"
        echo "  status     - Check if service is running"
        echo "  logs       - Show recent logs"
        echo "  restart    - Restart the service"
        echo ""
        exit 1
        ;;
esac
