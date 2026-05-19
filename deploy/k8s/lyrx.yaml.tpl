apiVersion: v1
kind: Namespace
metadata:
  name: ${K8S_NAMESPACE}
  labels:
    app.kubernetes.io/name: ${K8S_APP_NAME}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${K8S_DEPLOYMENT}
  namespace: ${K8S_NAMESPACE}
  labels:
    app.kubernetes.io/name: ${K8S_APP_NAME}
spec:
  replicas: ${K8S_REPLICAS}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${K8S_APP_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${K8S_APP_NAME}
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${K8S_CONTAINER}
          image: ${REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: ${CONTAINER_PORT}
              name: http
          env:
            - name: ENV
              value: ${APP_ENV}
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: ${K8S_READINESS_INITIAL_DELAY}
            periodSeconds: ${K8S_READINESS_PERIOD}
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: ${K8S_LIVENESS_INITIAL_DELAY}
            periodSeconds: ${K8S_LIVENESS_PERIOD}
          resources:
            requests:
              cpu: ${K8S_CPU_REQUEST}
              memory: ${K8S_MEMORY_REQUEST}
            limits:
              cpu: ${K8S_CPU_LIMIT}
              memory: ${K8S_MEMORY_LIMIT}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsUser: ${K8S_RUN_AS_USER}
            runAsGroup: ${K8S_RUN_AS_GROUP}
            capabilities:
              drop: ["ALL"]
---
apiVersion: v1
kind: Service
metadata:
  name: ${K8S_SERVICE}
  namespace: ${K8S_NAMESPACE}
  labels:
    app.kubernetes.io/name: ${K8S_APP_NAME}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: ${K8S_APP_NAME}
  ports:
    - name: http
      port: ${SERVICE_PORT}
      targetPort: http
