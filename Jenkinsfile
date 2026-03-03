pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    AWS_REGION   = "eu-central-1"
    CLUSTER_NAME = "fintech-dev-cluster"
    SERVICE_NAME = "fintech-dev-svc"
    ECR_REPO     = "051826742726.dkr.ecr.eu-central-1.amazonaws.com/fintech-dev-api"
    APP_DIR      = "app"
    SMOKE_URL    = "http://fintech-dev-alb-1109785864.eu-central-1.elb.amazonaws.com/"
  }

  stages {
    stage("Checkout") {
      steps { checkout scm }
    }

    stage("Compute image tag") {
      steps {
        script {
          def sha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.IMAGE_TAG = "v${env.BUILD_NUMBER}-${sha}"
          env.IMAGE_URI = "${env.ECR_REPO}:${env.IMAGE_TAG}"
          echo "IMAGE_URI=${env.IMAGE_URI}"
        }
      }
    }

    stage("Build Docker image") {
      steps {
        sh '''
          set -euo pipefail
          docker --version
          docker build -t "$IMAGE_URI" "./$APP_DIR"
        '''
      }
    }

    stage("Login to ECR") {
      steps {
        sh '''
          set -euo pipefail
          aws --version
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$(echo $ECR_REPO | cut -d/ -f1)"
        '''
      }
    }

    stage("Push to ECR") {
      steps {
        sh '''
          set -euo pipefail
          docker push "$IMAGE_URI"
        '''
      }
    }

    stage("Deploy to ECS (new task definition)") {
      steps {
        sh '''
          set -euo pipefail

          echo "Deploying: $IMAGE_URI"

          TD_ARN=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --region "$AWS_REGION" \
            --query "services[0].taskDefinition" \
            --output text)

          echo "Current TD: $TD_ARN"

          aws ecs describe-task-definition \
            --task-definition "$TD_ARN" \
            --region "$AWS_REGION" \
            --query "taskDefinition" \
            --output json > td.json

          python - <<'PY'
import json, os
with open("td.json") as f:
    td = json.load(f)

for k in ["taskDefinitionArn","revision","status","requiresAttributes","compatibilities","registeredAt","registeredBy"]:
    td.pop(k, None)

# Update container image (assumes first container is app)
td["containerDefinitions"][0]["image"] = os.environ["IMAGE_URI"]

with open("td-new.json","w") as f:
    json.dump(td, f)
PY

          NEW_TD_ARN=$(aws ecs register-task-definition \
            --cli-input-json file://td-new.json \
            --region "$AWS_REGION" \
            --query "taskDefinition.taskDefinitionArn" \
            --output text)

          echo "New TD: $NEW_TD_ARN"

          aws ecs update-service \
            --cluster "$CLUSTER_NAME" \
            --service "$SERVICE_NAME" \
            --task-definition "$NEW_TD_ARN" \
            --region "$AWS_REGION" >/dev/null

          aws ecs wait services-stable \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --region "$AWS_REGION"

          echo "ECS is stable."
        '''
      }
    }

    stage("Smoke test") {
      steps {
        sh '''
          set -euo pipefail
          echo "Testing: $SMOKE_URL"
          curl -fsS "$SMOKE_URL" | head -n 5 || true
          curl -fsSI "$SMOKE_URL" | head -n 20
          echo "Smoke test OK"
        '''
      }
    }
  }

  post {
    always {
      sh '''
        docker image prune -af || true
      '''
    }
  }
}