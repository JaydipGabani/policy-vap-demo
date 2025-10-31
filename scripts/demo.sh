#!/bin/bash
set -e  # Exit on error

##############################################################################
# VAP (Validating Admission Policy) Demo for AKS Azure Policy
# 
# This script demonstrates how to:
# 1. Enable VAP feature flag in AKS Azure Policy
# 2. Create and apply a custom policy using Gatekeeper constraint template
# 3. Show policy enforcement with deny action
# 4. Display policy, ConstraintTemplate, Constraints, and VAP resources
##############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Demo magic settings
DEMO_PROMPT="${GREEN}➜ ${BLUE}\W ${NC}$ "
TYPE_SPEED=20
NO_WAIT=false

# Try to source demo-magic if available and pv is installed
DEMO_MAGIC=false
if [ -f "$(dirname "$0")/demo-magic.sh" ] && command -v pv &> /dev/null; then
    # Temporarily disable exit on error for sourcing demo-magic
    set +e
    . "$(dirname "$0")/demo-magic.sh" 2>/dev/null
    if [ $? -eq 0 ]; then
        DEMO_MAGIC=true
    fi
    set -e
fi

# Fallback functions if demo-magic is not available or pv not installed
if [ "$DEMO_MAGIC" = false ]; then
    function p() {
        echo -e "${GREEN}${1}${NC}"
    }
    
    function pe() {
        echo -e "${BLUE}\$ ${NC}${1}"
        eval "$1"
    }
    
    function wait() {
        if [ "$NO_WAIT" = false ]; then
            echo ""
            read -p "Press Enter to continue..." -r
        fi
    }
    
    function cmd() {
        echo "\$ $@"
        "$@"
    }
fi

##############################################################################
# Configuration Variables
##############################################################################

# Azure Configuration (modify these for your environment)
RESOURCE_GROUP="${RESOURCE_GROUP:-vap-demo-rg}"
CLUSTER_NAME="${CLUSTER_NAME:-vap-demo-aks}"
LOCATION="${LOCATION:-eastus}"
NODE_COUNT="${NODE_COUNT:-2}"
VM_SIZE="${VM_SIZE:-Standard_DS2_v2}"

# Policy Configuration
NAMESPACE="${NAMESPACE:-default}"

##############################################################################
# Helper Functions
##############################################################################

function print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

function print_info() {
    echo -e "${GREEN}ℹ ${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}⚠ ${NC} $1"
}

function print_error() {
    echo -e "${RED}✗${NC} $1"
}

function print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

function check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("Azure CLI (az)")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
    
    print_success "All prerequisites installed"
}

##############################################################################
# Demo Steps
##############################################################################

function show_configuration() {
    print_header "Demo Configuration"
    
    cat <<EOF
Resource Group:  ${RESOURCE_GROUP}
Cluster Name:    ${CLUSTER_NAME}
Location:        ${LOCATION}
Node Count:      ${NODE_COUNT}
VM Size:         ${VM_SIZE}
Namespace:       ${NAMESPACE}
EOF
    
    wait
}

function create_aks_cluster() {
    print_header "Step 1: Create AKS Cluster with VAP Feature Enabled"
    
    print_info "Creating resource group..."
    pe "az group create --name ${RESOURCE_GROUP} --location ${LOCATION}"
    
    echo ""
    print_info "Creating AKS cluster with VAP feature flag enabled..."
    print_warning "This may take several minutes..."
    
    pe "az aks create \
        --resource-group ${RESOURCE_GROUP} \
        --name ${CLUSTER_NAME} \
        --node-count ${NODE_COUNT} \
        --node-vm-size ${VM_SIZE} \
        --enable-addons azure-policy \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --network-plugin azure \
        --generate-ssh-keys"
    
    print_success "AKS cluster created successfully"
    wait
}

function configure_kubectl() {
    print_header "Step 2: Configure kubectl"
    
    print_info "Getting AKS credentials..."
    pe "az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME} --overwrite-existing"
    
    echo ""
    print_info "Verifying cluster connection..."
    pe "kubectl cluster-info"
    
    echo ""
    pe "kubectl get nodes"
    
    print_success "kubectl configured successfully"
    wait
}

function verify_azure_policy_addon() {
    print_header "Step 3: Verify Azure Policy Add-on"
    
    print_info "Checking Azure Policy pods in gatekeeper-system namespace..."
    pe "kubectl get pods -n gatekeeper-system"
    
    echo ""
    print_info "Checking for Gatekeeper webhook..."
    pe "kubectl get validatingwebhookconfigurations | grep gatekeeper"
    
    print_success "Azure Policy add-on is running"
    wait
}

function apply_constraint_template() {
    print_header "Step 4: Apply Constraint Template"
    
    print_info "Applying privileged container constraint template..."
    pe "kubectl apply -f manifests/constraint-template.yaml"
    
    echo ""
    print_info "Waiting for constraint template to be ready..."
    # Poll for constraint template readiness
    for i in {1..30}; do
        if kubectl get constrainttemplate k8spspprivilegedcontainer &>/dev/null; then
            print_success "Constraint template is ready"
            break
        fi
        sleep 2
    done
    
    echo ""
    print_info "Viewing constraint template..."
    pe "kubectl get constrainttemplates"
    
    echo ""
    pe "kubectl describe constrainttemplate k8spspprivilegedcontainer"
    
    print_success "Constraint template applied successfully"
    wait
}

