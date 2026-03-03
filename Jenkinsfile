pipeline {
  agent { label 'fintech-agent' }

  environment {
    AWS_REGION   = "eu-central-1"
    ACCOUNT_ID   = "051826742726"
    ECR_REPO     = "fintech-dev-api"
    ECR_URI      = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

    ECS_CLUSTER  = "fintech-dev-cluster"
    ECS_SERVICE  = "fintech-dev-svc"

    TASK_FAMILY  = "fintech-dev-task"
    CONTAINER_NAME = "app"
  }

  options { timestamps() }

  triggers { githubPush() }

  stages {
    stage("Checkout") {
      steps { checkout scm }
    }

    stage("Build Docker image") {
      steps {
        sh '''
          set -euo pipefail
          docker --version
          GIT_SHA=$(git rev-parse --short=8 HEAD)
          IMAGE_TAG="b${BUILD_NUMBER}-${GIT_SHA}"
          echo "${IMAGE_TAG}" > .image_tag
          docker build -t ${ECR_REPO}:${IMAGE_TAG} ./app
        '''
      }
    }

    stage("Login to ECR") {
      steps {
        sh '''
          set -euo pipefail
          aws --version
          aws ecr get-login-password --region ${AWS_REGION} \
            | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
        '''
      }
    }

    stage("Push to ECR") {
      steps {
        sh '''
          set -euo pipefail
          IMAGE_TAG=$(cat .image_tag)
          docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
          docker push ${ECR_URI}:${IMAGE_TAG}

          # optional convenience tag
          docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:latest
          docker push ${ECR_URI}:latest
        '''
      }
    }

    stage("Register new Task Definition revision") {
      steps {
        sh '''
          set -euo pipefail
          IMAGE_TAG=$(cat .image_tag)
          export NEW_IMAGE="${ECR_URI}:${IMAGE_TAG}"
          export CONTAINER_NAME="${CONTAINER_NAME}"
          echo "New image: ${NEW_IMAGE}"

          aws ecs describe-task-definition \
            --task-definition ${TASK_FAMILY} \
            --region ${AWS_REGION} \
            --query taskDefinition \
            --output json > taskdef.json

          PYBIN=$(command -v python3 || command -v python)

          ${PYBIN} - <<'PY'
import json, os

container_name = os.environ["CONTAINER_NAME"]
new_image      = os.environ["NEW_IMAGE"]

td = json.load(open("taskdef.json"))

for k in ["taskDefinitionArn","revision","status","requiresAttributes","compatibilities","registeredAt","registeredBy"]:
    td.pop(k, None)

found = False
for c in td.get("containerDefinitions", []):
    if c.get("name") == container_name:
        c["image"] = new_image
        found = True
        break

if not found:
    raise SystemExit(f"ERROR: container name '{container_name}' not found in task definition")

json.dump(td, open("taskdef.register.json","w"))
print("Wrote taskdef.register.json with updated image:", new_image)
PY

          NEW_TASKDEF_ARN=$(aws ecs register-task-definition \
            --region ${AWS_REGION} \
            --cli-input-json file://taskdef.register.json \
            --query "taskDefinition.taskDefinitionArn" \
            --output text)

          echo "New task definition: ${NEW_TASKDEF_ARN}"
          echo "${NEW_TASKDEF_ARN}" > .new_taskdef_arn
        '''
      }
    }

    stage("Deploy (update ECS service)") {
      steps {
        sh '''
          set -euo pipefail
          NEW_TASKDEF_ARN=$(cat .new_taskdef_arn)

          aws ecs update-service \
            --cluster ${ECS_CLUSTER} \
            --service ${ECS_SERVICE} \
            --task-definition "${NEW_TASKDEF_ARN}" \
            --region ${AWS_REGION}

          aws ecs wait services-stable \
            --cluster ${ECS_CLUSTER} \
            --services ${ECS_SERVICE} \
            --region ${AWS_REGION}
        '''
      }
    }

    stage("Smoke test (ALB)") {
      steps {
        sh '''
          set -euo pipefail
          ALB_DNS="fintech-dev-alb-1109785864.eu-central-1.elb.amazonaws.com"
          echo "Hitting: http://${ALB_DNS}/"
          curl -sS -o /tmp/out.html -w "HTTP=%{http_code}\n" "http://${ALB_DNS}/"
          head -n 20 /tmp/out.html
        '''
      }
    }
  }

  post {
    always {
      sh 'docker image prune -af || true'
    }
  }
}