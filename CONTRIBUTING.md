# Contributing to VAP Demo

Thank you for your interest in contributing to this demo repository!

## Demo Script Features

The demo script (`scripts/demo.sh`) includes:

### Interactive Mode (Default)
- Pauses between steps for explanation
- Uses demo-magic for simulated typing (if `pv` is installed)
- Great for live presentations

### Automated Mode
- Use `--no-wait` flag to skip pauses
- Useful for CI/CD or automated testing

### Configuration Options

Configure via command-line arguments:
```bash
./scripts/demo.sh --resource-group my-rg --location westus2
```

Or via environment variables:
```bash
export RESOURCE_GROUP="my-rg"
export LOCATION="westus2"
./scripts/demo.sh
```

## Demo Flow

1. **Prerequisites Check**: Verifies Azure CLI and kubectl are installed
2. **Configuration Display**: Shows all configuration values
3. **Cluster Creation**: Creates AKS with Azure Policy add-on
4. **kubectl Configuration**: Gets cluster credentials
5. **Policy Add-on Verification**: Checks Gatekeeper pods
6. **Constraint Template**: Applies privileged container template
7. **Constraint Application**: Applies constraint with deny enforcement
8. **Policy Testing (Deny)**: Attempts to create privileged pod (fails)
9. **Policy Testing (Allow)**: Creates unprivileged pod (succeeds)
10. **VAP Resources**: Shows validating admission policies
11. **Summary**: Displays all policy resources
12. **Cleanup**: Optional resource deletion

## Customizing Policies

### Change Enforcement Action

Edit `manifests/constraint.yaml`:
```yaml
spec:
  enforcementAction: dryrun  # Options: deny, dryrun, warn
```

### Apply to Different Namespaces

Edit `manifests/constraint.yaml`:
```yaml
spec:
  match:
    namespaces:
      - default
      - production
      - staging
```

### Add Exempt Images

Edit `manifests/constraint.yaml`:
```yaml
spec:
  parameters:
    exemptImages:
      - "trusted-registry.io/*"
      - "system-pod:v1.0"
```

## Testing Different Scenarios

### Test 1: Privileged Container (Should Fail)
```bash
kubectl apply -f manifests/test-privileged-pod.yaml
# Expected: Error - privileged container not allowed
```

### Test 2: Unprivileged Container (Should Succeed)
```bash
kubectl apply -f manifests/test-unprivileged-pod.yaml
# Expected: Pod created successfully
```

### Test 3: Check Audit Results
```bash
kubectl get k8spspprivilegedcontainer psp-privileged-container -o yaml
```

## Adding New Policies

To add more constraint templates:

1. Download template from [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)
2. Save to `manifests/` directory
3. Create corresponding constraint YAML
4. Add test cases
5. Update demo script if needed

## Troubleshooting

### Azure Policy Pods Not Running
```bash
kubectl get pods -n gatekeeper-system
kubectl logs -n gatekeeper-system <pod-name>
```

### Constraint Not Enforcing
```bash
# Check constraint status
kubectl get k8spspprivilegedcontainer psp-privileged-container -o yaml

# Check webhook
kubectl get validatingwebhookconfigurations
```

### Demo Script Issues
```bash
# Check prerequisites
which az
which kubectl

# Verify Azure login
az account show

# Test cluster access
kubectl cluster-info
```

## Best Practices

1. **Always test in non-production first**
2. **Use `dryrun` enforcement initially** to validate behavior
3. **Monitor constraint audit results** before switching to `deny`
4. **Document exemptions** with clear business justification
5. **Version control all policy files**

## Resources

- [Azure Policy Documentation](https://docs.microsoft.com/en-us/azure/governance/policy/)
- [Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Constraint Template Library](https://github.com/open-policy-agent/gatekeeper-library)
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)

## License

This demo is provided as-is for educational purposes.