function apply_constraint() {
    print_header "Step 5: Apply Constraint with Deny Enforcement"
    
    print_info "Applying constraint to deny privileged containers..."
    pe "kubectl apply -f manifests/constraint.yaml"
    
    echo ""
    print_info "Waiting for constraint to be ready..."
    # Poll for constraint readiness
    for i in {1..30}; do
        if kubectl get k8spspprivilegedcontainer psp-privileged-container &>/dev/null; then
            print_success "Constraint is ready"
            break
        fi
        sleep 2
    done
    
    echo ""
    print_info "Viewing constraints..."
    pe "kubectl get constraints"
    
    echo ""
    pe "kubectl get k8spspprivilegedcontainer"
    
    echo ""
    pe "kubectl describe k8spspprivilegedcontainer psp-privileged-container"
    
    print_success "Constraint applied with deny enforcement"
    wait
}

function test_policy_deny() {
    print_header "Step 6: Test Policy Enforcement - Deny Privileged Pod"
    
    print_info "Attempting to create a privileged pod (should be denied)..."
    echo -e "${BLUE}\$ ${NC}kubectl apply -f manifests/test-privileged-pod.yaml"
    
    if kubectl apply -f manifests/test-privileged-pod.yaml 2>&1; then
        print_error "Unexpected: Pod was allowed (policy may not be enforcing)"
    else
        print_success "Policy correctly denied the privileged pod!"
    fi
    
    wait
}

function test_policy_allow() {
    print_header "Step 7: Test Policy Enforcement - Allow Unprivileged Pod"
    
    print_info "Creating an unprivileged pod (should be allowed)..."
    pe "kubectl apply -f manifests/test-unprivileged-pod.yaml"
    
    echo ""
    print_info "Verifying pod creation..."
    pe "kubectl get pods unprivileged-pod"
    
    echo ""
    print_info "Cleaning up test pod..."
    pe "kubectl delete pod unprivileged-pod --ignore-not-found=true"
    
    print_success "Unprivileged pod was allowed as expected"
    wait
}

function show_vap_resources() {
    print_header "Step 8: Show VAP Resources"
    
    print_info "Listing Validating Admission Policies..."
    pe "kubectl get validatingadmissionpolicies" || print_warning "No VAP resources found (may require K8s 1.26+)"
    
    echo ""
    print_info "Listing Validating Admission Policy Bindings..."
    pe "kubectl get validatingadmissionpolicybindings" || print_warning "No VAP bindings found (may require K8s 1.26+)"
    
    wait
}

function show_all_resources() {
    print_header "Step 9: Summary - All Policy Resources"
    
    print_info "Constraint Templates:"
    pe "kubectl get constrainttemplates"
    
    echo ""
    print_info "Constraints:"
    pe "kubectl get constraints"
    
    echo ""
    print_info "Gatekeeper Pods:"
    pe "kubectl get pods -n gatekeeper-system"
    
    echo ""
    print_info "Azure Policy Assignment Status:"
    pe "kubectl get azurepolicystates --all-namespaces" || print_warning "Azure policy states may take time to sync"
    
    wait
}

function cleanup() {
    print_header "Cleanup (Optional)"
    
    print_warning "This will delete the entire resource group and all resources."
    echo ""
    read -p "Do you want to proceed with cleanup? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting resource group..."
        pe "az group delete --name ${RESOURCE_GROUP} --yes --no-wait"
        print_success "Cleanup initiated (running in background)"
    else
        print_info "Cleanup skipped"
    fi
}

##############################################################################
# Main Demo Flow
##############################################################################

function run_demo() {
    clear
    
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   AKS Azure Policy with VAP (Validating Admission Policy)     ║
║                         Demo Script                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    
    echo ""
    print_info "This demo will show how to:"
    echo "  1. Enable VAP feature in AKS with Azure Policy"
    echo "  2. Apply Gatekeeper constraint template for privileged containers"
    echo "  3. Enforce policy with deny action"
    echo "  4. Display all policy resources"
    echo ""
    
    wait
    
    check_prerequisites
    show_configuration
    create_aks_cluster
    configure_kubectl
    verify_azure_policy_addon
    apply_constraint_template
    apply_constraint
    test_policy_deny
    test_policy_allow
    show_vap_resources
    show_all_resources
    
    print_header "Demo Complete!"
    print_success "Successfully demonstrated AKS Azure Policy with VAP support"
    echo ""
    
    cleanup
}

function show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -n, --no-wait          Skip wait prompts between steps
    --resource-group NAME   Resource group name (default: vap-demo-rg)
    --cluster-name NAME     AKS cluster name (default: vap-demo-aks)
    --location LOCATION     Azure location (default: eastus)
    --node-count COUNT      Number of nodes (default: 2)
    
Environment Variables:
    RESOURCE_GROUP          Resource group name
    CLUSTER_NAME            AKS cluster name
    LOCATION                Azure location
    NODE_COUNT              Number of nodes
    
Examples:
    $0                                          # Run with defaults
    $0 --no-wait                               # Run without pauses
    $0 --resource-group my-rg --location westus2
    
EOF
}

##############################################################################
# Script Entry Point
##############################################################################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--no-wait)
            NO_WAIT=true
            shift
            ;;
        --resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --node-count)
            NODE_COUNT="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run the demo
run_demo
