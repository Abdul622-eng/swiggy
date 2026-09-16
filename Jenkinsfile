pipeline {

    agent any

    parameters {

        choice(
            name: 'IMAGE_TAG',
            choices: ['1.0', '1.1', '1.2'],
            description: 'ECR image version'
        )

        choice(
            name: 'ENVIRONMENT',
            choices: ['DEV', 'QA', 'PROD'],
            description: 'Deployment environment'
        )
    }

    environment {

        AWS_REGION = 'eu-north-1'

        ECR_REPOSITORY = 'devops-demo-app'

        DEV_HOST  = 'DEV_PUBLIC_IP'
        QA_HOST   = 'QA_PUBLIC_IP'
        PROD_HOST = 'PROD_PUBLIC_IP'

        SSH_CREDENTIAL_ID = 'ec2-ssh-key'

        CONTAINER_NAME = 'devops-demo-app'

        CONTAINER_PORT = '2000'

        HOST_PORT = '2000'
    }

    stages {

        stage('Checkout') {

            steps {

                echo "Checking out Swiggy application"

                git(
                    branch: 'main',
                    url: 'https://github.com/Satoo36/swiggy.git'
                )
            }
        }

        stage('Get AWS Account') {

            steps {

                script {

                    env.AWS_ACCOUNT_ID = sh(
                        script: '''
                            aws sts get-caller-identity \
                            --query Account \
                            --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY =
                        "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    env.ECR_IMAGE =
                        "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

                    echo "AWS Account: ${AWS_ACCOUNT_ID}"
                    echo "ECR Registry: ${ECR_REGISTRY}"
                    echo "ECR Image: ${ECR_IMAGE}"
                }
            }
        }

        stage('Check ECR Repository') {

            steps {

                sh '''
                    aws ecr describe-repositories \
                    --repository-names ${ECR_REPOSITORY} \
                    --region ${AWS_REGION}
                '''
            }
        }

        stage('ECR Login') {

            steps {

                sh '''
                    aws ecr get-login-password \
                    --region ${AWS_REGION} | \
                    docker login \
                    --username AWS \
                    --password-stdin \
                    ${ECR_REGISTRY}
                '''
            }
        }

        /*
         * BUILD ONLY FOR DEV
         */
        stage('Docker Build') {

            when {

                expression {
                    params.ENVIRONMENT == 'DEV'
                }
            }

            steps {

                echo "Building ${ECR_IMAGE}"

                sh '''
                    docker build \
                    -t ${ECR_IMAGE} \
                    .
                '''

                echo "Docker build completed"
            }
        }

        /*
         * TEST ONLY FOR DEV
         */
        stage('Docker Image Test') {

            when {

                expression {
                    params.ENVIRONMENT == 'DEV'
                }
            }

            steps {

                sh '''
                    docker image inspect ${ECR_IMAGE}
                '''

                echo "Docker image test successful"
            }
        }

        /*
         * PUSH ONLY FOR DEV
         */
        stage('Push to ECR') {

            when {

                expression {
                    params.ENVIRONMENT == 'DEV'
                }
            }

            steps {

                echo "Pushing ${ECR_IMAGE} to ECR"

                sh '''
                    docker push ${ECR_IMAGE}
                '''

                echo "Image pushed successfully"
            }
        }

        /*
         * QA AND PROD USE EXISTING IMAGE
         *
         * NO BUILD
         * NO PUSH
         */
        stage('Select Existing Image') {

            when {

                expression {
                    params.ENVIRONMENT != 'DEV'
                }
            }

            steps {

                echo "Using existing ECR image"
                echo "IMAGE_TAG = ${IMAGE_TAG}"
                echo "ENVIRONMENT = ${ENVIRONMENT}"

                sh '''
                    aws ecr describe-images \
                    --repository-name ${ECR_REPOSITORY} \
                    --image-ids imageTag=${IMAGE_TAG} \
                    --region ${AWS_REGION}
                '''
            }
        }

        /*
         * GET DIGEST
         */
        stage('Get ECR Digest') {

            steps {

                script {

                    env.ECR_DIGEST = sh(
                        script: '''
                            aws ecr describe-images \
                            --repository-name ${ECR_REPOSITORY} \
                            --image-ids imageTag=${IMAGE_TAG} \
                            --region ${AWS_REGION} \
                            --query 'imageDetails[0].imageDigest' \
                            --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "ECR IMAGE DIGEST:"
                    echo "${ECR_DIGEST}"
                }
            }
        }

        /*
         * SELECT DEV / QA / PROD
         */
        stage('Select Environment') {

            steps {

                script {

                    switch(params.ENVIRONMENT) {

                        case 'DEV':
                            env.TARGET_HOST = env.DEV_HOST
                            break

                        case 'QA':
                            env.TARGET_HOST = env.QA_HOST
                            break

                        case 'PROD':
                            env.TARGET_HOST = env.PROD_HOST
                            break

                        default:
                            error("Invalid environment")
                    }

                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Target server: ${env.TARGET_HOST}"
                }
            }
        }

        /*
         * DEPLOY EXISTING ECR IMAGE
         */
        stage('Deploy') {

            steps {

                script {

                    sshagent(
                        credentials: [env.SSH_CREDENTIAL_ID]
                    ) {

                        sh """

                            ssh -o StrictHostKeyChecking=no \
                            ubuntu@${TARGET_HOST} '

                                set -e

                                echo "================================="
                                echo "Environment: ${ENVIRONMENT}"
                                echo "Image: ${ECR_IMAGE}"
                                echo "================================="

                                echo "Checking IAM Role..."

                                aws sts get-caller-identity

                                echo "Logging into ECR..."

                                AWS_ACCOUNT_ID=\\\$(aws sts get-caller-identity \
                                --query Account \
                                --output text)

                                aws ecr get-login-password \
                                --region ${AWS_REGION} | \
                                docker login \
                                --username AWS \
                                --password-stdin \
                                \\\${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                                echo "Pulling ECR image..."

                                docker pull ${ECR_IMAGE}

                                echo "Stopping old container..."

                                docker rm -f ${CONTAINER_NAME} \
                                2>/dev/null || true

                                echo "Starting new container..."

                                docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${HOST_PORT}:${CONTAINER_PORT} \
                                ${ECR_IMAGE}

                                echo "Container started"

                                docker ps

                            '
                        """
                    }
                }
            }
        }

        /*
         * VERIFY SAME DIGEST
         */
        stage('Verify Image Digest') {

            steps {

                script {

                    sshagent(
                        credentials: [env.SSH_CREDENTIAL_ID]
                    ) {

                        def deployedDigest = sh(
                            script: """

                                ssh -o StrictHostKeyChecking=no \
                                ubuntu@${TARGET_HOST} '

                                    docker inspect \
                                    --format="{{index .RepoDigests 0}}" \
                                    ${CONTAINER_NAME}

                                '

                            """,
                            returnStdout: true
                        ).trim()

                        echo "================================="
                        echo "ECR DIGEST:"
                        echo "${ECR_DIGEST}"
                        echo "================================="

                        echo "DEPLOYED IMAGE:"
                        echo "${deployedDigest}"
                        echo "================================="

                        if (!deployedDigest.contains(ECR_DIGEST)) {

                            error(
                                "DIGEST MISMATCH! Deployment failed verification."
                            )
                        }

                        echo "DIGEST VERIFIED"
                        echo "Same ECR image is deployed."
                    }
                }
            }
        }

        /*
         * APPLICATION HEALTH CHECK
         */
        stage('Health Check') {

            steps {

                script {

                    sshagent(
                        credentials: [env.SSH_CREDENTIAL_ID]
                    ) {

                        sh """

                            ssh -o StrictHostKeyChecking=no \
                            ubuntu@${TARGET_HOST} '

                                echo "Testing application..."

                                curl -f \
                                http://localhost:${HOST_PORT}

                                echo ""

                                echo "Application is UP"

                            '

                        """
                    }
                }
            }
        }
    }

    post {

        success {

            echo "======================================"

            echo "PIPELINE SUCCESS"

            echo "IMAGE TAG  : ${IMAGE_TAG}"

            echo "ENVIRONMENT: ${ENVIRONMENT}"

            echo "ECR DIGEST : ${ECR_DIGEST}"

            echo "======================================"
        }

        failure {

            echo "======================================"

            echo "PIPELINE FAILED"

            echo "IMAGE TAG  : ${IMAGE_TAG}"

            echo "ENVIRONMENT: ${ENVIRONMENT}"

            echo "======================================"
        }
    }
}
