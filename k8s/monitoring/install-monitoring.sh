#!/bin/bash
# Install Prometheus and Grafana monitoring stack on EKS

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing monitoring stack...${NC}"

# Add Prometheus Helm repository
echo -e "${YELLOW}Adding Prometheus Helm repository...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo -e "${YELLOW}Creating monitoring namespace...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus stack with custom values
echo -e "${YELLOW}Installing Prometheus stack...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait \
  --timeout 10m

# Install AWS Load Balancer Controller (if not already installed)
echo -e "${YELLOW}Checking for AWS Load Balancer Controller...${NC}"
if ! kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
  echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"

  # Add EKS Helm repository
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update

  # Install AWS Load Balancer Controller
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=eks-assessment-dev \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller
else
  echo -e "${GREEN}AWS Load Balancer Controller already installed${NC}"
fi

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for monitoring pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Get Grafana admin password
echo -e "${GREEN}Monitoring stack installed successfully!${NC}"
echo ""
echo -e "${YELLOW}=== Access Information ===${NC}"
echo ""
echo "Grafana URL: http://$(kubectl get ingress -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Grafana Username: admin"
echo "Grafana Password: $(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"
echo ""
echo "Prometheus URL: http://$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9090"
echo ""
echo -e "${YELLOW}Port-forward Grafana locally:${NC}"
echo "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo ""
echo -e "${YELLOW}Port-forward Prometheus locally:${NC}"
echo "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
