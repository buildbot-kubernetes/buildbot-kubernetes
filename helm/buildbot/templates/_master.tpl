{{- define "buildbot.master" -}}
{{- $buildbotWorker := (dict "Release" (dict "Name" .Release.Name) "Chart" (dict "Name" "buildbot-worker") "Values" (index .Values "buildbot-worker")) }}
replicas: {{ .Values.replicaCount }}
selector:
  matchLabels:
    app.kubernetes.io/name: {{ include "buildbot.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/component: buildbot-master
template:
  metadata:
    labels:
      app.kubernetes.io/name: {{ include "buildbot.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
      app.kubernetes.io/component: buildbot-master
  spec:
{{- with .Values.securityContext }}
    securityContext:
{{ toYaml . | indent 6 }}
{{- end }}
{{- if or .Values.securityContext.runAsUser .Values.extraInit .Values.secret.values .Values.secret.extraFileSecret }}
    initContainers:
{{- if .Values.securityContext.runAsUser }}
    - name: "chown-workdir"
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy | quote }}
      command:
      - /bin/sh
      - -c
      - chown -R {{ .Values.securityContext.runAsUser }}:{{ .Values.securityContext.fsGroup }} /var/lib/buildbot
      securityContext:
        runAsUser: 0
      volumeMounts:
      - mountPath: /var/lib/buildbot
        name: buildbot-master-dir
{{- end }}
{{- if .Values.secret.values }}
    - name: "copy-secret"
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy | quote }}
      command:
      - /bin/sh
      - -c
      - >-
        cp -r /etc/buildbot-secret/* /var/lib/buildbot-secret &&
        chown {{ .Values.securityContext.runAsUser }} -R /var/lib/buildbot-secret &&
        find /var/lib/buildbot-secret -type f -exec chmod 600 {} +
      securityContext:
        runAsUser: 0
      volumeMounts:
      - name: buildbot-secret-workdir
        mountPath: /var/lib/buildbot-secret
{{- if .Values.secret.values }}
      - name: buildbot-secret
        mountPath: /etc/buildbot-secret/{{ .Release.Name }}-secret
{{- end }}
{{- range .Values.secret.extraFileSecret }}
      - name: buildbot-secret-{{ . }}
        mountPath: /etc/buildbot-secret/buildbot-secret-{{ . }}
{{- end }}
{{- end }}
{{- end }}
    containers:
    - name: {{ .Chart.Name }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      env:
      - name: BUILDBOT_CONFIG_URL
        value: "file:///mnt/buildbot/master.cfg"
{{- if .Values.db.enabled }}
      - name: PG_USERNAME
        value: "{{ .Values.postgresql.postgresUser }}"
      - name: PG_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ .Release.Name }}-postgresql
            key: postgres-password
{{- end }}
{{- if (index .Values "buildbot-worker").enabled }}
      - name: NUM_WORKERS
        value: "{{ (index .Values "buildbot-worker").replicaCount }}"
      - name: WORKERPASS
        valueFrom:
          secretKeyRef:
{{- if (index .Values "buildbot-worker").password.secret_name}}
            name: {{ (index .Values "buildbot-worker").password.secret_name }}
{{- else }}
            name: {{ include "buildbot-worker.fullname" $buildbotWorker }}-secret
{{- end }}
            key: {{ (index .Values "buildbot-worker").password.key }}
{{- end }}
      ports:
      - name: http
        containerPort: {{ .Values.serviceUI.port }}
        protocol: TCP
      - name: pb
        containerPort: {{ .Values.servicePB.port }}
        protocol: TCP
      livenessProbe:
        httpGet:
          path: /
          port: http
      readinessProbe:
        httpGet:
          path: /
          port: http
{{- if typeIs "string" .Values.antiAffinity }}
{{- if eq .Values.affinity "hard-anti-affinity" }}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - topologyKey: "kubernetes.io/hostname"
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: "{{ include "buildbot.name" . }}"
                app.kubernetes.io/instance: "{{ .Release.Name }}"
                app.kubernetes.io/component: "buildbot-master"
{{- else if eq .Values.affinity "soft-anti-affinity" }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: "{{ include "buildbot.name" . }}"
                  app.kubernetes.io/instance: "{{ .Release.Name }}"
                  app.kubernetes.io/component: "buildbot-master"
{{- end }}
{{- else }}
{{- with .Values.affinity }}
      affinity:
{{ toYaml . | indent 8 }}
{{- end }}
{{- end }}
      volumeMounts:
      - name: buildbot-master-dir
        mountPath: /var/lib/buildbot
      - name: buildbot-secret-workdir
        mountPath: /var/lib/buildbot-secret
      - name: buildbot-master-file
        mountPath: /mnt/buildbot
{{- if .Values.local_docker.enabled }}
      - name: rundind
        mountPath: /var/run/docker.sock
        subPath: docker.sock
{{- end }}
{{- with .Values.resources }}
      resources:
{{ toYaml . | indent 8 }}
{{- end }}
{{- with .Values.nodeSelector }}
    nodeSelector:
{{ toYaml . | indent 8 }}
{{- end }}
{{- with .Values.tolerations }}
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
    - name: buildbot-secret-workdir
      emptyDir: {}
    - name: buildbot-master-file
      {{ .Values.config.type }}:
{{- if .Values.config.name }}
        name: {{ .Values.config.name }}
{{- else }}
        name: {{ include "buildbot.fullname" . }}-master.cfg
{{- end }}
        items:
{{ toYaml .Values.config.items | indent 8 -}}
{{- if .Values.secret.values }}
    - name: buildbot-secret
      secret:
        secretName: {{ include "buildbot.fullname" . }}-secret
        defaultMode: 256
{{- end }}
{{- range .Values.secret.extraFileSecret }}
    - name: buildbot-secret-{{ . }}
      secret:
        secretName: {{ . }}
        defaultMode: 256
{{- end }}
{{- if .Values.local_docker.enabled }}
    - name: varlibdockerdind
      emptyDir: {}
    - name: rundind
      emptyDir: {}
{{- end }}
{{- end -}}
