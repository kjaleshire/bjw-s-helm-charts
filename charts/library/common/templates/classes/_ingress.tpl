{{/*
This template serves as a blueprint for all Ingress objects that are created
within the common library.
*/}}

{{- define "bjw-s.common.class.ingress" -}}
  {{- $rootContext := .rootContext -}}
  {{- $ingressObject := .object -}}

  {{- $labels := merge
    ($ingressObject.labels | default dict)
    (include "bjw-s.common.lib.metadata.allLabels" $rootContext | fromYaml)
  -}}
  {{- $annotations := merge
    ($ingressObject.annotations | default dict)
    (include "bjw-s.common.lib.metadata.globalAnnotations" $rootContext | fromYaml)
  -}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $ingressObject.name }}
  {{- with $labels }}
  labels:
    {{- range $key, $value := . }}
      {{- printf "%s: %s" $key (tpl $value $rootContext | toYaml ) | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- with $annotations }}
  annotations:
    {{- range $key, $value := . }}
      {{- printf "%s: %s" $key (tpl $value $rootContext | toYaml ) | nindent 4 }}
    {{- end }}
  {{- end }}
  namespace: {{ $rootContext.Release.Namespace }}
spec:
  {{- if $ingressObject.className }}
  ingressClassName: {{ $ingressObject.className }}
  {{- end }}
  {{- if $ingressObject.tls }}
  tls:
    {{- range $ingressObject.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ tpl . $rootContext | quote }}
        {{- end }}
      {{- $secretName := tpl (default "" .secretName) $rootContext }}
      {{- if $secretName }}
      secretName: {{ $secretName | quote}}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $ingressObject.defaultBackend }}
  defaultBackend: {{ $ingressObject.defaultBackend | toYaml | nindent 4 }}
  {{- else }}
  rules:
  {{- range $ingressObject.hosts }}
    - host: {{ tpl .host $rootContext | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ tpl .path $rootContext | quote }}
            pathType: {{ default "Prefix" .pathType }}
            backend:
              service:
                {{ $service := dict -}}
                {{ $serviceName := "" -}}
                {{ $servicePort := 0 -}}

                {{ if .service.name -}}
                  {{ $serviceName = tpl .service.name $rootContext -}}
                {{ else if .service.identifier -}}
                  {{ $service = (include "bjw-s.common.lib.service.getByIdentifier" (dict "rootContext" $rootContext "id" .service.identifier) | fromYaml ) -}}
                  {{ if not $service -}}
                    {{fail (printf "No enabled Service found with this identifier. (ingress: '%s', path: '%s', identifier: '%s')" $ingressObject.identifier .path .service.identifier)}}
                  {{ end -}}
                  {{ $serviceName = $service.name -}}
                {{ end -}}

                {{ if empty (dig "port" nil .service) -}}
                  {{/* Default to the Service primary port if no port has been specified */ -}}
                  {{ if $service -}}
                    {{ $defaultServicePort := include "bjw-s.common.lib.service.primaryPort" (dict "rootContext" $rootContext "serviceObject" $service) | fromYaml -}}
                    {{ if $defaultServicePort -}}
                      {{ $servicePort = $defaultServicePort.port -}}
                    {{ end -}}
                  {{ end -}}
                {{ else -}}
                  {{/* If a port number is given, use that */ -}}
                  {{ if kindIs "float64" .service.port -}}
                    {{ $servicePort = .service.port -}}
                  {{ else if kindIs "string" .service.port -}}
                    {{/* If a port name is given, try to resolve to a number */ -}}
                    {{ $servicePort = include "bjw-s.common.lib.service.getPortNumberByName" (dict "rootContext" $rootContext "serviceID" .service.identifier "portName" .service.port) -}}
                  {{ end -}}
                {{ end -}}
                name: {{ default .service.name $serviceName }}
                port:
                  number: {{ $servicePort }}
          {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
