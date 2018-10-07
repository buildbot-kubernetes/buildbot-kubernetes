{{- define "buildbot.master" -}}
replicas: {{ .Values.master.replicaCount }}
selector:
  matchLabels:
    app: {{ template "buildbot.name" . }}
    chart: {{ template "buildbot.chart" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
    compotent: {{ template "buildbot.name" . }}-master
template:
  metadata:
    labels:
      app: {{ template "buildbot.name" . }}
      chart: {{ template "buildbot.chart" . }}
      release: {{ .Release.Name }}
      heritage: {{ .Release.Service }}
      compotent: {{ template "buildbot.name" . }}-master
  spec:
{{- with .Values.master.securityContext }}
    securityContext:
{{ toYaml . | indent 6 }}
{{- end }}
{{- if or .Values.master.securityContext.runAsUser .Values.master.extraInit }}
    initContainers:
{{- if .Values.master.securityContext.runAsUser }}
    - name: "chown"
      image: "{{ .Values.master.image.repository }}:{{ .Values.master.image.tag }}"
      imagePullPolicy: {{ .Values.master.image.pullPolicy | quote }}
      command:
      - /bin/sh
      - -c
      - chown -R {{ .Values.master.securityContext.runAsUser }}:{{ .Values.master.securityContext.fsGroup }} /var/lib/buildbot
      securityContext:
        runAsUser: 0
      volumeMounts:
      - mountPath: /var/lib/buildbot
        name: buildbot-master-dir
{{- end }}
{{- end }}
    containers:
    - name: {{ .Chart.Name }}
      image: "{{ .Values.master.image.repository }}:{{ .Values.master.image.tag }}"
      imagePullPolicy: {{ .Values.master.image.pullPolicy }}
      env:
      - name: BUILDBOT_CONFIG_URL
        value: "file:///mnt/buildbot/master.cfg"
{{- if .Values.postgresql.enabled }}
      - name: PG_USERNAME
        value: "{{ .Values.postgresql.postgresUser }}"
      - name: PG_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ .Release.Name }}-postgresql
            key: postgres-password
{{- end }}
{{- if .Values.worker.enabled }}
      - name: NUM_WORKERS
        value: "{{ .Values.worker.replicaCount }}"
      - name: WORKERPASS
        valueFrom:
          secretKeyRef:
{{- if .Values.worker.password.secret_name}}
            name: {{ .Values.worker.password.secret_name }}
{{- else }}
            name: {{ .Release.Name }}-worker-secret
{{- end }}
            key: {{ .Values.worker.password.key }}
{{- end }}
      ports:
      - name: http
        containerPort: {{ .Values.master.serviceUI.port }}
        protocol: TCP
      - name: pb
        containerPort: {{ .Values.master.servicePB.port }}
        protocol: TCP
      livenessProbe:
        httpGet:
          path: /
          port: http
      readinessProbe:
        httpGet:
          path: /
          port: http
{{- if typeIs "string" .Values.master.antiAffinity }}
{{- if eq .Values.master.antiAffinity "hard" }}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - topologyKey: "kubernetes.io/hostname"
            labelSelector:
              matchLabels:
                app: "{{ template "buildbot.name" . }}"
                release: "{{ .Release.Name }}"
                component: "master"
{{- else if eq .Values.master.antiAffinity "soft" }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app: "{{ template "buildbot.name" . }}"
                  release: "{{ .Release.Name }}"
                  component: "master"
{{- end }}
{{- else }}
{{- with .Values.master.antiAffinity }}
      affinity:
{{ toYaml . | indent 8 }}
{{- end }}
{{- end }}
      volumeMounts:
      - name: buildbot-master-dir
        mountPath: /var/lib/buildbot
      - name: buildbot-master-file
        mountPath: /mnt/buildbot
{{- if .Values.local_docker.enabled }}
      - name: rundind
        mountPath: /var/run/docker.sock
        subPath: docker.sock
{{- end }}
  {{- with .Values.master.resources }}
      resources:
{{ toYaml . | indent 8 }}
  {{- end }}
  {{- with .Values.master.nodeSelector }}
    nodeSelector:
{{ toYaml . | indent 8 }}
  {{- end }}
  {{- with .Values.master.affinity }}
    affinity:
{{ toYaml . | indent 8 }}
  {{- end }}
  {{- with .Values.master.tolerations }}
    tolerations:
{{ toYaml . | indent 8 }}
  {{- end }}
{{- if .Values.local_docker.enabled }}
    - name: docker-dind-worker
      image: "{{ .Values.local_docker.image.repository }}:{{ .Values.local_docker.image.tag }}"
      imagePullPolicy: {{ .Values.local_docker.image.pullPolicy }}
      securityContext:
        allowPrivilegeEscalation: true
      volumeMounts:
      - name: varlibdockerdind
        mountPath: /var/lib/docker
      - name: rundind
        mountPath: /var/run/
{{- end }}
    volumes:
    - name: buildbot-master-file
      {{ .Values.config.type }}:
{{- if .Values.config.name }}
        name: {{ .Values.config.name }}
{{- else }}
        name: {{ .Release.Name }}-master.cfg
{{- end }}
        items:
{{ toYaml .Values.config.items | indent 8 }}
{{- if .Values.local_docker.enabled }}
    - name: varlibdockerdind
      emptyDir: {}
    - name: rundind
      emptyDir: {}
{{- end }}
{{- end -}}
