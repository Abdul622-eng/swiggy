pipeline {

    agent any

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
     * ENVIRONMENT VARIABLES
     * =========================================================
     */

    environment {

        AWS_REGION = 'eu-north-1'

        ECR_REPOSITORY = 'devops-demo-app'


        /*
         * EC2 PRIVATE IP ADDRESSES
         */

        DEV_HOST  = '13.48.67.105'

        QA_HOST   = '16.171.115.119'

        PROD_HOST = '13.48.71.57'


        /*
         * Jenkins SSH credential
         */

        SSH_CREDENTIAL_ID = 'ec2-ssh-key'


        /*
         * Docker configuration
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
                echo "https://github.com/Abdul622-eng/swiggy.git"

                git(
                    branch: 'main',
                    url: 'https://github.com/Abdul622-eng/swiggy.git'
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
         * ONLY DEV BUILDS THE IMAGE
         *
         * QA and PROD do NOT build.
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
         * ONLY DEV
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
         * ONLY DEV
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
         * QA / PROD
         *
         * NO BUILD
         * NO PUSH
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

                echo "Using existing image from ECR"

                echo "No Docker build"

                echo "No Docker push"


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
         * DEV:
         * Build → Push → Deploy
         *
         * QA/PROD:
         * Existing image → Deploy
         *
         * Deployment always uses exact digest.
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

                        sh(
                            script: """

ssh -o StrictHostKeyChecking=no ubuntu@${env.TARGET_HOST} 'bash -s' <<'REMOTE_SCRIPT'

set -e


echo "========================================="
echo "REMOTE DEPLOYMENT"
echo "========================================="

echo "Environment : ${params.ENVIRONMENT}"

echo "Image Tag   : ${params.IMAGE_TAG}"

echo "Image Digest:"
echo "${env.ECR_IMAGE_DIGEST}"

echo ""


echo "========================================="
echo "1. CHECKING IAM ROLE"
echo "========================================="

aws sts get-caller-identity

echo ""


echo "========================================="
echo "2. CHECKING DISK SPACE"
echo "========================================="

df -h /

echo ""


echo "========================================="
echo "3. CHECKING DOCKER"
echo "========================================="

docker version

echo ""


echo "========================================="
echo "4. DOCKER DISK USAGE"
echo "========================================="

docker system df || true

echo ""


echo "========================================="
echo "5. LOGGING INTO ECR"
echo "========================================="

aws ecr get-login-password \
--region ${env.AWS_REGION} | \
docker login \
--username AWS \
--password-stdin \
${env.ECR_REGISTRY}

echo ""

echo "ECR login successful."

echo ""


echo "========================================="
echo "6. CLEANING UNUSED DOCKER DATA"
echo "========================================="

docker container prune -f || true

docker image prune -f || true

docker builder prune -af || true

echo ""

echo "Docker disk usage after cleanup:"

docker system df || true

echo ""

echo "Disk space after cleanup:"

df -h /

echo ""


echo "========================================="
echo "7. PULLING EXACT IMAGE DIGEST"
echo "========================================="

IMAGE="${env.ECR_IMAGE_DIGEST}"

echo "Image:"
echo "\${IMAGE}"

echo ""


PULL_SUCCESS=false


for ATTEMPT in 1 2 3
do

    echo "-----------------------------------------"

    echo "Docker pull attempt: \${ATTEMPT}/3"

    echo "-----------------------------------------"


    if docker pull "\${IMAGE}"
    then

        echo ""

        echo "Docker pull successful."

        PULL_SUCCESS=true

        break

    else

        echo ""

        echo "Docker pull failed."

        if [ "\${ATTEMPT}" -lt 3 ]
        then

            echo "Cleaning Docker image cache..."

            docker image prune -af || true

            echo ""

            echo "Waiting 10 seconds before retry..."

            sleep 10

        fi

    fi

done


if [ "\${PULL_SUCCESS}" != "true" ]
then

    echo ""

    echo "========================================="

    echo "DOCKER PULL FAILED"

    echo "========================================="

    echo ""

    echo "Final disk status:"

    df -h /

    echo ""

    echo "Docker disk usage:"

    docker system df || true

    exit 1

fi


echo ""


echo "========================================="

echo "8. VERIFY PULLED IMAGE"

echo "========================================="

docker image inspect "\${IMAGE}" >/dev/null

echo "Exact image digest pulled successfully."

echo ""


echo "========================================="

echo "9. STOPPING OLD CONTAINER"

echo "========================================="

docker rm -f ${env.CONTAINER_NAME} 2>/dev/null || true

echo "Old container removed."

echo ""


echo "========================================="

echo "10. STARTING NEW CONTAINER"

echo "========================================="

docker run -d \
--name ${env.CONTAINER_NAME} \
--restart unless-stopped \
-p ${env.HOST_PORT}:${env.CONTAINER_PORT} \
"\${IMAGE}"

echo ""

echo "Container started."

echo ""


echo "========================================="

echo "11. CONTAINER STATUS"

echo "========================================="

docker ps \
--filter name=${env.CONTAINER_NAME}

echo ""


echo "========================================="

echo "12. CONTAINER LOGS"

echo "========================================="

docker logs \
--tail 30 \
${env.CONTAINER_NAME} || true

echo ""

echo "========================================="

echo "DEPLOYMENT COMPLETED"

echo "========================================="

REMOTE_SCRIPT

""".stripIndent()
                        )
                    }
                }
            }
        }


        /*
         * =====================================================
         * 12. VERIFY IMAGE DIGEST
         *
         * Container image ID is compared with the image ID
         * corresponding to the expected ECR digest.
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

                        def deployedImageId = sh(
                            script: """

                                ssh -o StrictHostKeyChecking=no \
                                ubuntu@${env.TARGET_HOST} \
                                "docker inspect \
                                --format='ID={{.Image}}' \
                                ${env.CONTAINER_NAME}"

                            """,
                            returnStdout: true
                        ).trim()


                        echo "Expected ECR Digest:"

                        echo "${env.ECR_DIGEST}"

                        echo ""

                        echo "Container Image ID:"

                        echo "${deployedImageId}"

                        echo ""


                        /*
                         * Get the image ID corresponding to the
                         * expected digest on the remote server.
                         */

                        def expectedImageId = sh(
                            script: """

                                ssh -o StrictHostKeyChecking=no \
                                ubuntu@${env.TARGET_HOST} \
                                "docker image inspect \
                                ${env.ECR_IMAGE_DIGEST} \
                                --format='ID={{.Id}}'"

                            """,
                            returnStdout: true
                        ).trim()


                        echo "Expected Image ID:"

                        echo "${expectedImageId}"

                        echo ""


                        if (
                            !deployedImageId ||
                            !expectedImageId
                        ) {

                            error(
                                "Unable to determine deployed image ID."
                            )
                        }


                        if (
                            deployedImageId != expectedImageId
                        ) {

                            error(
                                "IMAGE MISMATCH! Container is not running the expected ECR image."
                            )
                        }


                        echo "=========================================="

                        echo "IMAGE DIGEST VERIFIED"

                        echo "Container is running the exact image."

                        echo "=========================================="
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
