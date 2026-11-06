// Declarative pipeline: checkout -> build -> test -> package -> (approve) -> deploy with Ansible.
// Jenkins VM needs: JDK 17, git, ansible. Credential 'shopease-vm-ssh' = SSH private key for the app VMs.
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    triggers {
        // No webhook needed: Jenkins checks GitHub every ~2 minutes. Registered after the first run.
        pollSCM('H/2 * * * *')
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['staging', 'production', 'none'],
               description: 'Where to deploy after a successful build. Production asks for approval.')
    }

    environment {
        // Lab convenience only: skips SSH host-key prompts. For real use, add the VM to known_hosts instead.
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        ANSIBLE_NOCOLOR = '1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'chmod +x gradlew'
                sh './gradlew clean assemble --no-daemon'
            }
        }

        stage('Test') {
            steps {
                sh './gradlew test jacocoTestReport --no-daemon'
            }
            post {
                always {
                    junit 'build/test-results/test/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                archiveArtifacts artifacts: 'build/libs/shopease.jar', fingerprint: true
            }
        }

        stage('Approve production') {
            when {
                expression { params.DEPLOY_ENV == 'production' }
            }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: "Deploy build #${env.BUILD_NUMBER} to PRODUCTION?"
                }
            }
        }

        stage('Deploy') {
            when {
                // Multibranch jobs set BRANCH_NAME; plain Pipeline jobs leave it null (then always allowed).
                expression {
                    // First run of a new pipeline has no parameters yet (null), so treat that as 'none'.
                    (params.DEPLOY_ENV ?: 'none') != 'none' && [null, 'main'].contains(env.BRANCH_NAME)
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'shopease-vm-ssh', keyFileVariable: 'SSH_KEY')]) {
                    dir('ansible') {
                        sh '''
                            ansible-playbook -i "inventory/${DEPLOY_ENV}.ini" deploy.yml \
                              --private-key "$SSH_KEY" \
                              -e jar_path="$WORKSPACE/build/libs/shopease.jar" \
                              -e release_id="$BUILD_NUMBER"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} finished OK (deploy target: ${params.DEPLOY_ENV})."
            // Optional email (needs SMTP set up in Manage Jenkins > System):
            // mail to: 'you@example.com', subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}", body: "${env.BUILD_URL}"
        }
        failure {
            echo "Build #${env.BUILD_NUMBER} FAILED. See ${env.BUILD_URL}console"
            // mail to: 'you@example.com', subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}", body: "${env.BUILD_URL}"
        }
    }
}
