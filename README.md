# Docker + Node + AWS Learning App

A small Express API used to learn how to containerize a Node.js application
and deploy it to AWS ECS Fargate through Amazon ECR.

## What it does

| Method | Path      | Description                     |
| ------ | --------- | ------------------------------- |
| GET    | `/`       | App info and available routes   |
| GET    | `/health` | Health check used by Docker/ECS |
| GET    | `/items`  | List in-memory items            |
| POST   | `/items`  | Add an item (`{"name":"..."}`)  |

## Run locally

```bash
npm install
npm start
```

Then open <http://localhost:3000/health>.

## Docker basics

Build the image:

```bash
docker build -t docker-node-learning-app .
```

Run a container:

```bash
docker run -p 3000:3000 --rm docker-node-learning-app
```

Run with Compose:

```bash
docker compose up --build
```

## Project structure

```text
.
├── Dockerfile                         # multi-stage image definition
├── docker-compose.yml                 # local container run config
├── .dockerignore                      # files excluded from the build context
├── server.js                          # Express API
├── aws/
│   ├── ecs-fargate-task-definition.json
│   ├── ecs-trust-policy.json
│   └── deploy.sh                      # build, push to ECR, register task
└── docs/
    └── aws-deployment.md              # full ECR + ECS Fargate guide
```

## Key Docker concepts covered

- **Image vs container**: an image is the immutable blueprint; a container is a
  running instance of that image.
- **Dockerfile layers**: each `RUN`, `COPY`, and `ADD` creates a layer. Layers
  are cached, so unchanged steps are reused on rebuild.
- **Multi-stage build**: the first stage installs dependencies, and the second
  copies only the runtime artifacts, producing a smaller final image.
- **`.dockerignore`**: keeps the build context small and prevents local
  `node_modules`, `.git`, and docs from entering the image.
- **Healthcheck**: Docker polls `/health` to report container health; ECS and
  load balancers use the same idea for target health.

## AWS deployment

See [docs/aws-deployment.md](docs/aws-deployment.md) for the full ECR + ECS
Fargate walkthrough, including IAM roles, networking, logs, load balancer, and
cleanup.
