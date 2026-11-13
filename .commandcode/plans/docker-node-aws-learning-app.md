# Docker + Node + AWS Learning App

## Goal
A sample Express API containerized with Docker and deployable to AWS
ECR + ECS Fargate, with learning documentation.

## Already scaffolded
- `package.json` — Express app, ESM, `start`/`dev` scripts
- `server.js` — routes: `/`, `/health`, `/items` (GET/POST)
- `.gitignore`, `.dockerignore`
- `Dockerfile` — multi-stage build, non-root user, healthcheck
- `docker-compose.yml`
- `aws/ecs-fargate-task-definition.json`
- `aws/ecs-trust-policy.json`
- `aws/deploy.sh` — build, push to ECR, register task definition
- `docs/aws-deployment.md` — full ECR + ECS Fargate guide
- `README.md` — local run, Docker concepts, AWS pointer

## Remaining work
1. Run `npm install` to generate `package-lock.json` and `node_modules`.
2. Verify the app boots and `/health` returns `{"status":"ok"}`.

## Verification
- `npm install`
- Start server, then `curl http://localhost:3000/health`
- Optional: `docker compose up --build` and hit `/health`
