pipeline {
  agent any

  environment {
    AWS_REGION   = "eu-central-1"
    ECR_REPO     = "051826742726.dkr.ecr.eu-central-1.amazonaws.com/fintech-dev-api"
    CLUSTER_NAME = "fintech-dev-cluster"
    SERVICE_NAME = "fintech-dev-svc"
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {
    stage("Checkout") {
      steps { checkout scm }
    }

    stage("Build Docker image") {
      steps {
        sh '''
          set -e
          docker --version
          docker build -t fintech-dev-api:${BUILD_NUMBER} ./app
        '''
      }
    }

    stage("Login to ECR") {
      steps {
        sh '''
          set -e
          aws --version
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$ECR_REPO"
        '''
      }
    }

    stage("Push to ECR") {
      steps {
        sh '''
          set -e
          docker tag fintech-dev-api:${BUILD_NUMBER} ${ECR_REPO}:${BUILD_NUMBER}
          docker tag fintech-dev-api:${BUILD_NUMBER} ${ECR_REPO}:latest
          docker push ${ECR_REPO}:${BUILD_NUMBER}
          docker push ${ECR_REPO}:latest
        '''
      }
    }

    stage("Deploy to ECS (force new deploy)") {
      steps {
        sh '''
          set -e
          aws ecs update-service \
            --cluster "$CLUSTER_NAME" \
            --service "$SERVICE_NAME" \
            --force-new-deployment \
            --region "$AWS_REGION"
        '''
      }
    }

    stage("Smoke test") {
      steps {
        sh '''
          set -e
          echo "Hit your public endpoint (ALB/Domain) from Jenkins if reachable."
          echo "If Jenkins is private, run this test from your laptop instead."
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