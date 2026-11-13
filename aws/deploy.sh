#!/usr/bin/env bash
set -euo pipefail

# --- Configuration: override these via environment variables ---
AWS_REGION="${AWS_REGION:-eu-central-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-docker-node-learning-app}"
ECS_CLUSTER="${ECS_CLUSTER:-docker-node-learning-cluster}"
ECS_SERVICE="${ECS_SERVICE:-docker-node-learning-service}"
TASK_FAMILY="${TASK_FAMILY:-docker-node-learning-app}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DESIRED_COUNT="${DESIRED_COUNT:-1}"
SUBNETS="${SUBNETS:-subnet-0bbc29fcbfa162258}"
SECURITY_GROUPS="${SECURITY_GROUPS:-sg-0ad626e3b66f55aab}"
ASSIGN_PUBLIC_IP="${ASSIGN_PUBLIC_IP:-ENABLED}"

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_HOST="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_HOST}/${ECR_REPOSITORY}:${IMAGE_TAG}"

log()  { printf '\n==> %s\n' "$1"; }
fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

build_and_push_image() {
  log "Building Docker image (${IMAGE_TAG})"
  docker build -t "${ECR_REPOSITORY}:${IMAGE_TAG}" .

  log "Ensuring ECR repository exists (${ECR_REPOSITORY})"
  aws ecr describe-repositories \
    --repository-names "${ECR_REPOSITORY}" \
    --region "${AWS_REGION}" >/dev/null 2>&1 ||
    aws ecr create-repository \
      --repository-name "${ECR_REPOSITORY}" \
      --region "${AWS_REGION}" >/dev/null

  log "Authenticating Docker with ECR"
  aws ecr get-login-password --region "${AWS_REGION}" |
    docker login --username AWS --password-stdin "${ECR_HOST}"

  log "Pushing image to ${IMAGE_URI}"
  docker tag "${ECR_REPOSITORY}:${IMAGE_TAG}" "${IMAGE_URI}"
  docker push "${IMAGE_URI}"
}

register_task_definition() {
  log "Ensuring ECS cluster exists (${ECS_CLUSTER})"
  aws ecs create-cluster \
    --cluster-name "${ECS_CLUSTER}" \
    --region "${AWS_REGION}" >/dev/null

  log "Registering task definition (${TASK_FAMILY})"
  local task_definition_json
  task_definition_json="$(sed \
    -e "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|g" \
    -e "s|\${AWS_REGION}|${AWS_REGION}|g" \
    -e "s|\${ECR_REPOSITORY}|${ECR_REPOSITORY}|g" \
    -e "s|\${TASK_FAMILY}|${TASK_FAMILY}|g" \
    -e "s|\${IMAGE_TAG}|${IMAGE_TAG}|g" \
    aws/ecs-fargate-task-definition.json)"

  aws ecs register-task-definition \
    --cli-input-json "${task_definition_json}" \
    --region "${AWS_REGION}"
}

deploy_fargate_service() {
  if [[ -z "${SUBNETS}" || -z "${SECURITY_GROUPS}" ]]; then
    fail "SUBNETS and SECURITY_GROUPS are required (comma-separated). Example: SUBNETS=subnet-111 SECURITY_GROUPS=sg-222 bash aws/deploy.sh"
  fi

  local network_config="awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SECURITY_GROUPS}],assignPublicIp=${ASSIGN_PUBLIC_IP}}"

  if aws ecs describe-services \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}" \
    --region "${AWS_REGION}" \
    --query "length(services)" \
    --output text | grep -q '^1$'; then
    log "Updating Fargate service (${ECS_SERVICE})"
    aws ecs update-service \
      --cluster "${ECS_CLUSTER}" \
      --service "${ECS_SERVICE}" \
      --task-definition "${TASK_FAMILY}" \
      --desired-count "${DESIRED_COUNT}" \
      --network-configuration "${network_config}" \
      --region "${AWS_REGION}"
  else
    log "Creating Fargate service (${ECS_SERVICE})"
    aws ecs create-service \
      --cluster "${ECS_CLUSTER}" \
      --service-name "${ECS_SERVICE}" \
      --task-definition "${TASK_FAMILY}" \
      --launch-type FARGATE \
      --desired-count "${DESIRED_COUNT}" \
      --network-configuration "${network_config}" \
      --region "${AWS_REGION}"
  fi
}

build_and_push_image
register_task_definition
deploy_fargate_service

log "Deployment complete."
