#!/bin/bash

# Firebase Emulator Integration Tests Runner
#
# This script starts Firebase emulators and runs integration tests.
#
# Usage:
#   ./scripts/run_emulator_tests.sh          # Run all emulator tests
#   ./scripts/run_emulator_tests.sh firebase # Run firebase service tests only
#   ./scripts/run_emulator_tests.sh drive    # Run drive log service tests only
#   ./scripts/run_emulator_tests.sh post     # Run post service tests only

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Firebase Emulator Integration Tests${NC}"
echo "======================================"

# Check if firebase-tools is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Error: firebase-tools is not installed${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

# Check if emulators are already running
check_emulators() {
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

# Start emulators if not running
start_emulators() {
    if check_emulators; then
        echo -e "${GREEN}Emulators are already running${NC}"
    else
        echo -e "${YELLOW}Starting Firebase Emulators...${NC}"
        firebase emulators:start --only auth,firestore &
        EMULATOR_PID=$!

        # Wait for emulators to start
        echo "Waiting for emulators to start..."
        for i in {1..30}; do
            if check_emulators; then
                echo -e "${GREEN}Emulators started successfully${NC}"
                return 0
            fi
            sleep 1
        done

        echo -e "${RED}Failed to start emulators${NC}"
        exit 1
    fi
}

# Run tests
run_tests() {
    local test_filter=$1

    echo -e "\n${YELLOW}Running Integration Tests...${NC}"
    echo "--------------------------------------"

    case $test_filter in
        firebase)
            flutter test test/integration/firebase_service_integration_test.dart --tags=emulator
            ;;
        drive)
            flutter test test/integration/drive_log_service_integration_test.dart --tags=emulator
            ;;
        post)
            flutter test test/integration/post_service_integration_test.dart --tags=emulator
            ;;
        *)
            # Run all emulator tests
            flutter test test/integration/ --tags=emulator
            ;;
    esac
}

# Main
start_emulators
run_tests $1

echo -e "\n${GREEN}Tests completed!${NC}"
