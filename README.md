# K3s Microservices on AWS with Terraform

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![K3s](https://img.shields.io/badge/k3s-%230F4C75.svg?style=for-the-badge&logo=rancher&logoColor=white)](https://k3s.io/)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)](https://www.python.org/)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)

A production-ready **K3s Kubernetes cluster** on AWS EC2 deployed with **Terraform**, featuring a microservices demo with Frontend and Backend services communicating via Kubernetes networking.

## 🎯 Project Overview

This project demonstrates:
- **Infrastructure as Code (IaC)** using [Terraform](https://www.terraform.io/)
- **Lightweight Kubernetes** with [K3s](https://k3s.io/) (~50MB vs 2GB+ for full K8s)
- **AWS Free Tier** compatible deployment (`t3.micro` instances)
- **Containerized microservices** with Docker
- **Service-to-service communication** within Kubernetes
- **NodePort services** for external access
- **Monitoring with Prometheus** (optional)
- **Kubernetes Dashboard** for visualization (optional)

## 📐 Architecture

```
┌──────────────────────────────────────────────────┐
│                  Terraform                       │
│  (AWS VPC, Subnets, Security Groups, EC2)       │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│            AWS EC2 t3.micro (Master)             │
│  ┌────────────────────────────────────────────┐  │
│  │             K3s Cluster                    │  │
│  │  ┌──────────────────┐  ┌────────────────┐ │  │
│  │  │  Backend Service │  │ Frontend Service│ │  │
│  │  │  (Flask API)     │←─┤ (Flask Web)     │ │  │
│  │  │  Port: 5000      │  │ Port: 8080      │ │  │
│  │  │  2 replicas      │  │ 2 replicas      │ │  │
│  │  └──────────────────┘  └────────────────┘ │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### Service Communication Flow

```
User → Frontend Service (NodePort 30080)
         ↓
    Frontend Pod
         ↓ HTTP GET
    Backend Service (ClusterIP)
         ↓
    Backend Pod → Returns JSON data
```

## 📋 Prerequisites

### 1. AWS Account Setup

- [Create AWS account](https://portal.aws.amazon.com/billing/signup) (Free Tier eligible)
- [Create IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) with these policies:
  - `AmazonEC2FullAccess`
  - `AmazonVPCFullAccess`
  - `IAMFullAccess` (for key pair management)
- [Generate Access Keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)

### 2. Install Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **[Terraform](https://www.terraform.io/downloads)** | Infrastructure provisioning | `brew install terraform` (macOS)<br>`choco install terraform` (Windows) |
| **[AWS CLI](https://aws.amazon.com/cli/)** | AWS authentication | `brew install awscli` (macOS)<br>`pip install awscli` (Windows/Linux) |
| **[kubectl](https://kubernetes.io/docs/tasks/tools/)** | Kubernetes management | `brew install kubectl` (macOS)<br>`choco install kubernetes-cli` (Windows) |
| **[Docker](https://www.docker.com/products/docker-desktop)** | Container builds | [Download Docker Desktop](https://www.docker.com/products/docker-desktop) |

**Verify installations**:
```bash
terraform version   # v1.0+
aws --version       # 2.0+
kubectl version --client
docker --version
```

### 3. Configure AWS CLI

```bash
aws configure
```

Provide:
- **AWS Access Key ID**: `YOUR_ACCESS_KEY_ID`
- **AWS Secret Access Key**: `YOUR_SECRET_ACCESS_KEY`
- **Default region**: `us-east-1`
- **Output format**: `json`

### 4. Docker Hub Account

- [Sign up for Docker Hub](https://hub.docker.com/signup)
- Login locally: `docker login`

---

## 🚀 Quick Start (5 Minutes)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/k3s-microservices-aws.git
cd k3s-microservices-aws

# 2. Create SSH key pair for EC2
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k3s-cluster -N ""

# 3. Import key to AWS
aws ec2 import-key-pair \
  --key-name k3s-cluster \
  --public-key-material fileb://~/.ssh/k3s-cluster.pub \
  --region us-east-1

# 4. Deploy infrastructure
cd terraform
terraform init
terraform apply -auto-approve

# 5. Get kubeconfig (wait ~2 minutes for K3s to start)
MASTER_IP=$(terraform output -raw master_public_ip)
ssh -i ~/.ssh/k3s-cluster ubuntu@$MASTER_IP 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/k3s-config
sed -i '' "s/127.0.0.1/$MASTER_IP/g" ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config

# 6. Verify cluster
kubectl get nodes --insecure-skip-tls-verify

# 7. Build & push Docker images (AMD64 for EC2)
cd ../microservices/backend
docker buildx build --platform linux/amd64 -t YOUR_DOCKERHUB_USERNAME/backend-service:v1 --push .

cd ../frontend
docker buildx build --platform linux/amd64 -t YOUR_DOCKERHUB_USERNAME/frontend-service:v1 --push .

# 8. Update manifests with your Docker Hub username
# Edit kubernetes/manifests/backend-deployment.yaml
# Edit kubernetes/manifests/frontend-deployment.yaml
# Change: image: YOUR_DOCKERHUB_USERNAME/backend-service:v1 → YOUR_USERNAME/backend-service:v1

# 9. Deploy microservices
cd ../..
kubectl apply -f kubernetes/manifests/backend-deployment.yaml --validate=false --insecure-skip-tls-verify
kubectl apply -f kubernetes/manifests/frontend-deployment.yaml --validate=false --insecure-skip-tls-verify

# 10. Remove master node taint (allows pods on control plane)
kubectl taint nodes k3s-master CriticalAddonsOnly=true:NoExecute- --insecure-skip-tls-verify

# 11. Wait for pods to be Running
kubectl get pods -w --insecure-skip-tls-verify
# Press Ctrl+C when all pods show 1/1 Running

# 12. Test application
kubectl port-forward svc/frontend-service 8080:80 --insecure-skip-tls-verify
```

**In another terminal**:
```bash
curl http://localhost:8080/          # Frontend response
curl http://localhost:8080/data      # Frontend → Backend
```

**Expected output**:
```json
{"service":"frontend","status":"running","message":"Welcome to K3s Microservices!"}
{"service":"frontend","data":{"users":456,"requests":7890,"status":"healthy"}}
```

---

## 📁 Project Structure

```
k3s-microservices-aws/
│
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                        # VPC, Subnets, EC2, Security Groups
│   ├── variables.tf                   # Configurable parameters
│   ├── outputs.tf                     # IP addresses, kubeconfig commands
│   ├── terraform.tfvars               # Your custom values
│   └── scripts/
│       └── install-k3s.sh             # K3s bootstrap script
│
├── microservices/                      # Application code
│   ├── backend/
│   │   ├── app.py                     # Flask API (port 5000)
│   │   ├── Dockerfile                 # Backend container image
│   │   └── requirements.txt           # Python dependencies
│   │
│   └── frontend/
│       ├── app.py                     # Flask web (port 8080)
│       ├── Dockerfile                 # Frontend container image
│       └── requirements.txt           # Python dependencies
│
├── kubernetes/manifests/               # K8s resources
│   ├── backend-deployment.yaml        # Backend: Deployment + Service
│   └── frontend-deployment.yaml       # Frontend: Deployment + Service
│
└── README.md                          # This file
```

---

## 🔧 Detailed Setup Guide

### Step 1: Terraform Infrastructure

**Navigate to terraform directory**:
```bash
cd terraform
```

**Review/customize** `terraform.tfvars`:
```hcl
aws_region            = "us-east-1"
cluster_name          = "k3s-microservices"
master_instance_type  = "t3.micro"        # Free Tier eligible
worker_instance_type  = "t3.micro"
worker_count          = 0                 # 0 = master only (cost savings)
key_name              = "k3s-cluster"
allowed_ssh_cidr      = "0.0.0.0/0"      # Change to YOUR_IP/32 for security
```

**Initialize Terraform**:
```bash
terraform init
```

**Preview changes**:
```bash
terraform plan
```

**Deploy infrastructure** (~5 minutes):
```bash
terraform apply
```

Type `yes` when prompted.

**Expected resources created**:
- 1 VPC (`10.0.0.0/16`)
- 2 Subnets (public + private)
- 1 Internet Gateway
- 1 Route Table
- 1 Security Group (SSH + K3s API + NodePorts)
- 1 EC2 instance (`t3.micro`)
- K3s installed and running

**Get outputs**:
```bash
terraform output
```

```
master_public_ip = "44.200.157.180"
kubeconfig_command = "ssh -i ~/.ssh/k3s-cluster ubuntu@44.200.157.180 'sudo cat /etc/rancher/k3s/k3s.yaml'"
```

### Step 2: Access K3s Cluster

**Wait 2 minutes** for K3s to fully initialize, then:

```bash
# Get kubeconfig from master
MASTER_IP=$(terraform output -raw master_public_ip)
ssh -i ~/.ssh/k3s-cluster ubuntu@$MASTER_IP 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/k3s-config

# Replace localhost with public IP
sed -i '' "s/127.0.0.1/$MASTER_IP/g" ~/.kube/k3s-config  # macOS
# sed -i "s/127.0.0.1/$MASTER_IP/g" ~/.kube/k3s-config  # Linux

# Set kubeconfig environment variable
export KUBECONFIG=~/.kube/k3s-config

# Verify cluster access
kubectl get nodes --insecure-skip-tls-verify
```

**Expected**:
```
NAME         STATUS   ROLES                  AGE   VERSION
k3s-master   Ready    control-plane,master   5m    v1.28.5+k3s1
```

**Check system pods**:
```bash
kubectl get pods -A --insecure-skip-tls-verify
```

```
NAMESPACE     NAME                                     READY   STATUS    AGE
kube-system   coredns-...                              1/1     Running   5m
kube-system   local-path-provisioner-...               1/1     Running   5m
kube-system   metrics-server-...                       1/1     Running   5m
```

### Step 3: Build Microservices

**Why AMD64?** EC2 instances use x86_64 architecture. If you're on M1/M2 Mac (ARM64), you **must** build for `linux/amd64`.

**Backend**:
```bash
cd microservices/backend
docker buildx build --platform linux/amd64 \
  -t YOUR_DOCKERHUB_USERNAME/backend-service:v1 --push .
```

**Frontend**:
```bash
cd ../frontend
docker buildx build --platform linux/amd64 \
  -t YOUR_DOCKERHUB_USERNAME/frontend-service:v1 --push .
```

**Verify images**:
```bash
docker images | grep service
```

### Step 4: Update Kubernetes Manifests

**Edit** `kubernetes/manifests/backend-deployment.yaml`:
```yaml
spec:
  containers:
  - name: backend
    image: YOUR_DOCKERHUB_USERNAME/backend-service:v1  # Change this
```

**Edit** `kubernetes/manifests/frontend-deployment.yaml`:
```yaml
spec:
  containers:
  - name: frontend
    image: YOUR_DOCKERHUB_USERNAME/frontend-service:v1  # Change this
```

### Step 5: Deploy to K3s

```bash
cd ~/k3s-microservices-aws

# Deploy backend
kubectl apply -f kubernetes/manifests/backend-deployment.yaml \
  --validate=false --insecure-skip-tls-verify

# Deploy frontend
kubectl apply -f kubernetes/manifests/frontend-deployment.yaml \
  --validate=false --insecure-skip-tls-verify
```

**Remove master node taint** (allows workloads on control-plane):
```bash
kubectl taint nodes k3s-master CriticalAddonsOnly=true:NoExecute- --insecure-skip-tls-verify
```

**Watch deployment**:
```bash
kubectl get pods --insecure-skip-tls-verify
```

**Expected**:
```
NAME                                  READY   STATUS    RESTARTS   AGE
backend-deployment-55566f6f64-abc12   1/1     Running   0          2m
backend-deployment-55566f6f64-def34   1/1     Running   0          2m
frontend-deployment-bfd64d5bd-ghi56   1/1     Running   0          2m
frontend-deployment-bfd64d5bd-jkl78   1/1     Running   0          2m
```

### Step 6: Test Application

**Method 1: Port Forwarding** (localhost access):
```bash
kubectl port-forward svc/frontend-service 8080:80 --insecure-skip-tls-verify
```

In another terminal:
```bash
# Test frontend
curl http://localhost:8080/
# {"service":"frontend","status":"running","message":"Welcome to K3s Microservices!"}

# Test frontend → backend communication
curl http://localhost:8080/data
# {"service":"frontend","data":{"users":456,"requests":7890,"status":"healthy"}}
```

**Method 2: NodePort** (external access):
```bash
# Get NodePort
kubectl get svc frontend-service --insecure-skip-tls-verify
# NAME               TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
# frontend-service   NodePort   10.43.123.45   <none>        80:30080/TCP   5m

# Access via EC2 public IP
MASTER_IP=$(cd terraform && terraform output -raw master_public_ip)
curl http://$MASTER_IP:30080/
curl http://$MASTER_IP:30080/data
```

---

## 📊 Monitoring & Management (Optional)

### Step 7: Install Kubernetes Dashboard

The [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) provides a web UI for cluster visualization.

```bash
# Install dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml \
  --insecure-skip-tls-verify

# Create admin service account
cat <<EOF | kubectl apply -f - --insecure-skip-tls-verify
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Get access token
kubectl -n kubernetes-dashboard create token admin-user --insecure-skip-tls-verify

# Start kubectl proxy
kubectl proxy --insecure-skip-tls-verify
```

**Access Dashboard**:
Visit: [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

Paste the token when prompted.

**⚠️ Note**: Dashboard is **resource-intensive** on t3.micro. Consider removing after exploration:
```bash
kubectl delete namespace kubernetes-dashboard --insecure-skip-tls-verify
```

### Step 8: Install Prometheus Monitoring

[Prometheus](https://prometheus.io/) provides metrics collection and monitoring for your cluster.

```bash
# Create monitoring namespace
kubectl create namespace monitoring --insecure-skip-tls-verify

# Install Prometheus Operator
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml \
  --insecure-skip-tls-verify

# Wait for CRDs to be ready
sleep 30

# Create ServiceAccount and RBAC
cat <<EOF | kubectl apply -f - --insecure-skip-tls-verify
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

# Deploy Prometheus instance
cat <<EOF | kubectl apply -f - --insecure-skip-tls-verify
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  replicas: 1
  resources:
    requests:
      memory: 200Mi
      cpu: 100m
    limits:
      memory: 400Mi
      cpu: 200m
EOF

# Expose Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 --insecure-skip-tls-verify
```

**Access Prometheus**: [http://localhost:9090](http://localhost:9090)

**⚠️ Note**: Prometheus is **resource-intensive** on t3.micro. Monitor with `kubectl top nodes` and remove if cluster struggles:
```bash
kubectl delete namespace monitoring --insecure-skip-tls-verify
```

---

## 🧪 Testing & Validation

### Comprehensive Application Tests

```bash
# Get master public IP
MASTER_IP=$(cd terraform && terraform output -raw master_public_ip)

# Get NodePort
NODE_PORT=$(kubectl get svc frontend-service -o jsonpath='{.spec.ports[0].nodePort}' --insecure-skip-tls-verify)

# Test 1: Frontend service (NodePort)
echo "Testing frontend..."
curl http://$MASTER_IP:$NODE_PORT/

# Test 2: Backend connectivity through frontend
echo "Testing backend via frontend..."
curl http://$MASTER_IP:$NODE_PORT/data

# Test 3: Check pod logs
echo "Frontend logs:"
kubectl logs -l app=frontend --tail=20 --insecure-skip-tls-verify

echo "Backend logs:"
kubectl logs -l app=backend --tail=20 --insecure-skip-tls-verify

# Test 4: Scaling
echo "Testing horizontal scaling..."
kubectl scale deployment frontend-deployment --replicas=3 --insecure-skip-tls-verify
kubectl scale deployment backend-deployment --replicas=3 --insecure-skip-tls-verify

# Wait and verify
sleep 15
kubectl get pods --insecure-skip-tls-verify

# Test 5: Pod health and readiness
kubectl describe pod -l app=frontend --insecure-skip-tls-verify | grep -A 5 "Conditions:"
kubectl describe pod -l app=backend --insecure-skip-tls-verify | grep -A 5 "Conditions:"

# Test 6: Service endpoints
kubectl get endpoints --insecure-skip-tls-verify

# Test 7: Load test (simple)
echo "Running simple load test..."
for i in {1..10}; do
  curl -s http://$MASTER_IP:$NODE_PORT/data &
done
wait
echo "Load test complete"

# Scale back down to save resources
kubectl scale deployment frontend-deployment --replicas=1 --insecure-skip-tls-verify
kubectl scale deployment backend-deployment --replicas=1 --insecure-skip-tls-verify
```

### Resource Monitoring

```bash
# Check resource usage
kubectl top nodes --insecure-skip-tls-verify
kubectl top pods --insecure-skip-tls-verify

# Check events
kubectl get events --sort-by='.lastTimestamp' --insecure-skip-tls-verify

# Describe deployments
kubectl describe deployment backend-deployment --insecure-skip-tls-verify
kubectl describe deployment frontend-deployment --insecure-skip-tls-verify
```

---

## 🔍 Troubleshooting

### Issue: `kubectl` commands timeout

**Cause**: API server overloaded (t3.micro has only 1 vCPU, 1 GB RAM)

**Solution**:
```bash
# Scale down to 1 replica per service
kubectl scale deployment backend-deployment --replicas=1 --insecure-skip-tls-verify
kubectl scale deployment frontend-deployment --replicas=1 --insecure-skip-tls-verify

# Delete heavy workloads (if installed)
kubectl delete namespace monitoring --insecure-skip-tls-verify
kubectl delete namespace kubernetes-dashboard --insecure-skip-tls-verify
```

### Issue: Pods stuck in `ContainerCreating`

**Cause 1**: Image architecture mismatch (ARM64 image on AMD64 EC2)

```bash
kubectl describe pod <POD_NAME> --insecure-skip-tls-verify
# Look for: "no match for platform" or "exec format error"

# Solution: Rebuild for AMD64
docker buildx build --platform linux/amd64 -t YOUR_USERNAME/service:v1 --push .
kubectl rollout restart deployment <DEPLOYMENT_NAME> --insecure-skip-tls-verify
```

**Cause 2**: Image pull authentication

```bash
# Check events
kubectl describe pod <POD_NAME> --insecure-skip-tls-verify
# Look for: "ErrImagePull" or "ImagePullBackOff"

# Solution: Ensure images are public on Docker Hub or create secret
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --insecure-skip-tls-verify
```

### Issue: Pods in `Pending` state

**Cause**: Master node has `NoSchedule` taint

```bash
kubectl describe pod <POD_NAME> --insecure-skip-tls-verify
# Look for: "0/1 nodes are available: 1 node(s) had untolerated taint"

# Solution: Remove taint
kubectl taint nodes k3s-master CriticalAddonsOnly=true:NoExecute- --insecure-skip-tls-verify
```

### Issue: Cannot SSH to EC2

**Cause**: Security Group blocking your IP

```bash
# Check current IP
curl ifconfig.me

# Update Security Group in AWS Console:
# EC2 → Security Groups → k3s-master-sg → Inbound Rules
# Type: SSH, Source: YOUR_IP/32
```

### Issue: K3s not responding

**SSH to master** and check:
```bash
ssh -i ~/.ssh/k3s-cluster ubuntu@$MASTER_IP

# Check K3s status
sudo systemctl status k3s

# View logs
sudo journalctl -u k3s -n 50 --no-pager

# Restart K3s
sudo systemctl restart k3s
sleep 30
sudo systemctl status k3s
```

---

## 🧹 Cleanup

### Delete Kubernetes Resources

```bash
# Delete microservices
kubectl delete -f kubernetes/manifests/ --insecure-skip-tls-verify

# Delete monitoring (if installed)
kubectl delete namespace monitoring --insecure-skip-tls-verify

# Delete dashboard (if installed)
kubectl delete namespace kubernetes-dashboard --insecure-skip-tls-verify
```

### Destroy AWS Infrastructure

```bash
cd terraform
terraform destroy -auto-approve
```

Confirm by typing `yes` when prompted.

### Cleanup Local Files

```bash
# Delete SSH key from AWS
aws ec2 delete-key-pair --key-name k3s-cluster --region us-east-1

# Delete local SSH keys (optional)
rm ~/.ssh/k3s-cluster ~/.ssh/k3s-cluster.pub

# Delete kubeconfig
rm ~/.kube/k3s-config

# Unset environment variable
unset KUBECONFIG
```

**Estimated Cost**: 
- **Free Tier**: $0 (750 hours/month t3.micro)
- **Beyond Free Tier**: ~$0.01/hour (~$7/month) for t3.micro

---

## 📚 Resources

### Official Documentation
- [K3s Documentation](https://docs.k3s.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Docker Documentation](https://docs.docker.com/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

### Related Guides
- [AWS Free Tier Details](https://aws.amazon.com/free/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Docker Multi-platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [K3s Quick Start Guide](https://docs.k3s.io/quick-start)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### Useful Commands

**Terraform**:
```bash
terraform fmt        # Format code
terraform validate   # Validate syntax
terraform show       # Show current state
terraform output     # Show outputs
terraform refresh    # Sync state with real infrastructure
```

**kubectl**:
```bash
kubectl get all -A --insecure-skip-tls-verify           # All resources
kubectl logs <POD_NAME> --insecure-skip-tls-verify      # Pod logs
kubectl logs -f <POD_NAME> --insecure-skip-tls-verify   # Follow logs
kubectl exec -it <POD_NAME> -- /bin/sh --insecure-skip-tls-verify  # Shell into pod
kubectl describe node k3s-master --insecure-skip-tls-verify        # Node details
kubectl top nodes --insecure-skip-tls-verify            # Resource usage
kubectl top pods --insecure-skip-tls-verify             # Pod resource usage
```

**Docker**:
```bash
docker ps                    # Running containers
docker images                # Local images
docker system prune -a       # Clean up everything
docker buildx ls             # List builders
docker login                 # Login to Docker Hub
```

**AWS CLI**:
```bash
aws ec2 describe-instances   # List EC2 instances
aws ec2 describe-key-pairs   # List key pairs
aws ec2 describe-vpcs        # List VPCs
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Vijaya Valeti**
- GitHub: [@yourusername](https://github.com/yourusername)
- LinkedIn: [Your LinkedIn](https://linkedin.com/in/yourprofile)

---

## ⭐ Acknowledgments

- [Rancher Labs](https://rancher.com/) for K3s
- [HashiCorp](https://www.hashicorp.com/) for Terraform
- [AWS](https://aws.amazon.com/) for cloud infrastructure
- Kubernetes community
- [Prometheus](https://prometheus.io/) and CNCF for monitoring tools

---

## 🎓 Learning Resources

### Video Tutorials
- [Terraform Tutorial for Beginners](https://www.youtube.com/watch?v=SLB_c_ayRMo)
- [Kubernetes Crash Course](https://www.youtube.com/watch?v=X48VuDVv0do)
- [K3s vs K8s: What's the Difference?](https://www.youtube.com/watch?v=2LNxGVS81mE)

### Books
- **Kubernetes in Action** by Marko Lukša
- **Terraform: Up & Running** by Yevgeniy Brikman
- **The DevOps Handbook** by Gene Kim

### Online Courses
- [Kubernetes for the Absolute Beginners](https://www.udemy.com/course/learn-kubernetes/)
- [Terraform Associate Certification](https://www.hashicorp.com/certification/terraform-associate)
- [AWS Certified Solutions Architect](https://aws.amazon.com/certification/certified-solutions-architect-associate/)

---

**Built with ❤️ for learning DevOps, Cloud, and Kubernetes**