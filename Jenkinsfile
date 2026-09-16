pipeline {

    agent any

    /*
     * Do not perform Jenkins' automatic checkout.
     * We will perform checkout explicitly in the Checkout stage.
     */
    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    /*
     * =========================================================
     * PARAMETERS
     * =========================================================
     */

    parameters {

        choice(
            name: 'IMAGE_TAG',
            choices: ['1.0', '1.1', '1.2'],
            description: 'Docker image version'
        )

        choice(
            name: 'ENVIRONMENT',
            choices: ['DEV', 'QA', 'PROD'],
            description: 'Deployment environment'
        )
    }


    /*
     * =========================================================
     * GLOBAL ENVIRONMENT VARIABLES
     * =========================================================
     */

    environment {

        AWS_REGION = 'eu-north-1'

        ECR_REPOSITORY = 'devops-demo-app'


        /*
         * EC2 SERVERS
         *
         * Replace these with your actual DEV / QA / PROD
         * EC2 IP addresses.
         */

        DEV_HOST  = '16.192.126.10'

        QA_HOST   = '16.16.126.99'

        PROD_HOST = '13.48.204.116'


        /*
         * Jenkins SSH credential
         */

        SSH_CREDENTIAL_ID = 'ec2-ssh-key'


        /*
         * Docker settings
         */

        CONTAINER_NAME = 'devops-demo-app'

        CONTAINER_PORT = '2000'

        HOST_PORT = '2000'
    }


    /*
     * =========================================================
     * STAGES
     * =========================================================
     */

    stages {


        /*
         * =====================================================
         * 1. CHECKOUT
         * =====================================================
         */

        stage('Checkout') {

            steps {

                echo "=========================================="
                echo "CHECKOUT"
                echo "=========================================="

                echo "Repository:"
                echo "https://github.com/Satoo36/swiggy.git"

                git(
                    branch: 'main',
                    url: 'https://github.com/Satoo36/swiggy.git'
                )

                echo "Checkout completed"
            }
        }


        /*
         * =====================================================
         * 2. GET AWS ACCOUNT
         * =====================================================
         */

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
                        "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"


                    env.ECR_IMAGE =
                        "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${params.IMAGE_TAG}"


                    echo "=========================================="
                    echo "AWS INFORMATION"
                    echo "=========================================="

                    echo "AWS Account : ${env.AWS_ACCOUNT_ID}"

                    echo "AWS Region  : ${env.AWS_REGION}"

                    echo "ECR Registry: ${env.ECR_REGISTRY}"

                    echo "Repository  : ${env.ECR_REPOSITORY}"

                    echo "Image Tag   : ${params.IMAGE_TAG}"

                    echo "Image       : ${env.ECR_IMAGE}"
                }
            }
        }


        /*
         * =====================================================
         * 3. CHECK ECR REPOSITORY
         * =====================================================
         */

        stage('Check ECR Repository') {

            steps {

                echo "Checking ECR repository..."

                sh '''
                    aws ecr describe-repositories \
                    --repository-names ${ECR_REPOSITORY} \
                    --region ${AWS_REGION}
                '''

                echo "ECR repository exists"
            }
        }


        /*
         * =====================================================
         * 4. ECR LOGIN
         * =====================================================
         */

        stage('ECR Login') {

            steps {

                echo "Logging into Amazon ECR..."

                sh '''
                    aws ecr get-login-password \
                    --region ${AWS_REGION} | \
                    docker login \
                    --username AWS \
                    --password-stdin \
                    ${ECR_REGISTRY}
                '''

                echo "ECR login successful"
            }
        }


        /*
         * =====================================================
         * 5. DOCKER BUILD
         *
         * IMPORTANT:
         *
         * BUILD ONLY HAPPENS FOR DEV.
         *
         * QA and PROD DO NOT BUILD.
         * =====================================================
         */

        stage('Docker Build') {

            when {

                expression {

                    return params.ENVIRONMENT == 'DEV'
                }
            }

            steps {

                echo "=========================================="
                echo "DOCKER BUILD"
                echo "=========================================="

                echo "Building:"
                echo "${env.ECR_IMAGE}"

                sh '''
                    docker build \
                    --pull \
                    -t ${ECR_IMAGE} \
                    .
                '''

                echo "Docker build completed"
            }
        }


        /*
         * =====================================================
         * 6. DOCKER IMAGE TEST
         *
         * Only DEV because DEV performs the build.
         * =====================================================
         */

        stage('Docker Image Test') {

            when {

                expression {

                    return params.ENVIRONMENT == 'DEV'
                }
            }

            steps {

                echo "Testing Docker image..."

                sh '''
                    docker image inspect ${ECR_IMAGE}
                '''

                echo "Docker image test successful"
            }
        }


        /*
         * =====================================================
         * 7. PUSH TO ECR
         *
         * PUSH ONLY FROM DEV.
         *
         * QA and PROD never push.
         * =====================================================
         */

        stage('Push to ECR') {

            when {

                expression {

                    return params.ENVIRONMENT == 'DEV'
                }
            }

            steps {

                echo "=========================================="
                echo "PUSH TO ECR"
                echo "=========================================="

                echo "Pushing:"
                echo "${env.ECR_IMAGE}"

                sh '''
                    docker push ${ECR_IMAGE}
                '''

                echo "Image pushed successfully"
            }
        }


        /*
         * =====================================================
         * 8. SELECT EXISTING IMAGE
         *
         * Used by QA and PROD.
         *
         * NO BUILD
         * NO PUSH
         *
         * The image must already exist in ECR.
         * =====================================================
         */

        stage('Select Existing Image') {

            when {

                expression {

                    return params.ENVIRONMENT != 'DEV'
                }
            }

            steps {

                echo "=========================================="
                echo "SELECT EXISTING IMAGE"
                echo "=========================================="

                echo "Environment : ${params.ENVIRONMENT}"

                echo "Image Tag   : ${params.IMAGE_TAG}"

                echo "No Docker build will be performed."

                echo "No Docker push will be performed."


                sh '''
                    aws ecr describe-images \
                    --repository-name ${ECR_REPOSITORY} \
                    --image-ids imageTag=${IMAGE_TAG} \
                    --region ${AWS_REGION}
                '''

                echo "Existing ECR image verified"
            }
        }


        /*
         * =====================================================
         * 9. GET ECR IMAGE DIGEST
         *
         * This is very important.
         *
         * We resolve:
         *
         * 1.0 -> sha256:xxxx
         * 1.1 -> sha256:xxxx
         * 1.2 -> sha256:xxxx
         *
         * Deployment will use this exact digest.
         * =====================================================
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


                    if (
                        !env.ECR_DIGEST ||
                        env.ECR_DIGEST == 'None'
                    ) {

                        error(
                            "Image ${params.IMAGE_TAG} does not exist in ECR."
                        )
                    }


                    env.ECR_IMAGE_DIGEST =
                        "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}@${env.ECR_DIGEST}"


                    echo "=========================================="
                    echo "ECR IMAGE DIGEST"
                    echo "=========================================="

                    echo "IMAGE TAG    : ${params.IMAGE_TAG}"

                    echo "IMAGE DIGEST : ${env.ECR_DIGEST}"

                    echo "IMAGE BY DIGEST:"
                    echo "${env.ECR_IMAGE_DIGEST}"
                }
            }
        }


        /*
         * =====================================================
         * 10. SELECT ENVIRONMENT
         * =====================================================
         */

        stage('Select Environment') {

            steps {

                script {

                    switch (params.ENVIRONMENT) {

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

                            error(
                                "Invalid environment: ${params.ENVIRONMENT}"
                            )
                    }


                    echo "=========================================="
                    echo "DEPLOYMENT TARGET"
                    echo "=========================================="

                    echo "Environment : ${params.ENVIRONMENT}"

                    echo "Target Host : ${env.TARGET_HOST}"

                    echo "Image Tag   : ${params.IMAGE_TAG}"

                    echo "Digest      : ${env.ECR_DIGEST}"
                }
            }
        }


        /*
         * =====================================================
         * 11. DEPLOY
         *
         * IMPORTANT:
         *
         * The deployment server does NOT build the image.
         *
         * It pulls the EXACT ECR DIGEST.
         * =====================================================
         */

        stage('Deploy') {

            steps {

                script {

                    echo "=========================================="
                    echo "DEPLOY"
                    echo "=========================================="

                    echo "Environment : ${params.ENVIRONMENT}"

                    echo "Image Tag   : ${params.IMAGE_TAG}"

                    echo "Digest      : ${env.ECR_DIGEST}"

                    echo "Target      : ${env.TARGET_HOST}"


                    sshagent(
                        credentials: [env.SSH_CREDENTIAL_ID]
                    ) {

                        sh """

                            ssh -o StrictHostKeyChecking=no \
                            ubuntu@${env.TARGET_HOST} '

                                set -e

                                echo "========================================="
                                echo "REMOTE DEPLOYMENT"
                                echo "========================================="

                                echo "Environment:"
                                echo "${params.ENVIRONMENT}"

                                echo "Image:"
                                echo "${env.ECR_IMAGE_DIGEST}"


                                echo ""
                                echo "1. Checking IAM role..."
                                echo ""

                                aws sts get-caller-identity


                                echo ""
                                echo "2. Logging into ECR..."
                                echo ""

                                AWS_ACCOUNT_ID=\\\$(aws sts get-caller-identity \
                                --query Account \
                                --output text)


                                aws ecr get-login-password \
                                --region ${env.AWS_REGION} | \
                                docker login \
                                --username AWS \
                                --password-stdin \
                                \\\${AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com


                                echo ""
                                echo "3. Pulling EXACT image digest..."
                                echo ""

                                docker pull ${env.ECR_IMAGE_DIGEST}


                                echo ""
                                echo "4. Stopping old container..."
                                echo ""

                                docker rm -f ${env.CONTAINER_NAME} \
                                2>/dev/null || true


                                echo ""
                                echo "5. Starting container..."
                                echo ""

                                docker run -d \
                                --name ${env.CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${env.HOST_PORT}:${env.CONTAINER_PORT} \
                                ${env.ECR_IMAGE_DIGEST}


                                echo ""
                                echo "6. Container status..."
                                echo ""

                                docker ps \
                                --filter name=${env.CONTAINER_NAME}


                                echo ""
                                echo "Deployment completed."
                                echo ""

                            '
                        """
                    }
                }
            }
        }


        /*
         * =====================================================
         * 12. VERIFY IMAGE DIGEST
         *
         * Verify that the running container uses exactly
         * the same ECR digest.
         * =====================================================
         */

        stage('Verify Image Digest') {

            steps {

                script {

                    echo "=========================================="
                    echo "VERIFY IMAGE DIGEST"
                    echo "=========================================="


                    sshagent(
                        credentials: [env.SSH_CREDENTIAL_ID]
                    ) {

                        def deployedImage = sh(
                            script: """

                                ssh -o StrictHostKeyChecking=no \
                                ubuntu@${env.TARGET_HOST} '

                                    docker inspect \
                                    --format="{{index .RepoDigests 0}}" \
                                    ${env.CONTAINER_NAME}

                                '

                            """,
                            returnStdout: true
                        ).trim()


                        echo "Expected ECR Image:"
                        echo "${env.ECR_IMAGE_DIGEST}"

                        echo ""

                        echo "Deployed Image:"
                        echo "${deployedImage}"

                        echo ""


                        if (
                            !deployedImage.contains(
                                "${env.ECR_DIGEST}"
                            )
                        ) {

                            error(
                                "DIGEST MISMATCH! Expected ${env.ECR_DIGEST}, but deployed ${deployedImage}"
                            )
                        }


                        echo "=========================================="

                        echo "DIGEST VERIFIED SUCCESSFULLY"

                        echo "Same image digest is running."

                        echo "=========================================="
                    }
                }
            }
        }


        /*
         * =====================================================
         * 13. APPLICATION HEALTH CHECK
         * =====================================================
         */

        stage('Health Check') {

            steps {

                script {

                    echo "=========================================="
                    echo "APPLICATION HEALTH CHECK"
                    echo "=========================================="


                    sshagent(
                        credentials: [env.SSH_CREDENTIAL_ID]
                    ) {

                        sh """

                            ssh -o StrictHostKeyChecking=no \
                            ubuntu@${env.TARGET_HOST} '

                                echo "Testing application..."

                                curl -f \
                                http://localhost:${env.HOST_PORT}

                                echo ""

                                echo "Application is UP."

                            '

                        """
                    }
                }
            }
        }
    }


    /*
     * =========================================================
     * POST ACTIONS
     * =========================================================
     */

    post {

        success {

            echo ""
            echo "=========================================="
            echo "          PIPELINE SUCCESS"
            echo "=========================================="

            echo "IMAGE TAG  : ${params.IMAGE_TAG}"

            echo "ENVIRONMENT: ${params.ENVIRONMENT}"

            echo "ECR DIGEST : ${env.ECR_DIGEST}"

            echo "TARGET     : ${env.TARGET_HOST}"

            echo "=========================================="
            echo ""
        }


        failure {

            echo ""
            echo "=========================================="
            echo "          PIPELINE FAILED"
            echo "=========================================="

            echo "IMAGE TAG  : ${params.IMAGE_TAG}"

            echo "ENVIRONMENT: ${params.ENVIRONMENT}"

            echo "=========================================="
            echo ""
        }
    }
}
