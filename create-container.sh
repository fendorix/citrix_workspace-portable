.#!/bin/bash

# Script to create/recreate Citrix Workspace distrobox container
# This script handles the complete setup process including building and container creation

set -e

# Configuration
CONTAINER_NAME="citrix_workspace"
IMAGE_NAME="quay.io/rafael_palomar/citrix_workspace-portable:latest"
LOCAL_IMAGE="citrix_workspace-portable"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if distrobox is installed
check_distrobox() {
    if ! command -v distrobox &> /dev/null; then
        print_error "distrobox is not installed. Please install it first."
        exit 1
    fi
}

# Check if podman or docker is installed
check_container_runtime() {
    if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
        print_error "Neither podman nor docker is installed. Please install one of them first."
        exit 1
    fi
}

# Remove existing container if it exists
remove_existing_container() {
    if distrobox list | grep -q "^${CONTAINER_NAME}"; then
        print_warning "Removing existing container: ${CONTAINER_NAME}"
        distrobox rm -f "${CONTAINER_NAME}"
        print_info "Container removed successfully"
    else
        print_info "No existing container found"
    fi
}

# Build the container image
build_image() {
    local use_local=$1
    local force_download=$2
    
    if [ "$use_local" = true ]; then
        print_info "Building local container image..."
        
        local build_args=""
        if [ "$force_download" = true ]; then
            print_warning "Forcing redownload of workspace app (cache busted)"
            build_args="--build-arg FORCE_DOWNLOAD=$(date +%s)"
        fi
        
        if command -v podman &> /dev/null; then
            podman build $build_args -t "${LOCAL_IMAGE}:latest" .
        else
            docker build $build_args -t "${LOCAL_IMAGE}:latest" .
        fi
        print_info "Image built successfully"
    else
        print_info "Skipping image build (using remote image: ${IMAGE_NAME})"
    fi
}

# Create the distrobox container
create_container() {
    local use_local=$1
    local image_to_use
    
    if [ "$use_local" = true ]; then
        image_to_use="${LOCAL_IMAGE}:latest"
    else
        image_to_use="${IMAGE_NAME}"
    fi
    
    print_info "Creating distrobox container: ${CONTAINER_NAME}"
    print_info "Using image: ${image_to_use}"
    
    distrobox create -i "${image_to_use}" -n "${CONTAINER_NAME}"
    
    print_info "Container created successfully"
}

# Export the application
export_application() {
    print_info "Exporting wfica application..."
    print_warning "You will need to manually export the application by running:"
    echo "  distrobox enter ${CONTAINER_NAME}"
    echo "  distrobox-export --app wfica"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create or recreate Citrix Workspace distrobox container.

OPTIONS:
    -h, --help          Show this help message
    -l, --local         Build image locally instead of using remote image
    -r, --rebuild       Force rebuild of the container (removes existing)
    -e, --export        Enter container and export application automatically
    -f, --force-download Force redownload of Citrix workspace app (busts cache)
    --no-build          Skip image building (only recreate container)

EXAMPLES:
    # Create container using remote image
    $0

    # Rebuild container with local image
    $0 --local --rebuild

    # Rebuild with forced workspace app redownload
    $0 --local --rebuild --force-download

    # Recreate container without rebuilding image
    $0 --rebuild --no-build

EOF
}

# Main function
main() {
    local use_local=false
    local rebuild=false
    local auto_export=false
    local no_build=false
    local force_download=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--local)
                use_local=true
                shift
                ;;
            -r|--rebuild)
                rebuild=true
                shift
                ;;
            -e|--export)
                auto_export=true
                shift
                ;;
            -f|--force-download)
                force_download=true
                shift
                ;;
            --no-build)
                no_build=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    print_info "Starting Citrix Workspace container setup..."
    
    # Perform checks
    check_distrobox
    check_container_runtime
    
    # Remove existing container if rebuild is requested
    if [ "$rebuild" = true ]; then
        remove_existing_container
    fi
    
    # Build image if needed
    if [ "$no_build" = false ] && [ "$use_local" = true ]; then
        build_image "$use_local" "$force_download"
    fi
    
    # Create container
    create_container "$use_local"
    
    # Export application
    if [ "$auto_export" = true ]; then
        print_info "Entering container to export application..."
        distrobox enter "${CONTAINER_NAME}" -- distrobox-export --app wfica
    else
        export_application
    fi
    
    print_info "Setup complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Enter the container: distrobox enter ${CONTAINER_NAME}"
    echo "  2. Export the application: distrobox-export --app wfica"
    echo "  3. Open any .ica file to launch Citrix Workspace"
}

# Run main function
main "$@"
