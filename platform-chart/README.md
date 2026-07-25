# bankapp-platform — one Helm chart, one ArgoCD Application

Ye sab kuch ek jagah bundle karta hai: BankApp + MySQL + Elasticsearch +
Kibana + Filebeat + dono Ingress (bankapp aur kibana). ArgoCD ko sirf **ek**
Application chahiye — is chart ke path ki taraf pointing — aur wahi teen alag
Applications (elasticsearch/kibana/filebeat) ki jagah leta hai.

Sab kuch `webapps` namespace me deploy hoga (jaisa bola gaya, `logging` alag
namespace ki zaroorat nahi).

## 1. Is folder ko apne `bankapp-k3s` repo me daalo

```bash
cd ~/atharv/bankapp-k3s
cp -r /path/to/platform-chart .
```

(Ya seedha yahi naya folder banake files copy kar do — path tumhare hisaab se.)

## 2. Image repo update karo

`platform-chart/values.yaml` me:
```yaml
bankapp:
  image:
    repository: YOUR_DOCKERHUB_USER/bankapp
```
Apna actual Docker Hub username daal do.

## 3. Chart dependencies resolve karo (Elastic subcharts download honge)

```bash
cd platform-chart
helm repo add elastic https://helm.elastic.co
helm repo update
helm dependency build
```

## 4. Purane manual/multiple-Application resources clean karo

Ye zaroori hai — purane standalone Elasticsearch/Kibana/Filebeat installs
(chahe manual `helm install` se the, ya alag ArgoCD Applications se) is naye
combined chart ke saath naam-conflict karenge:

```bash
# Agar teen alag ArgoCD Applications banaye the unhe hatao:
kubectl delete application elasticsearch kibana filebeat -n argocd --ignore-not-found

# Agar manually helm install kiya tha:
helm uninstall elasticsearch -n logging --ignore-not-found
helm uninstall kibana -n logging --ignore-not-found
helm uninstall filebeat -n logging --ignore-not-found
kubectl delete namespace logging --ignore-not-found

# Purana standalone bankapp bhi hatao agar `k8s/*.yaml` se tha
kubectl delete application bankapp -n argocd --ignore-not-found
```

⚠️ Isse purana Elasticsearch data (PVC) bhi chala jayega — fresh start hoga.

## 5. Git me push karo

```bash
cd ~/atharv/bankapp-k3s
git add platform-chart/
git commit -m "Consolidate bankapp + ELK into single Helm chart"
git push
```

## 6. Ek hi ArgoCD Application banao

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bankapp-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_GITHUB_USERNAME/bankapp-k3s.git
    targetRevision: main
    path: platform-chart
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: webapps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

`YOUR_GITHUB_USERNAME` apna daalo.

## 7. Sync watch karo

```bash
kubectl get application bankapp-platform -n argocd -w
kubectl get pods -n webapps -w
```

Elasticsearch ko `1/1 Running` hone me sabse zyada time lagega (~1-2 min).

## 8. Ab HPA vs ArgoCD conflict wala fix (yaad hai pichli baar?)

Same issue phir se ho sakta hai — HPA replicas badlega, ArgoCD usse "drift"
samjhega. Isliye chart ke `bankapp.yaml` template me maine already
`replicas` field Deployment spec se **hata diya hai** jab HPA enabled ho
(dekho `templates/bankapp.yaml` — `{{- if not .Values.bankapp.hpa.enabled }}`
wala block) — is baar `ignoreDifferences` ki bhi zaroorat nahi padegi.

## Access

Same jaisa pehle:
```bash
# laptop pe
echo "3.108.88.140  bankapp.dev.local" | sudo tee -a /etc/hosts
echo "3.108.88.140  kibana.dev.local" | sudo tee -a /etc/hosts
```

## Future changes

Ab bas `platform-chart/values.yaml` edit karo (chahe image tag ho, HPA
limits ho, ya ELK resources), `git push` karo — ArgoCD khud sync kar dega.
Koi manual `helm upgrade` ya multiple Applications manage nahi karne padenge.
