# Spring PetClinic: DevOps CI/CD Pipeline

A DevOps project that wraps the open-source [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application in a complete automated pipeline: build, test, code quality, security scanning, containerization, GitOps deployment to Kubernetes with a persistent PostgreSQL database, and monitoring with alerting.

The application code is unchanged, apart from adding a metrics dependency. The project is everything between a `git push` and the new version running in the cluster, observed and alerting.

## Before and after

| Task | Before (manual baseline) | Now (automated) |
|---|---|---|
| Build and test | Run `./mvnw package` by hand | Jenkins runs it on every push |
| Code quality | None | SonarQube analysis and quality gate |
| Test coverage | Not measured | JaCoCo report, 90.8% in SonarQube |
| Dependency security | None | Trivy filesystem scan, fails on CRITICAL |
| Packaging | Loose `.jar` on a laptop | Docker image, scanned and versioned on Docker Hub |
| Deployment | `java -jar` by hand | ArgoCD syncs Kubernetes from Git |
| Database | In-memory H2, data lost on restart | PostgreSQL with a persistent volume |
| Monitoring | None | Prometheus metrics, Grafana dashboard |
| Failure detection | Notice it by hand | Alertmanager alert when PetClinic is down |

## Pipeline flow

```
Developer -> GitHub -> Jenkins (polls for new commits)
                          |
                          +-> Maven build + JUnit tests (JaCoCo coverage)
                          +-> SonarQube analysis -> Quality Gate
                          +-> Trivy dependency scan
                          +-> Archive .jar
                          +-> Docker build -> Trivy image scan
                          +-> Push image to Docker Hub (:BUILD_NUMBER, :latest)
                          +-> Commit new image tag to k8s/petclinic.yaml in Git
                                       |
                                    ArgoCD (watches Git)
                                       |
                                    Kubernetes (kind)
                                       +-> PetClinic Deployment
                                       +-> PostgreSQL StatefulSet + PersistentVolume
                                       +-> ServiceMonitor + PrometheusRule
                                       |
                    Prometheus -> Grafana dashboard
                         |
                    Alertmanager (PetClinicDown, PetClinicHighErrorRate)
```

Jenkins never runs `kubectl`. It only updates Git, and ArgoCD makes the cluster match Git. This is the GitOps model: every deployment is a Git commit, so history and rollback come for free.

## Tools and status

| Tool | Purpose | Status |
|---|---|---|
| Git / GitHub | Source control, single source of truth | Done |
| Maven + JUnit | Build and tests | Done |
| Jenkins | CI server | Done |
| JaCoCo | Code coverage | Done |
| SonarQube | Code quality and quality gate | Done |
| Trivy | Dependency and image vulnerability scans | Done |
| Docker + Docker Hub | Image build and registry | Done |
| Kubernetes (kind) | Runs the application | Done |
| PostgreSQL | Persistent database (StatefulSet + PVC) | Done |
| ArgoCD | GitOps continuous delivery | Done |
| Micrometer + Spring Boot Actuator | Expose application metrics | Done |
| Prometheus | Metrics collection and alert rules | Done |
| Grafana | Dashboards | Done |
| Alertmanager | Alert routing | Done |
| Terraform, Ansible | Infrastructure as code on Azure | Planned |

## Pipeline stages

| Stage | What it does |
|---|---|
| Checkout | Pulls the latest code from GitHub |
| Build & Test | `./mvnw clean package` compiles, runs JUnit tests and builds the `.jar` |
| SonarQube Analysis | Sends code and coverage data to SonarQube |
| SonarQube Quality Gate | Stops the pipeline if the quality gate fails |
| Dependency Scan (Trivy) | Scans libraries for known vulnerabilities, fails on CRITICAL |
| Archive | Saves the `.jar` as a build artifact |
| Docker Build | Packages the `.jar` into an image tagged with the build number and `latest` |
| Trivy Image Scan | Scans the image, fails on CRITICAL vulnerabilities that have a fix |
| Push to Docker Hub | Pushes both tags using stored credentials |
| Update Kubernetes Manifest | Writes the new image tag into `k8s/petclinic.yaml` and pushes to Git |

## Monitoring and alerting

PetClinic exposes metrics at `/actuator/prometheus` through Micrometer. Prometheus scrapes them through a `ServiceMonitor`, Grafana shows them on a dashboard, and `PrometheusRule` alerts are delivered to Alertmanager.

| Alert | Condition | Severity |
|---|---|---|
| `PetClinicDown` | No PetClinic target is up for 1 minute | critical |
| `PetClinicHighErrorRate` | More than 5% of requests return a 5xx error for 5 minutes | warning |

The monitoring stack is installed with the `kube-prometheus-stack` Helm chart, using resource limits tuned for a small local cluster (`monitoring/values.yaml`). The dashboard is exported to `monitoring/petclinic-dashboard.json`.

To prove the alert works, auto-sync was paused and the deployment scaled to zero. `PetClinicDown` moved from Pending to Firing and appeared in Alertmanager, and recovered after the app was restored.

## Results

**Jenkins pipeline (all stages)**

![Jenkins stage view](docs/images/jenkins-stage-view.png)

**SonarQube dashboard.** Quality gate passed, 90.8% coverage, 0.0% duplication.

![SonarQube dashboard](docs/images/sonarqube-dashboard.png)

**SonarQube to Jenkins webhook**

![SonarQube webhook](docs/images/sonarqube-webhook.png)

**Trivy dependency scan**

![Trivy report](docs/images/trivy-report.png)

**Trivy image scan**

![Trivy image report](docs/images/trivy-image-report.png)

**Image on Docker Hub**

![Docker Hub](docs/images/docker-hub.png)

**ArgoCD: application Synced and Healthy**

![ArgoCD](docs/images/argocd-synced.png)

**Kubernetes pods**

![Pods](docs/images/k8s-pods.png)

**Jenkins commits the new image tag to Git**

![GitOps commit](docs/images/github-jenkins-commit.png)

**Database persistence.** The data is still there after the PostgreSQL pod is deleted and recreated.

![Persistence](docs/images/postgres-persistence.png)

**Grafana dashboard: availability, JVM memory, CPU and HTTP requests**

![Grafana dashboard](docs/images/grafana-dashboard.png)

**Prometheus target: PetClinic is UP**

![Prometheus targets](docs/images/prometheus-targets.png)

**Alert test: PetClinicDown firing**

![Alert firing](docs/images/prometheus-alert-firing.png)

**Alertmanager receiving the alert**

![Alertmanager](docs/images/alertmanager-alerts.png)

## Repository layout

```
.
├── src/, pom.xml            Application code and Maven build
├── Jenkinsfile              Pipeline definition
├── Dockerfile               PetClinic image
├── .dockerignore
├── jenkins/Dockerfile       Custom Jenkins image with Docker CLI and Trivy
├── k8s/
│   ├── postgres.yaml        PostgreSQL StatefulSet, Service and volume claim
│   ├── petclinic.yaml       PetClinic Deployment and Service (image tag updated by Jenkins)
│   ├── servicemonitor.yaml  Tells Prometheus to scrape PetClinic
│   └── prometheusrule.yaml  Alert rules
├── argocd/application.yaml  ArgoCD application pointing at k8s/
├── monitoring/
│   ├── values.yaml          Helm values for the monitoring stack
│   └── petclinic-dashboard.json  Exported Grafana dashboard
└── docs/images/             Screenshots used in this README
```

## How to run it locally

Requirements: Docker Desktop (6 GB RAM or more, 16 GB total recommended), kubectl, Helm, kind, Java 17+, Git, a Docker Hub account and token, and a GitHub fine-grained token with Contents read and write on this repo.

**1. CI tools**

```bash
docker network create devops

docker build -t jenkins-devops ./jenkins
docker run -d --name jenkins --network devops --user root \
  -p 8081:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins-devops

docker run -d --name sonarqube --network devops -p 9000:9000 \
  -e SONAR_VALIDATEWEBHOOKS=false \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:community
```

In Jenkins: install the SonarQube Scanner plugin, add credentials `sonar-token` (secret text), `dockerhub-creds` and `github-creds` (username with password), add a SonarQube server named `sonarqube` at `http://sonarqube:9000`, and create a Pipeline job from SCM. Under the Git SCM section, add *Polling ignores commits in certain paths* with Excluded Regions `k8s/.*`. In SonarQube, add a webhook to `http://jenkins:8080/sonarqube-webhook/`.

**2. Kubernetes and ArgoCD**

```bash
kind create cluster --name devops
kubectl create namespace petclinic
kubectl create secret generic db-credentials -n petclinic \
  --from-literal=POSTGRES_USER=petclinic \
  --from-literal=POSTGRES_PASSWORD='<your-password>' \
  --from-literal=POSTGRES_DB=petclinic

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**3. Monitoring stack (install before ArgoCD syncs the ServiceMonitor and PrometheusRule)**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/values.yaml \
  --set grafana.adminPassword='<your-password>'

kubectl apply -f argocd/application.yaml
```

The database and Grafana passwords are supplied at install time and are never committed to Git.

Access the apps with port-forwards:

```bash
kubectl port-forward svc/argocd-server -n argocd 8083:443                                   # https://localhost:8083
kubectl port-forward -n petclinic svc/petclinic 8082:80                                     # http://localhost:8082
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80                           # http://localhost:3000
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090      # http://localhost:9090
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093   # http://localhost:9093
```

## Design decisions

| Decision | Reason |
|---|---|
| GitOps with ArgoCD | Jenkins only changes Git, and the cluster is never changed by hand, so every deployment is auditable and reversible |
| Polling excludes `k8s/.*` | Jenkins' own manifest commit must not trigger another build, which would loop forever |
| PostgreSQL as a StatefulSet with a PVC | The database keeps its data and identity when the pod is restarted or rescheduled |
| Secrets created outside Git | Passwords in a repository are effectively public |
| Readiness and liveness probes on `/actuator/health` | Kubernetes only sends traffic to healthy pods and restarts stuck ones |
| Trivy for dependency and image scans | No API key needed, and one tool covers both |
| Custom Jenkins image | Docker CLI and Trivy survive container recreation, and the setup is reproducible |
| `pollSCM` instead of a GitHub webhook | GitHub cannot reach `localhost` |
| Fail only on CRITICAL findings | Keeps the gate meaningful without constant failures from minor issues |
| Alerts defined as code in Git | Rules are reviewed, versioned and deployed by ArgoCD like the application |
| Alert expression ends in `or vector(0)` | A missing target produces no data, so without it the "down" alert can never fire |

## Challenges and fixes

| Problem | Cause | Fix |
|---|---|---|
| Port 8080 clash | PetClinic and Jenkins both default to 8080 | Mapped Jenkins to 8081 |
| GitHub cannot trigger a local Jenkins | A webhook cannot reach `localhost` | Used `pollSCM` |
| OWASP Dependency-Check blocked | The NVD API key could not be generated | Used Trivy for dependency scanning |
| Quality Gate stage timed out | SonarQube blocks webhooks to private Docker addresses, so the webhook showed "Server Unreachable" | Recreated SonarQube with `SONAR_VALIDATEWEBHOOKS=false` |
| `PostgresIntegrationTests` failed | The test starts a database through Docker Compose, which was removed from the baseline | Excluded the database integration tests with `-Dtest` (see roadmap) |
| Jenkins checkout failed with "not in a git directory" | The container was recreated as root, so Git rejected a workspace owned by another user | Deleted the stale workspace and set Git `safe.directory` |
| ArgoCD server showed `CreateContainerConfigError` right after install | It started before its secrets existed | Resolved itself after a retry |
| ArgoCD silently stopped syncing | An invalid character in `petclinic.yaml`, while Jenkins still reported success | Fixed the file, and now run `kubectl apply --dry-run=server` before pushing |
| "Service down" alert never fired | When no pods exist, the `up` metric disappears, and `sum()` of nothing is empty rather than 0 | Added `or vector(0)`, and verified by scaling the deployment to zero |
| Alertmanager pod never started | A 128Mi memory limit was lower than the operator's default request | Set an explicit request and a higher limit in `values.yaml` |
| ArgoCD stayed OutOfSync | The Prometheus operator's admission webhook rejected an invalid alert rule from Git, while the older rule in the cluster kept working | Found it in `operationState.message`, fixed the expression, and pushed |
| Scaling down for the alert test was undone immediately | ArgoCD self-heal restores the replica count | Paused auto-sync for the test and restored it afterward |
| `kubectl patch` failed with "invalid JSON patch" | PowerShell strips quotes from inline JSON | Passed the patch through a file with `--patch-file` |

## Roadmap

1. Terraform and Ansible to provision the infrastructure on Azure
2. Slack notifications from Alertmanager and Jenkins
3. Re-enable the PostgreSQL and MySQL integration tests, which need a database available to the Jenkins build
4. A manifest validation stage in the Jenkinsfile, so an invalid file fails the build instead of blocking ArgoCD

---

# About the Application