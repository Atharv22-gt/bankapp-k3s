# BankApp on K3s (adapted from the DevOpsShack Mega Project)

Original project used AWS EKS + Terraform + Jenkins + SonarQube + Nexus.
This version strips all of that out and deploys the same Spring Boot bank app
straight onto your existing K3s box — same Elastic IP, same `ingress-nginx`
you already have working for CloudMart.

Dropped from the original: Terraform/EKS, Jenkins/SonarQube/Nexus CI, EBS
storage, cert-manager/TLS, LoadBalancer-per-service monitoring stack.
Kept: the actual app, MySQL, Deployment/Service, HPA, Ingress — same shape,
just re-pointed at what you already have.

## 1. Build the image (multi-stage Dockerfile — no Maven install needed)

```bash
cd app-source
docker build -t YOUR_DOCKERHUB_USER/bankapp:v1 .
docker push YOUR_DOCKERHUB_USER/bankapp:v1
```

First build will take a few minutes (Maven downloads dependencies inside the
build stage). Runtime image is small since it's just a JRE + jar.

## 2. Update the image name in the manifest

Edit `k8s/02-bankapp.yaml`, replace:
```yaml
image: YOUR_DOCKERHUB_USER/bankapp:v1
```
with your actual pushed image.

## 3. Deploy

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-mysql.yaml
kubectl apply -f k8s/02-bankapp.yaml
kubectl apply -f k8s/03-hpa.yaml
kubectl apply -f k8s/04-ingress.yaml
```

Watch it come up:
```bash
kubectl get pods -n webapps -w
```

MySQL takes ~30-60s to become ready; bankapp's readiness probe also waits
60s before the first check (Spring Boot startup), so don't panic if it sits
at `0/1` for a bit.

## 4. Check the HPA works (needs metrics-server)

K3s ships with metrics-server enabled by default, but confirm:
```bash
kubectl get deployment metrics-server -n kube-system
kubectl top pods -n webapps
```
If `kubectl top` errors out, metrics-server isn't running — HPA won't get
real CPU/memory numbers until it is. (You disabled Traefik earlier for the
CloudMart project — metrics-server is a separate addon and shouldn't have
been affected, but worth checking since it's the same K3s install.)

## 5. Access it

Same pattern as CloudMart — add a hosts entry.

**On the EC2 box itself:**
```bash
echo "127.0.0.1  bankapp.dev.local" | sudo tee -a /etc/hosts
curl http://bankapp.dev.local/login
```

**On your laptop (for Chrome):**
```bash
echo "3.108.88.140  bankapp.dev.local" | sudo tee -a /etc/hosts
```
Then open `http://bankapp.dev.local` in Chrome. You should see the bank
app's login page.

## 6. Useful checks

```bash
kubectl get ingress -n webapps
kubectl get hpa -n webapps
kubectl logs -n webapps -l app=bankapp --tail=50
kubectl logs -n webapps -l app=mysql --tail=50
```

## Notes / things you gave up by skipping EKS+Jenkins

- No SonarQube/Trivy scanning — if you want that later, we can add Trivy as
  a manual `docker scan` step, or wire up a lightweight GitHub Actions
  pipeline instead of Jenkins (much less infra to babysit).
- No auto image-tag-bump-on-push (the Jenkins CD stage that edited
  `manifest.yaml` and pushed to git) — you're manually building/pushing/
  editing the image tag for now. A GitHub Actions workflow can replicate
  this cheaply if you want it later.
- MySQL has no backup/replication — fine for practice, not for real data.
