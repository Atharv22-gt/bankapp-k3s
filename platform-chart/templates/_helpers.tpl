{{- define "platform.labels" -}}
app.kubernetes.io/part-of: bankapp-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
