# Deploying to AWS ECR + ECS Fargate

This guide takes the Docker image built from this project and runs it on
AWS Fargate. Fargate removes the need to manage EC2 instances: AWS runs the
container and bills only for the CPU and memory the task requests.

## Architecture

```text
Docker image --> Amazon ECR --> ECS Fargate task --> CloudWatch Logs
                                                        |
                                              Application Load Balancer (optional)
```

- **Amazon ECR** stores the container image.
- **ECS cluster** is a logical grouping for the tasks.
- **Task definition** describes how to run the container (CPU, memory, port).
- **Fargate service** keeps the desired number of tasks running.
- **Application Load Balancer** routes external traffic to the task (optional).

## Prerequisites

- Docker installed and running
- AWS CLI installed and configured (`aws configure`)
- IAM permissions for: ECR, ECS, IAM, EC2 (for networking), CloudWatch Logs

## 1. Create the IAM execution role

Fargate needs a role to pull the image from ECR and write logs to CloudWatch.

```bash
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://aws/ecs-trust-policy.json

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

## 2. Build, push, and register

The included script automates image build, ECR push, cluster creation, and
task definition registration. Run it from the project root.

```bash
export AWS_REGION=eu-central-1
export ECR_REPOSITORY=docker-node-learning-app
bash aws/deploy.sh
```

You can also run the AWS CLI commands from the script manually if you are on
PowerShell or prefer step-by-step control.

## 3. Create a Fargate service

The service needs subnet and security group IDs from your VPC.

```bash
aws ecs create-service \
  --cluster docker-node-learning-cluster \
  --service-name docker-node-learning-service \
  --task-definition docker-node-learning-app \
  --launch-type FARGATE \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-11111111,subnet-22222222],securityGroups=[sg-33333333],assignPublicIp=ENABLED}" \
  --region eu-central-1
```

- `subnets`: at least one public subnet if you enable a public IP, otherwise
  private subnets with a NAT gateway.
- `securityGroups`: allow TCP port 3000 from your ALB or test source.
- `assignPublicIp=ENABLED`: only for direct testing; disable it when using an ALB.

## 4. Test the running task

With `assignPublicIp=ENABLED`, find the task's public IP:

```bash
aws ecs list-tasks --cluster docker-node-learning-cluster --region eu-central-1
aws ecs describe-tasks --cluster docker-node-learning-cluster --tasks <task-id> --region eu-central-1
```

Then:

```bash
curl http://<public-ip>:3000/health
```

Expected response:

```json
{"status":"ok","uptime":1.23}
```

## 5. Optional: add an Application Load Balancer

For a production-like setup, create an ALB with a target group (target type
`ip`, port 3000, health check path `/health`), then pass the target group and
container name to `create-service`:

```bash
aws ecs create-service \
  --cluster docker-node-learning-cluster \
  --service-name docker-node-learning-service \
  --task-definition docker-node-learning-app \
  --launch-type FARGATE \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-11111111],securityGroups=[sg-33333333],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=<target-group-arn>,containerName=app,containerPort=3000" \
  --region eu-central-1
```

## 6. View logs

The task definition writes to CloudWatch Logs under
`/ecs/docker-node-learning-app`.

```bash
aws logs tail /ecs/docker-node-learning-app --region eu-central-1 --follow
```

## Cleanup

```bash
aws ecs delete-service --cluster docker-node-learning-cluster --service docker-node-learning-service --force
aws ecs delete-cluster --cluster docker-node-learning-cluster
aws ecr delete-repository --repository-name docker-node-learning-app --force
```
