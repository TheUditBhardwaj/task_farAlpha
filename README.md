
# 1. Provide instructions on how to build and push the Docker image to a container registry.
## Step 1: Navigate to Project Directory

Ensure you are in the project root directory where the `Dockerfile` is located.

```bash
cd flask-mongodb-app

```

## Step 2: Build the Docker Image

Run the build command to create the image based on your `Dockerfile`.

```bash
docker build -t flask-mongo-app .

```

To verify the image was created successfully, list your local images:

```bash
docker images

```

## Step 3: Log in to Docker Hub

Authenticate your local terminal with your Docker Hub account. Use your Docker ID and password (or access token) when prompted.

```bash
docker login

```

## Step 4: Tag the Docker Image

Before pushing, you must tag the image with your Docker Hub namespace. 

```bash
docker tag flask-mongo-app uditbhardwaj/flask-mongo-app:latest

```

## Step 5: Push the Image to Docker Hub

Upload the tagged image to the public or private repository in your registry.

```bash
docker push uditbhardwaj/flask-mongo-app:latest

```

## Step 6: Verify the Image

1. Open [Docker Hub](https://hub.docker.com/) in your browser.
2. Log in and navigate to your repositories.
3. Confirm that the `flask-mongo-app` repository exists and contains the `latest` tag.

## Step 7: Use the Image in Kubernetes

Update your Kubernetes deployment manifest (e.g., `deployment.yaml`) to reference the newly pushed image.

```yaml
spec:
  containers:
  - name: flask-app
    image: uditbhardwaj/flask-mongo-app:latest

```

# 2. Provide the Kubernetes YAML files for all resources created.


# Kubernetes Resources

All Kubernetes manifests for this project are stored in the `k8s/` directory. 

```bash
kubectl apply -f k8s/

```

## Resource Manifests

### 1. MongoDB Secret (`mongo-secret.yaml`)

Stores MongoDB root credentials securely using a Kubernetes Secret.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongo-secret
type: Opaque
stringData:
  MONGO_INITDB_ROOT_USERNAME: admin
  MONGO_INITDB_ROOT_PASSWORD: admin1237

```

### 2. Persistent Volume Claim (`mongo-pvc.yaml`)

Requests storage from the cluster to ensure database persistence across Pod restarts.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

```

### 3. MongoDB Service (`mongo-service.yaml`)

An internal `ClusterIP` service that allows the Flask app to communicate with the database.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo-service
spec:
  type: ClusterIP
  selector:
    app: mongo
  ports:
    - port: 27017
      targetPort: 27017

```

### 4. MongoDB StatefulSet (`mongo-statefulset.yaml`)

Deploys MongoDB with attached persistent storage and authentication enabled.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongo
spec:
  serviceName: mongo-service
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
        - name: mongo
          image: mongo:5.0
          ports:
            - containerPort: 27017
          envFrom:
            - secretRef:
                name: mongo-secret
          args: ["--auth"]
          volumeMounts:
            - name: mongo-storage
              mountPath: /data/db
          resources:
            requests:
              cpu: "200m"
              memory: "250Mi"
            limits:
              cpu: "500m"
              memory: "500Mi"
      volumes:
        - name: mongo-storage
          persistentVolumeClaim:
            claimName: mongo-pvc

```

### 5. Flask Deployment (`flask-deployment.yaml`)

Manages the Flask application instances, pulling the image from the registry.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flask
  template:
    metadata:
      labels:
        app: flask
    spec:
      containers:
        - name: flask
          image: uditbhardwaj/flask-mongo-app:latest
          ports:
            - containerPort: 5000
          env:
            - name: MONGODB_URI
              value: mongodb://admin:admin123@mongo-service:27017/flask_db?authSource=admin
          resources:
            requests:
              cpu: "200m"
              memory: "250Mi"
            limits:
              cpu: "500m"
              memory: "500Mi"

```

### 6. Flask Service (`flask-service.yaml`)

Exposes the application externally via a `NodePort`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  type: NodePort
  selector:
    app: flask
  ports:
    - port: 5000
      targetPort: 5000

```

### 7. Horizontal Pod Autoscaler (`hpa.yaml`)

Automatically scales the Flask Deployment between 2 and 5 replicas based on CPU load.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: flask-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: flask-app
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

```

### 8. Load Generator (`load-generator.yaml`)

A helper Pod used to simulate traffic and trigger the HPA scaling.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
spec:
  containers:
    - name: load-generator
      image: python:3.9-slim
      command: ["/bin/sh"]
      args:
        - "-c"
        - |
          pip install requests &&
          while true; do
            python -c "import requests; requests.get('http://flask-service:5000/data')"
          done

```

---


# 3. steps to deploy the Flask application and MongoDB on a Minikube Kubernetes cluster.

## Step 1: Start Minikube

Initialize your local Kubernetes cluster.

```bash
minikube start

```

**Verify cluster status:**

```bash
kubectl get nodes

```

## Step 2: Enable Metrics Server

The Metrics Server is required for the **Horizontal Pod Autoscaler (HPA)** to function.

```bash
minikube addons enable metrics-server

```

**Verify installation:**

```bash
kubectl get deployment metrics-server -n kube-system

```

## Step 3: Prepare Manifests

Navigate to your project root and ensure all YAML files are organized.

```bash
cd flask-mongodb-app
ls k8s/

```

## Step 4: Deploy MongoDB

Deploy the database layer in order: Secret  PVC  Service  StatefulSet.

1. **Create Secret:** `kubectl apply -f k8s/mongo-secret.yaml`
2. **Create PVC:** `kubectl apply -f k8s/mongo-pvc.yaml`
3. **Create Service:** `kubectl apply -f k8s/mongo-service.yaml`
4. **Deploy StatefulSet:** `kubectl apply -f k8s/mongo-statefulset.yaml`

**Check MongoDB Pod status:**

```bash
kubectl get pods

```

## Step 5: Deploy Flask Application

Deploy the application and expose it to external traffic.

1. **Deploy Flask:** `kubectl apply -f k8s/flask-deployment.yaml`
2. **Expose Service:** `kubectl apply -f k8s/flask-service.yaml`

**Verify service and port:**

```bash
kubectl get svc flask-service

```

## Step 6: Access & Test Connectivity

Verify that the Flask app can communicate with MongoDB.

### 1. Insert Data

```bash
curl -X POST -H "Content-Type: application/json" \
-d '{"k8s":"connected"}' \
http://192.168.49.2:32595/data

```

### 2. Retrieve Data

```bash
curl http://192.168.49.2:32595/data

```

## Step 7: Configure & Test Autoscaling

Apply the HPA and simulate traffic to observe scaling behavior.

1. **Apply HPA:** `kubectl apply -f k8s/hpa.yaml`
2. **Start Load Generator:** `kubectl apply -f k8s/load-generator.yaml`

**Monitor scaling in real-time:**

```bash
kubectl get hpa -w

```

*(Once testing is complete, delete the load generator: `kubectl delete pod load-generator`)*

## Step 8: Verify Persistence

Confirm that data survives a application restart.

```bash
# Restart Flask pods
kubectl delete pods -l app=flask

# Verify data is still present
curl http://192.168.49.2:32595/data

```

---

## Autoscaling (Horizontal Pod Autoscaler) Results 

The Flask application was set to automatically increase or decrease the number
of running pods based on CPU usage.

### HPA Settings
- Minimum pods: 2  
- Maximum pods: 5  
- CPU limit for scaling: 70%  

---

### Initial State
When the application started, only **2 pods** were running.

<img width="709" height="46" alt="03-hpa-initial" src="https://github.com/user-attachments/assets/70e26d63-f07e-4bb0-862f-6c56942f8f2a" />



---

### Load Testing
To test autoscaling, a load generator was used to send many requests to the
Flask application. This increased CPU usage.

**What happened:**
- CPU usage went up to about **167%**
- Kubernetes automatically increased pods from **2 → 4 → 5**

<img width="655" height="131" alt="04-hpa-scale-up" src="https://github.com/user-attachments/assets/a5a478fb-6b7c-4b4a-b460-689e26f68376" />


---

### HPA Events
Kubernetes recorded events showing that autoscaling happened automatically
when CPU usage increased.

<img width="1035" height="114" alt="05-hpa-events" src="https://github.com/user-attachments/assets/a5044875-123a-40ec-9734-d2a945b5c39d" />


---

### Scale Down Behavior
After stopping the load generator:
- CPU usage dropped below **70%**
- Pods were slowly reduced from **5 → 4**
- This slow reduction avoids sudden changes

<img width="739" height="140" alt="06-hpa-scale-down" src="https://github.com/user-attachments/assets/7c09030b-a145-41b1-a988-78d79ceea4b1" />


---

### Final Result
The autoscaling worked correctly:
- Pods increased when the app was busy
- The app stayed available during heavy load
- Pods reduced safely when traffic stopped




# 4. DNS Resolution in Kubernetes 

In Kubernetes, **DNS works like a phone contact list**.

Instead of remembering difficult IP numbers, pods talk to each other using
**easy names**.

In this project:
- MongoDB has a service called **`mongo-service`**
- The Flask app talks to MongoDB using this name

Kubernetes automatically finds **where MongoDB is running** and connects them,
even if MongoDB restarts or moves to another pod.

So, Flask does not need to know MongoDB’s IP — Kubernetes handles it.

---

# 5. Resource Requests and Limits 

Resource requests and limits tell Kubernetes **how much power an app needs**.

- **Request** = minimum CPU and memory the app needs to run
- **Limit** = maximum CPU and memory the app can use

In this project:
- We told Kubernetes the minimum and maximum resources for Flask and MongoDB
- This prevents one app from using too much power
- It keeps everything running smoothly

These settings also help Kubernetes **add more pods automatically** when the
app is busy.

# 6. Design Choices 

### 1. MongoDB as a StatefulSet
**Why chosen:**  
MongoDB needs to keep its data safe even if the pod restarts. A StatefulSet
helps MongoDB keep the same identity and storage every time.

**Alternative considered:**  
Deployment  
**Why not chosen:**  
A Deployment does not guarantee stable storage and identity, which is risky for
databases.

---

### 2. Persistent Volume Claim (PVC) for MongoDB
**Why chosen:**  
To make sure MongoDB data is not lost when the pod restarts or crashes.

**Alternative considered:**  
Using container storage only  
**Why not chosen:**  
Data would be lost if the pod is deleted or restarted.

---

### 3. MongoDB Service as ClusterIP
**Why chosen:**  
MongoDB should only be accessed inside the Kubernetes cluster for security.

**Alternative considered:**  
NodePort or LoadBalancer  
**Why not chosen:**  
They would expose the database to the outside world, which is unsafe.

---

### 4. Flask Application as a Deployment
**Why chosen:**  
Flask is stateless and can run multiple copies at the same time easily.

**Alternative considered:**  
StatefulSet  
**Why not chosen:**  
Flask does not need fixed identity or storage, so StatefulSet is unnecessary.

---

### 5. NodePort Service for Flask
**Why chosen:**  
It allows easy access to the Flask app from a local machine when using Minikube.

**Alternative considered:**  
Ingress  
**Why not chosen:**  
Ingress is more complex and not required for a local test setup.

---

### 6. CPU-Based Autoscaling (HPA)
**Why chosen:**  
CPU usage is easy to measure and works well for web applications.

**Alternative considered:**  
Memory-based autoscaling  
**Why not chosen:**  
Memory usage does not always mean high traffic, so it is less reliable.

---

### 7. Resource Requests and Limits
**Why chosen:**  
To make sure each app gets enough resources and does not use too much.

**Alternative considered:**  
No limits  
**Why not chosen:**  
One app could use all resources and crash the system.


# 6. Cookie Point: Testing Scenarios (In Simple Language)

### 1. Testing Database Interaction
To test MongoDB connectivity, the Flask application endpoints were used.

**Steps performed:**
- Sent a POST request to insert data into MongoDB
- Sent a GET request to retrieve the stored data
- Restarted Flask pods to verify data persistence

**Result:**
- Data was inserted and retrieved successfully
- Data remained available even after pod restarts
- No MongoDB connection errors were found in application logs

---

### 2. Testing Autoscaling (HPA)

#### Simulating High Traffic
High traffic was simulated using a load generator pod that continuously sent
requests to the Flask application.

**Steps performed:**
- Deployed a load generator pod
- Generated continuous requests to the `/data` endpoint
- Monitored CPU usage and pod count using Kubernetes commands

**Commands used:**
```bash
kubectl get hpa
kubectl get pods -w

```

Here are the final sections for your project documentation, formatted to highlight the successful testing and conclusions of your deployment.

---

## 3. Autoscaling Results

The **Horizontal Pod Autoscaler (HPA)** was monitored during a high-traffic simulation using the `load-generator` pod. The following scaling behavior was observed:

### Observed Behavior:

* **Initial State:** The deployment started with **2 replicas** (as defined in the HPA `minReplicas`).
* **Scale-Up:** Once the load generator increased CPU usage beyond the **70% threshold**, the HPA automatically scaled the pods from **2 → 4 → 5**.
* **Maximum Capacity:** The system capped at **5 replicas** (as defined in `maxReplicas`), maintaining application stability.
* **Scale-Down:** After stopping the load generator, the pods scaled down back toward the minimum baseline.

**Result:** The autoscaling mechanism worked correctly, ensuring high availability during traffic spikes and resource efficiency during idle periods.

---

## 4. Issues Encountered & Resolutions

| Issue | Description | Resolution |
| --- | --- | --- |
| **Delayed Scale-Down** | The HPA did not scale down immediately after traffic stopped. | This is expected behavior due to the Kubernetes **stabilization window** (default 5 minutes), which prevents "flapping." |
| **Metrics Delay** | `kubectl get hpa` showed `<unknown>` metrics for the first 60 seconds. | Waited for the **Metrics Server** to collect sufficient data points from the newly created pods. |
| **NodePort Access** | Difficulty accessing the service via the cluster IP from the host machine. | Used `minikube ip` to identify the correct gateway address for the NodePort. |

---

## 5. Project Conclusion

The testing phase successfully confirmed the following technical milestones:

1. **Database Integrity:** Flask-to-MongoDB interactions (GET/POST) function correctly with root authentication.
2. **Stateful Persistence:** MongoDB data remains intact even after manual pod deletions, thanks to the **Persistent Volume Claim**.
3. **Elasticity:** The system dynamically adjusts its resource footprint based on real-time CPU utilization.
4. **Resilience:** The application remained available and responsive throughout the scaling and recovery processes.

The architecture is now fully validated for a containerized, scalable production environment.

.



---
---




**Udit Bhardwaj**
