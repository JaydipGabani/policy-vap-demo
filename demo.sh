#!/usr/bin/env bash

#################################
# include the -=magic=-
# you can pass command line args
#
# example:
# to disable simulated typing
# . ../demo-magic.sh -d
#
# pass -h to see all options
# #################################
. demo-magic.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
# TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"

# text color
# DEMO_CMD_COLOR=$BLACK

# hide the evidence
clear

SUBSCRIPTION_ID=$1
RESOURCE_GROUP=$2
AKS_CLUSTER_NAME=$3

# Step 1: Register the Azure Policy K8sNativeValidation feature
echo 'Registering AKS-AzurePolicyK8sNativeValidation feature...' | grep "Registering AKS-AzurePolicyK8sNativeValidation feature..."
pei "az feature register --name AKS-AzurePolicyK8sNativeValidation --namespace Microsoft.ContainerService | grep -A 4 name"

# Step 2: Register the Container Service provider
echo 'Registering Microsoft.ContainerService provider...' | grep "Registering Microsoft.ContainerService provider..."
pei "az provider register -n Microsoft.ContainerService"

# Step 3: View the Gatekeeper template with CEL validation engine
pei "curl -fsSL https://raw.githubusercontent.com/open-policy-agent/gatekeeper-library/master/library/pod-security-policy/privileged-containers/template.yaml | grep -A 40 "targets:""

# Step 4: View the Azure Policy definition JSON
pei "cat k8sNoPrivilegeContainerVAP.json"

# Step 5: Extract parameters and rules from the policy definition
pei "cat k8sNoPrivilegeContainerVAP.json | jq '.parameters' > params.json"
pei "cat k8sNoPrivilegeContainerVAP.json | jq '.policyRule' > rules.json"

# Step 6: Create the custom Azure Policy definition
echo 'Creating the custom Azure Policy definition...' | grep "Creating the custom Azure Policy definition..."
pei 'az policy definition create --name k8sNoPrivilegeContainerVAP --display-name "Kubernetes cluster should not allow privileged containers" --description "Do not allow privileged containers creation in a Kubernetes cluster." --mode "Microsoft.Kubernetes.Data" --metadata "{\"version\":\"1.0.0\",\"category\":\"Kubernetes\"}" --params @params.json --rules @rules.json'

# Step 7: Assign the policy to your AKS cluster
echo 'Assigning the policy to the AKS cluster...' | grep "Assigning the policy to the AKS cluster..."
pei "az policy assignment create --name k8sNoPrivilegeContainerVAPAssignment --policy k8sNoPrivilegeContainerVAP --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME"

# # Step 8: List policy assignments to verify
echo 'Verifying the policy assignment...' | grep "Verifying the policy assignment..."
pei "az policy assignment show --name k8sNoPrivilegeContainerVAPAssignment \
 --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME"

# Step 9: Get AKS credentials
pei "az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing"

# Step 10: Verify the ConstraintTemplate was created in the cluster, takes about 5 - 15 mins for constraint to be deployed
echo 'Verifying the ConstraintTemplate creation...' | grep "Verifying the ConstraintTemplate creation..."
pei "kubectl get constrainttemplates k8spspprivilegedcontainer"

# Step 11: Verify the Constraint was created
echo 'Verifying the Constraint creation...' | grep "Verifying the Constraint creation..."
pei "kubectl get k8spspprivilegedcontainer"

# Step 12: Verify the ValidatingAdmissionPolicy was created
echo 'Verifying the ValidatingAdmissionPolicy creation...' | grep "Verifying the ValidatingAdmissionPolicy creation..."
pei "kubectl get validatingadmissionpolicies gatekeeper-k8spspprivilegedcontainer"

# Step 13: Verify the ValidatingAdmissionPolicyBinding was created
echo 'Verifying the ValidatingAdmissionPolicyBinding creation...' | grep "Verifying the ValidatingAdmissionPolicyBinding creation..."
pei "kubectl get validatingadmissionpolicybindings | grep k8spspprivilegedcontainer"

# Step 14: Test the policy by trying to create a privileged pod (should be denied)
echo 'Testing the policy by creating a privileged pod (should be denied)...' | grep "Testing the policy by creating a privileged pod (should be denied)..."
pei "kubectl run privileged-pod --image=nginx --restart=Never --overrides='{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx\",\"securityContext\":{\"privileged\":true}}]}}'"
