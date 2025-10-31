# AKS Azure Policy with VAP (Validating Admission Policy) Demo

This repository demonstrates how to enable and use Validating Admission Policy (VAP) support in Azure Kubernetes Service (AKS) with Azure Policy add-on. It showcases policy enforcement using Gatekeeper constraint templates to prevent privileged containers from running in your cluster.

## 📋 Overview

This demo includes:

- ✅ Enabling the VAP feature flag in AKS with Azure Policy add-on
- ✅ Creating a custom policy using the Gatekeeper constraint template from the [OPA Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
- ✅ Applying the policy to an AKS cluster with "deny" enforcement action
- ✅ Showing policy, ConstraintTemplate, Constraints, and VAP resources via CLI
- ✅ Interactive bash script with configurable Azure variables and demo-magic support

## 🏗️ Architecture

The solution uses:

- **Azure Policy Add-on**: Extends Gatekeeper to work with Azure Policy
- **Gatekeeper**: Open-source policy controller for Kubernetes
- **Constraint Template**: Defines the policy logic (privileged container check)
- **Constraint**: Instance of the template with specific enforcement rules
- **VAP**: Kubernetes native validating admission policies (K8s 1.26+)

## 📁 Repository Structure

```
.
├── manifests/
│   ├── constraint-template.yaml       # ConstraintTemplate for privileged containers
│   ├── constraint.yaml                # Constraint with deny enforcement
│   ├── test-privileged-pod.yaml       # Test pod (should be denied)
│   └── test-unprivileged-pod.yaml     # Test pod (should be allowed)
├── scripts/
│   ├── demo.sh                        # Main demo script
│   └── demo-magic.sh                  # Demo presentation helper
└── README.md                          # This file
```

## 🚀 Quick Start

### Prerequisites

Before running the demo, ensure you have:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- An active Azure subscription with permissions to create resources
- Sufficient Azure quota for AKS cluster creation

### Running the Demo

1. **Clone the repository:**

```bash
git clone https://github.com/JaydipGabani/policy-vap-demo.git
cd policy-vap-demo
```

2. **Run the demo script:**

```bash
# Run with default settings (interactive mode)
./scripts/demo.sh

# Run without pauses (automated mode)
./scripts/demo.sh --no-wait

# Run with custom configuration
./scripts/demo.sh --resource-group my-rg --location westus2 --cluster-name my-cluster
```

3. **Or configure via environment variables:**

```bash
export RESOURCE_GROUP="my-vap-demo-rg"
export CLUSTER_NAME="my-vap-cluster"
export LOCATION="westus2"
export NODE_COUNT="3"

./scripts/demo.sh
```

## 🛠️ Manual Setup

If you prefer to run the steps manually:

### Step 1: Register VAP Feature and Create AKS Cluster

```bash
# Register the ValidatingAdmissionPolicy feature for Azure Policy
az feature register --namespace Microsoft.ContainerService --name AKS-AzurePolicyValidatingAdmissionPolicy

# Check registration status (may take a few minutes)
az feature show --namespace Microsoft.ContainerService --name AKS-AzurePolicyValidatingAdmissionPolicy

# Create resource group
az group create --name vap-demo-rg --location eastus

# Create AKS cluster with Azure Policy add-on
az aks create \
    --resource-group vap-demo-rg \
    --name vap-demo-aks \
    --node-count 2 \
    --enable-addons azure-policy \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --network-plugin azure \
    --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group vap-demo-rg --name vap-demo-aks
```

### Step 2: Verify Azure Policy Add-on

```bash
# Check Gatekeeper pods
kubectl get pods -n gatekeeper-system

# Verify webhook configuration
kubectl get validatingwebhookconfigurations | grep gatekeeper
```

### Step 3: Apply Constraint Template

```bash
# Apply the constraint template
kubectl apply -f manifests/constraint-template.yaml

# Verify template
kubectl get constrainttemplates
kubectl describe constrainttemplate k8spspprivilegedcontainer
```

### Step 4: Apply Constraint

```bash
# Apply constraint with deny enforcement
kubectl apply -f manifests/constraint.yaml

# Verify constraint
kubectl get k8spspprivilegedcontainer
kubectl describe k8spspprivilegedcontainer psp-privileged-container
```

### Step 5: Test Policy Enforcement

```bash
# This should be DENIED
kubectl apply -f manifests/test-privileged-pod.yaml

# This should be ALLOWED
kubectl apply -f manifests/test-unprivileged-pod.yaml

# Cleanup test pod
kubectl delete pod unprivileged-pod
```

### Step 6: View Policy Resources

```bash
# View all constraint templates
kubectl get constrainttemplates

# View all constraints
kubectl get constraints

# View Gatekeeper audit results
kubectl get k8spspprivilegedcontainer psp-privileged-container -o yaml

# View VAP resources (K8s 1.26+)
kubectl get validatingadmissionpolicies
kubectl get validatingadmissionpolicybindings
```

## 📚 Demo Script Options

The demo script supports various options:

```bash
Options:
    -h, --help              Show help message
    -n, --no-wait          Skip wait prompts between steps
    --resource-group NAME   Resource group name (default: vap-demo-rg)
    --cluster-name NAME     AKS cluster name (default: vap-demo-aks)
    --location LOCATION     Azure location (default: eastus)
    --node-count COUNT      Number of nodes (default: 2)
```

## 🔍 Understanding the Policy

The privileged container policy prevents pods from running with `securityContext.privileged: true`. This is important because privileged containers have access to all host devices and can bypass security mechanisms.

### Constraint Template

The constraint template (`manifests/constraint-template.yaml`) defines:
- Policy logic using both K8sNativeValidation (CEL) and Rego engines
- Support for exempt images (allow specific containers)
- Validation rules that check container security contexts

### Constraint

The constraint (`manifests/constraint.yaml`) specifies:
- Enforcement action: `deny` (blocks non-compliant resources)
- Match criteria: Applies to Pods in the default namespace
- No exemptions: All containers must comply

## 🧪 Testing

### Test Cases Included

1. **Privileged Pod (Denied)**: `manifests/test-privileged-pod.yaml`
   - Has `securityContext.privileged: true`
   - Should be rejected by the policy

2. **Unprivileged Pod (Allowed)**: `manifests/test-unprivileged-pod.yaml`
   - Has `securityContext.privileged: false`
   - Should be allowed by the policy

### Expected Behavior

When you try to create the privileged pod:
```
Error from server (Forbidden): error when creating "manifests/test-privileged-pod.yaml": 
admission webhook "validation.gatekeeper.sh" denied the request: 
[psp-privileged-container] Privileged container is not allowed: nginx, 
securityContext.privileged: true
```

## 🔧 Customization

### Modifying the Constraint

To change enforcement or scope, edit `manifests/constraint.yaml`:

```yaml
spec:
  enforcementAction: deny  # Options: deny, dryrun, warn
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - default      # Change or add more namespaces
```

### Adding Exempt Images

To allow specific images to be privileged:

```yaml
spec:
  parameters:
    exemptImages:
      - "my-trusted-image:*"
      - "docker.io/privileged-tool:latest"
```

## 🧹 Cleanup

To remove all resources created by the demo:

```bash
# Delete the resource group (this removes everything)
az group delete --name vap-demo-rg --yes --no-wait
```

Or use the cleanup option in the demo script when prompted.

## 📖 Additional Resources

- [Azure Policy for AKS](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/)
- [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
- [Kubernetes Validating Admission Policies](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is provided as-is for demonstration purposes.

## 👤 Author

Jaydip Gabani

## ⚠️ Disclaimer

This demo creates Azure resources that may incur costs. Please ensure you clean up resources after testing to avoid unexpected charges.