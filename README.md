# Swimlane DevOps Practical

This project implements the **Swimlane DevOps Practical** end-to-end using:

- Docker
- Kubernetes
- Terraform
- Helm
- MongoDB
- RBAC
- NetworkPolicies
- HPA
- Ansible + Packer artifacts

The objective is to containerize the application, deploy it in a resilient Kubernetes cluster, remove single points of failure, add scalability, and ensure security controls.

---

## 📋 Prerequisites

The following tools are required:

- **Docker** (>= 20.10)
- **Kubectl** (>= 1.29)
- **Helm** (v3)
- **Terraform** (>= 1.12.2)
- **Kind** (Kubernetes in Docker) (>= 0.20.0)
- **Git**
- **Ansible**
- **Packer**

---

## ⚙️ Kind Cluster Setup

I used Terraform with the [`tehcyx/kind`](https://registry.terraform.io/providers/tehcyx/kind/latest/docs) provider to provision a multi-node Kind cluster inside Docker.  
This provides reproducible local infrastructure for deploying both the application and MongoDB.

### Nodes Created

The `kind_config` block in Terraform defines:

#### Control-plane nodes
- At least **2 replicas** for high availability
- Prevents a single master node from being a single point of failure
- Handles Kubernetes API requests, scheduling, etc.

#### App worker nodes
- Dedicated worker nodes with label `role=app`
- Ensures application pods are scheduled only on app-workers (via `nodeSelector`)
- **Benefits:** Separation of concerns, avoids resource contention with DB

#### Mongo worker nodes
- Dedicated worker nodes with label `role=mongo`
- Ensures MongoDB StatefulSet pods always run on these nodes
- **Benefits:** Stability for storage workloads, predictable placement, easier debugging

#### Why multiple replicas / sets?
- **Control plane (replica set of 2):** Increases resilience; if one API server fails, cluster still works
- **App deployment (replica count 2):** Ensures load is distributed, rolling updates are safe, and downtime is minimized
- **MongoDB StatefulSet (replica count 2, rs0):** Provides a replica set with primary/secondary for data redundancy and failover

---

## 🕵️‍♂️ Cluster Validation

```sh
kubectl get nodes -o wide
kubectl describe node <node-name>
```

**Example Output:**

| NAME                           | ROLES           | LABELS     |
|---------------------------------|-----------------|------------|
| devops-cluster-control-plane    | control-plane   | ...        |
| devops-cluster-control-plane2   | control-plane   | ...        |
| devops-cluster-worker           | <none>          | role=app   |
| devops-cluster-worker2          | <none>          | role=app   |
| devops-cluster-worker3          | <none>          | role=mongo |
| devops-cluster-worker4          | <none>          | role=mongo |

---

## 🚀 Application Deployment

### Step 1 – Dockerize Application

The provided app ([source](https://github.com/swimlane/devops-practical)) was containerized using a `Dockerfile`.

- Non-essential files (Terraform, Helm, secrets, etc.) were excluded via `.dockerignore`
- Built and tagged as:

```sh
docker build -t tesseractdev12/swimlane-project:v1.0.2 .
docker push tesseractdev12/swimlane-project:v1.0.2
```

- **Docker Hub Repo:**  
  The image is available at [tesseractdev12/swimlane-project](https://hub.docker.com/r/tesseractdev12/swimlane-project)  
  Kubernetes pulls this image directly for deployment.

---

### Step 2 – Helm Chart

A custom Helm chart (`./helm/swimlane-app`) manages all Kubernetes resources.

#### Components Created

- **App Deployment + Service**
  - Deployment runs 2 replicas of the app
  - Service (ClusterIP) exposes the app inside the cluster
  - Configured with `nodeSelector: role=app` so pods land only on app workers
  - Env variable `MONGODB_URL` injected with cluster-internal MongoDB replica set connection string

- **MongoDB StatefulSet + Headless Service**
  - StatefulSet runs MongoDB in replica set (`rs0`) mode with 2 replicas
  - Uses PersistentVolumeClaims for durable storage
  - Headless Service (`clusterIP: None`) ensures stable DNS records:
    - `swimlane-mongodb-0.swimlane-mongodb:27017`
    - `swimlane-mongodb-1.swimlane-mongodb:27017`
  - Pods scheduled only on nodes labeled `role=mongo`

- **Init Job to bootstrap ReplicaSet**
  - A Kubernetes Job runs once to initialize the Mongo replica set
  - Waits for both Mongo pods to be ready, then runs:
    ```js
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "swimlane-mongodb-0.swimlane-mongodb:27017" },
        { _id: 1, host: "swimlane-mongodb-1.swimlane-mongodb:27017" }
      ]
    })
    ```
  - Without this step, Mongo would stay in "RSGhost" state and the app would fail to connect

- **Ingress for external access**
  - Ingress rule routes external traffic (via NGINX ingress controller) to the app service
  - Host set to `localhost` for Kind cluster

- **NetworkPolicies and RBAC**
  - **NetworkPolicy** only allows:
    - Ingress-nginx → App pods (port 3000)
    - App pods → Mongo pods (port 27017)
  - **RBAC** configured:
    - ServiceAccount, Role, and RoleBinding created for app
    - Restricts app to only get/list configmaps

- **HorizontalPodAutoscaler (HPA)**
  - Autoscaling configured for the app deployment
  - Rules:
    - `minReplicas: 2`
    - `maxReplicas: 5`
    - `average CPU utilization: 70%`
  - Enables cluster elasticity for higher load

---

### Step 3 – Deploy via Helm

Deploy all resources with:

```sh
helm upgrade --install swimlane ./helm/swimlane-app
```

This creates all resources in the correct order:

1. MongoDB StatefulSet & Headless Service
2. Init Job for replica set
3. App Deployment & Service
4. NetworkPolicy + RBAC
5. Ingress
6. HPA

---

## ✅ Validation Commands

- **Check pods:**
  ```sh
  kubectl get pods
  ```
- **Check services:**
  ```sh
  kubectl get svc
  ```
- **Check ingress:**
  ```sh
  kubectl get ingress
  ```
- **Check HPA scaling:**
  ```sh
  kubectl get hpa
  ```

---

## 🌐 Application Access

### Method 1 – Ingress + NGINX (via Terraform)

In my Terraform cluster setup, I pre-configured an NGINX ingress controller.  
The Helm chart then deployed an Ingress resource that points traffic on host `localhost` to the app’s service on port 3000.

**Access the app at:**
```
http://localhost
```
This is the primary and preferred method of accessing the application in this setup.

---

### Method 2 – Port Forwarding (Fallback Option)

If ingress is unavailable (for example, in a different local Kind setup or if the ingress controller is not running), you can access the app using Kubernetes port forwarding:

```sh
kubectl port-forward svc/swimlane-app 3000:3000
```

Then open the application in your browser at:

```
http://localhost:3000
```

✅ In my Terraform + Kind setup, Ingress is the main access method, while port-forwarding remains a reliable backup.

---

## 🍃 MongoDB Testing

Once MongoDB StatefulSet is running inside the cluster, you can connect directly into the pod and run basic queries:

```sh
kubectl exec -it swimlane-mongodb-0 -- mongosh
```

**Basic commands:**
```js
show dbs                   // list available databases
use devops                 // switch to our application database
show collections           // list collections in devops
db.users.find().pretty()   // check stored users
db.articles.find().pretty() // check articles posted from the app
```

**Insert example record:**
```js
db.users.insertOne({
  name: "M Shoaib",
  email: "mshob@swim.com",
  role: "admin"
})
```

✅ After inserting, you can immediately confirm by running `db.users.find().pretty()` again.

---

## 🔐 Security Controls

I implemented baseline Kubernetes security hardening in my Helm chart:

- **RBAC:**
  - Created a dedicated ServiceAccount for the app.
  - Bound it with a minimal Role + RoleBinding that only allows read access to configmaps.
  - This avoids running the app with the default service account (principle of least privilege).

- **NetworkPolicies:**
  - Restricted inbound access to app pods only from the ingress-nginx namespace.
  - Restricted inbound access to MongoDB pods only from app pods.
  - By default, all other pod-to-pod traffic is denied.

- **TLS:**
  - Not finalized (remains HTTP for now due to issues with tls.crt/tls.key secrets in Kind).
  - In a production environment, this would be replaced with a ClusterIssuer and cert-manager to auto-manage Let’s Encrypt certificates.

---

## 📈 Scalability

I enabled HorizontalPodAutoscaler (HPA) to dynamically scale the app deployment:

- **Minimum replicas:** 2
- **Maximum replicas:** 5
- **CPU threshold:** 70% average utilization

### Load Testing

Generate artificial load with a busybox pod:

```sh
kubectl run -it load-generator --rm --image=busybox -- /bin/sh
```

Inside the pod, run:

```sh
while true; do wget -q -O- http://swimlane-app.default.svc.cluster.local:3000 > /dev/null; done
```

Observe scaling in real time:

```sh
kubectl get hpa swimlane-app -w
```

You will see the replicas of `swimlane-app` increase automatically as CPU usage crosses the threshold, and scale back down when load reduces.

---

## ✅ End-to-End Validation

- DB reads/writes working
- Security isolation applied
- Autoscaling and resilience demonstrated

---

**Docker Hub Repo:**  
[tesseractdev12/swimlane-project](https://hub.docker.com/r/tesseractdev12/swimlane-project)

---