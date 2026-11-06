# ShopEase: automated deployment pipeline for an online shopping application

Mini project: **GitHub + Gradle + Jenkins + Ansible + Azure DevOps**.
A small Spring Boot shop is built, tested and deployed to Azure VMs automatically on every push.

```
Developer ──push──▶ GitHub ──webhook──▶ Jenkins VM
                                         │ 1 checkout
                                         │ 2 gradle build
                                         │ 3 gradle test (+ JaCoCo report)
                                         │ 4 archive shopease.jar
                                         │ 5 [approval if production]
                                         ▼ 6 ansible-playbook over SSH
                      Azure VM (staging / production)
                        /opt/shopease/releases/<build>/shopease.jar
                        /opt/shopease/current ──▶ newest release
                        systemd service "shopease" ─▶ health check
                        health check fails ─▶ automatic rollback

Azure DevOps: Boards (backlog and sprint) + azure-pipelines.yml (build/test on every push and PR)
```

## What is in this repo

| Path | Purpose |
|---|---|
| `src/main` | Spring Boot shop: products, in-memory carts, checkout, orders, simple web page |
| `src/test` | 15 tests: Mockito unit tests, MVC slice tests, JPA test, context test |
| `build.gradle` | Gradle build, JaCoCo coverage, versioning from Jenkins `BUILD_NUMBER`, fixed jar name |
| `Jenkinsfile` | The CI/CD pipeline |
| `ansible/` | Inventory, playbook and systemd template (release folders + rollback) |
| `azure-pipelines.yml` | Azure Pipelines build/test pipeline |
| `docs/` | Setup guide, demo script, backlog, decision records |

## 1. First step: generate the Gradle wrapper

The wrapper files are binary/generated, so they are not in this starter. Do this once:

```bash
# Option A: you have Gradle installed
gradle wrapper --gradle-version 8.14

# Option B: no Gradle. Create any Gradle (Groovy) project at https://start.spring.io,
# copy its gradlew, gradlew.bat and gradle/ folder into this repo.
```

Commit `gradlew`, `gradlew.bat` and `gradle/wrapper/*`.

## 2. Run locally

Needs JDK 17+.

```bash
./gradlew test          # 15 tests; report in build/reports/tests/test/index.html
./gradlew bootRun       # http://localhost:8080
```

Useful URLs: `/` (shop page), `/api/products`, `/actuator/health`, `/actuator/info` (shows the version).

## API

| Method and path | What it does |
|---|---|
| `GET /api/products` | List products |
| `GET /api/products/{id}` | One product (404 if missing) |
| `POST /api/products` | Create (validated, 400 on bad data) |
| `GET /api/carts/{cartId}` | View a cart |
| `POST /api/carts/{cartId}/items` | `{"productId":1,"quantity":2}` |
| `POST /api/carts/{cartId}/checkout` | `{"customerName":"Asha"}`: reduces stock, creates the order |

## 3. Build the pipeline

Follow `docs/SETUP.md`, or run the exact CMD commands in `docs/COMMANDS.md`.
Then rehearse with `docs/DEMO-SCRIPT.md`.

## Honest status of this starter

Written carefully but **not run yet**: the author's environment had no Gradle, Ansible, Jenkins or network access.
YAML files parse. Expect small first-run fixes (a version number, a plugin, a firewall rule).
Run `./gradlew test` first; it will tell you quickly whether the app part is healthy.

## Ideas for extra marks (pick two or three)

- SonarQube analysis stage in Jenkins
- Docker image stage (build, then run the container with Ansible)
- Email or Slack notification on failure
- Switch H2 to MySQL/PostgreSQL provisioned by an Ansible role
- Basic login with Spring Security
- Smoke-test stage that calls `/api/products` after deploy
