pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 45, unit: 'MINUTES')
  }

  environment {
    // <<< EDIT ME >>>
    ORG = 'your-org'                     // Your GitHub org/user
    REGISTRY = 'your-registry'           // e.g. ghcr.io/your-org or registry.example.com
    REGISTRY_CREDENTIALS = 'registry-credentials-id'
    GIT_SSH_CREDENTIALS = 'github-ssh-credentials-id'

    // Derived tags
    COMMIT = "${env.GIT_COMMIT ?: ''}"
    BRANCH = "${env.BRANCH_NAME ?: 'main'}"
    // Will be set in the "Init" stage once we parse JOB_NAME
    PKG_NUMBER = ''
    IMAGE_TAG = ''
  }

  stages {
    stage('Init') {
      steps {
        script {
          // Derive pkg number robustly (handles Multibranch and foldered jobs)
          def m = (env.JOB_NAME =~ /pkg(\d+)/)
          if (m && m[0] && m[0].size() > 1) {
            env.PKG_NUMBER = m[0][1]
          } else {
            error "Unable to determine PKG_NUMBER from JOB_NAME='${env.JOB_NAME}'. Rename job like 'pkg7-pipeline'."
          }

          // Compute tagging scheme
          def shortSha = (env.GIT_COMMIT ?: 'unknown').take(7)
          env.IMAGE_TAG = "${env.BRANCH}-${env.BUILD_NUMBER}-${shortSha}"

          echo "Building pkg${env.PKG_NUMBER}"
          echo "Branch: ${env.BRANCH}, Commit: ${env.GIT_COMMIT}, Image tag: ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Checkout (this repo)') {
      steps {
        checkout([
          $class: 'GitSCM',
          branches: [[name: env.BRANCH_NAME ?: '*/main']],
          userRemoteConfigs: [[
            // <<< EDIT ME >>> prefer SSH for private repos:
            url: "git@github.com:${env.ORG}/pkg${env.PKG_NUMBER}.git",
            credentialsId: env.GIT_SSH_CREDENTIALS
          ]],
          extensions: [
            [$class: 'CloneOption', shallow: true, depth: 1, noTags: true]
          ]
        ])
      }
    }

    stage('Checkout Dependencies (pkg1..N-1)') {
      when { expression { env.PKG_NUMBER.toInteger() > 1 } }
      steps {
        script {
          sh 'rm -rf deps && mkdir -p deps'
          int n = env.PKG_NUMBER.toInteger()
          // Option A: Sequential (simpler)
          sshagent (credentials: [env.GIT_SSH_CREDENTIALS]) {
            for (int i = 1; i < n; i++) {
              sh """
                echo "Cloning pkg${i}..."
                git clone --depth=1 --branch ${env.BRANCH} git@github.com:${env.ORG}/pkg${i}.git deps/pkg${i} || \
                git clone --depth=1 git@github.com:${env.ORG}/pkg${i}.git deps/pkg${i}
              """
            }
          }
        }
      }
    }

    stage('Prepare Incremental Build Context') {
      steps {
        sh """
          rm -rf incremental-build
          mkdir -p incremental-build/deps
          # deps/ may not exist if PKG_NUMBER=1
          if [ -d "deps" ]; then cp -R deps/* incremental-build/deps/ || true; fi
          # current package into its own folder to avoid collisions
          mkdir -p incremental-build/pkg${PKG_NUMBER}
          rsync -a --exclude 'incremental-build' --exclude '.git' ./ incremental-build/pkg${PKG_NUMBER}/
        """
      }
    }

    stage('Build Images') {
      steps {
        script {
          docker.withRegistry("https://${env.REGISTRY}", env.REGISTRY_CREDENTIALS) {
            // Optional: pull cache to speed up builds (ignore errors)
            sh "docker pull ${env.REGISTRY}/pkg${env.PKG_NUMBER}:buildcache || true"
            sh "docker pull ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:buildcache || true"

            // Build individual image (context = repo root)
            def individualImage = docker.build(
              "${env.REGISTRY}/pkg${env.PKG_NUMBER}:${env.IMAGE_TAG}",
              "--build-arg PKG_NUMBER=${env.PKG_NUMBER} --cache-from ${env.REGISTRY}/pkg${env.PKG_NUMBER}:buildcache ."
            )

            // Build complete (incremental) image (context = incremental-build)
            def completeImage = docker.build(
              "${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:${env.IMAGE_TAG}",
              "--build-arg PKG_NUMBER=${env.PKG_NUMBER} --cache-from ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:buildcache incremental-build"
            )

            // Tag cache images for next runs
            individualImage.push("buildcache")
            completeImage.push("buildcache")
          }
        }
      }
    }

    stage('Test (Individual & Complete)') {
      parallel {
        stage('Test Individual') {
          steps {
            sh """
              echo "Smoke-testing pkg${PKG_NUMBER}:${IMAGE_TAG}"
              docker run --rm ${env.REGISTRY}/pkg${env.PKG_NUMBER}:${env.IMAGE_TAG} /bin/sh -c "echo READY && [ -f /etc/os-release ]"
            """
          }
        }
        stage('Test Complete') {
          steps {
            sh """
              echo "Smoke-testing pkg${PKG_NUMBER}-complete:${IMAGE_TAG}"
              docker run --rm ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:${env.IMAGE_TAG} /bin/sh -c "echo READY && [ -d /app ] || [ -d /workspace ] || true"
            """
          }
        }
      }
    }

    stage('Push Images') {
      when {
        anyOf {
          branch 'main'
          buildingTag()
        }
      }
      steps {
        script {
          docker.withRegistry("https://${env.REGISTRY}", env.REGISTRY_CREDENTIALS) {
            def tags = [
              env.IMAGE_TAG,                      // e.g. featureX-123-abc1234
              "${env.BUILD_NUMBER}",              // Jenkins build number
              (env.GIT_COMMIT ?: '').take(7)     // short SHA
            ]
            for (t in tags) {
              sh "docker tag ${env.REGISTRY}/pkg${env.PKG_NUMBER}:${env.IMAGE_TAG} ${env.REGISTRY}/pkg${env.PKG_NUMBER}:${t}"
              sh "docker tag ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:${env.IMAGE_TAG} ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:${t}"
              sh "docker push ${env.REGISTRY}/pkg${env.PKG_NUMBER}:${t}"
              sh "docker push ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:${t}"
            }

            // Latest on main
            if (env.BRANCH == 'main') {
              sh "docker tag ${env.REGISTRY}/pkg${env.PKG_NUMBER}:${env.IMAGE_TAG} ${env.REGISTRY}/pkg${env.PKG_NUMBER}:latest"
              sh "docker tag ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:${env.IMAGE_TAG} ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:latest"
              sh "docker push ${env.REGISTRY}/pkg${env.PKG_NUMBER}:latest"
              sh "docker push ${env.REGISTRY}/pkg${env.PKG_NUMBER}-complete:latest"
            }
          }
        }
      }
    }
  }

  post {
    always {
      sh 'docker ps -a || true'
      cleanWs(deleteDirs: true, disableDeferredWipeout: true)
    }
    success { echo "✅ pkg${env.PKG_NUMBER} build complete" }
    failure { echo "❌ pkg${env.PKG_NUMBER} build failed" }
  }
}
