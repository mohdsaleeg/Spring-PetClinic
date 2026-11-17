# Spring PetClinic: DevOps CI/CD Pipeline

A DevOps project that wraps the open-source [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application in an automated build, test, code quality and security pipeline.

The application code is unchanged. The project is everything that happens between a `git push` and a verified build.

## Before and after

| Task | Before (manual baseline) | Now (automated) |
|---|---|---|
| Build and test | Run `./mvnw package` by hand | Jenkins runs it on every push |
| Test reporting | Read terminal output | JUnit results shown in Jenkins |
| Code quality | None | SonarQube analysis and quality gate |
| Test coverage | Not measured | JaCoCo report, 90.8% in SonarQube |
| Dependency security | None | Trivy scan, fails the build on CRITICAL findings |
| Build output | Loose `.jar` on a laptop | `.jar` archived by Jenkins for every build |

## Pipeline flow

```
Developer -> GitHub -> Jenkins (polls for new commits)
                          |
                          +-> Maven build + JUnit tests (JaCoCo coverage)
                          +-> SonarQube analysis -> Quality Gate
                          +-> Trivy dependency scan
                          +-> Archive .jar
```

## Tools and status

| Tool | Purpose | Status |
|---|---|---|
| Git / GitHub | Source control | Done |
| Maven + JUnit | Build and tests | Done |
| Jenkins | CI server | Done |
| JaCoCo | Code coverage | Done |
| SonarQube | Code quality and quality gate | Done |
| Trivy | Dependency vulnerability scan | Done |
| Docker, Docker Hub | Container image and registry | Done |
| Kubernetes, ArgoCD | Deployment (GitOps) | Planned |
| PostgreSQL | Persistent database | Planned |
| Prometheus, Grafana | Monitoring | Planned |
| Terraform, Ansible | Infrastructure as code | Planned |

## Pipeline stages

| Stage | What it does |
|---|---|
| Checkout | Pulls the latest code from GitHub |
| Build & Test | `./mvnw clean package` compiles, runs JUnit tests and builds the `.jar` |
| SonarQube Analysis | Sends code and coverage data to SonarQube |
| SonarQube Quality Gate | Stops the pipeline if the quality gate fails |
| Dependency Scan (Trivy) | Scans libraries for known vulnerabilities and fails on CRITICAL |
| Archive | Saves the `.jar` as a Jenkins build artifact |

## Results

**Jenkins pipeline**

![Jenkins stage view](docs/images/jenkins-stage-view.png)

**SonarQube dashboard.** The quality gate passed with 90.8% test coverage and 0.0% duplication.

![SonarQube dashboard](docs/images/sonarqube-dashboard.png)

**SonarQube to Jenkins webhook**

![SonarQube webhook](docs/images/sonarqube-webhook.png)

**Trivy dependency scan**

![Trivy report](docs/images/trivy-report.png)

## Repository layout

```
.
├── src/, pom.xml     Application code and Maven build
├── Jenkinsfile       Pipeline definition
└── docs/images/      Screenshots used in this README
```

## How to run it locally

Requirements: Docker Desktop, Java 17+, Git.

```bash
# Shared network so Jenkins and SonarQube can reach each other by name
docker network create devops

# Jenkins on http://localhost:8081
docker run -d --name jenkins --network devops \
  -p 8081:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# SonarQube on http://localhost:9000
docker run -d --name sonarqube --network devops -p 9000:9000 \
  -e SONAR_VALIDATEWEBHOOKS=false \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:community

# Trivy inside the Jenkins container
docker exec -u root jenkins bash -c "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
```

Then in Jenkins:

1. Install the **SonarQube Scanner** plugin.
2. Add a Secret text credential `sonar-token` containing a SonarQube user token.
3. Add a SonarQube server named `sonarqube` with URL `http://sonarqube:9000`.
4. Create a Pipeline job from SCM that uses the `Jenkinsfile` in this repo.

In SonarQube, add a webhook to `http://jenkins:8080/sonarqube-webhook/`.

## Design decisions

| Decision | Reason |
|---|---|
| Jenkins on port 8081 | PetClinic and Jenkins both default to 8080 |
| `pollSCM` instead of a GitHub webhook | GitHub cannot reach `localhost`, so Jenkins checks for new commits every 2 minutes |
| Trivy for dependency scanning | Needs no API key, and it can also scan container images later |
| Fail only on CRITICAL findings | Keeps the pipeline meaningful without constant failures from minor issues |
| Pipeline defined as code | The `Jenkinsfile` lives in the repo, so the pipeline is versioned and reproducible |

## Challenges and fixes

| Problem | Cause | Fix |
|---|---|---|
| Port 8080 clash | PetClinic and Jenkins both default to 8080 | Mapped Jenkins to port 8081 |
| GitHub cannot trigger a local Jenkins | A webhook cannot reach `localhost` | Used `pollSCM` |
| OWASP Dependency-Check blocked | The NVD API key could not be generated | Used Trivy for dependency scanning, which needs no key |
| Quality Gate stage timed out | The SonarQube webhook showed "Server Unreachable" because it blocks private Docker addresses | Recreated SonarQube with `SONAR_VALIDATEWEBHOOKS=false` |
| `PostgresIntegrationTests` failed locally | The test starts a database through Docker Compose, which was removed from the baseline | Excluded it with `-Dtest='!PostgresIntegrationTests'` until a real database is added |
Jenkins checkout failed with “not in a git directory”. Cause: the container was recreated as root, so Git rejected the workspace owned by another user. Fix: deleted the stale workspace and set safe.directory.

## Roadmap

1. Docker image, Docker Hub and a Trivy image scan
2. Kubernetes with PostgreSQL and ArgoCD GitOps deployment
3. Prometheus, Grafana and Slack alerts
4. Terraform and Ansible to provision the infrastructure on Azure
5. Re-enable the database integration tests once PostgreSQL is part of the pipeline

---

# About the application

# Spring PetClinic

Spring PetClinic is a sample Spring Boot application for managing a veterinary clinic.

## Technologies Used

- Java 17+
- Spring Boot
- Maven
- Spring Data JPA
- H2 Database
- Git and GitHub

## Project Structure

```text
spring-petclinic/
├── .mvn/
├── src/
│   ├── main/
│   └── test/
├── pom.xml
├── mvnw
├── mvnw.cmd
└── README.md
```

## Run the Application

Make sure Java 17 or newer is installed.

Run the following command:

```bash
./mvnw spring-boot:run
```

On Windows PowerShell:

```powershell
.\mvnw.cmd spring-boot:run
```
Jenkins CI/CD integration successfully configured.
Open your browser:

http://localhost:8080

## Author

Testing Jenkins SCM polling trigger.
mohdsaleeg