# Default Applications directory

helm_apps_dir := "apps"
helm_timeout := "5m"

# Kind configuration

cluster_name := "dev01"
cluster_config := "kind/config.yaml"

# Nginx Ingress Controller configuration

nginx_repo_name := "ingress-nginx"
nginx_chart_name := "ingress-nginx"
nginx_chart_url := "https://kubernetes.github.io/ingress-nginx"
nginx_chart_version := "4.13.0"
nginx_release_name := "ingress-nginx"
nginx_release_namespace := "ingress-nginx"
nginx_values_file := helm_apps_dir + "/" + nginx_release_name + "/values.yaml"

# ArgoCD configuration

argocd_repo_name := "argo"
argocd_chart_name := "argo-cd"
argocd_chart_url := "https://argoproj.github.io/argo-helm"
argocd_chart_version := "8.2.5"
argocd_release_name := "argocd"
argocd_release_namespace := "argocd"
argocd_values_file := helm_apps_dir + "/" + argocd_release_name + "/values.yaml"
argocd_url := "http://argocd.apps.127.0.0.1.nip.io"
argocd_app_path := "argocd/application.yaml"
argocd_app_name := "app-of-apps"

# 📚 Information from recipes available
default:
    @just --list

# 🚀 Provision a Kubernetes cluster with required dependencies
provision: _check-kind _check-nginx _check-argocd _check-argocd-deploy argocd-url

_check-kind:
    #!/usr/bin/env bash
    set -e
    if [[ `just _kind-status-cluster` == "0" ]]; then \
        just _kind-create-cluster
    else
        echo 'Cluster {{ cluster_name }} is already running! 🚀'
    fi

_kind-status-cluster:
    #!/usr/bin/env bash
    set -e
    cluster_status=`kind get clusters | grep {{ cluster_name }} | wc -l`
    echo $cluster_status

_kind-create-cluster:
    @kind create cluster --config={{ cluster_config }} --name={{ cluster_name }}

_kind-update-context:
    @kubectl cluster-info --context kind-{{ cluster_name }}
    @kubectl config use-context kind-{{ cluster_name }}

_repo-nginx:
    @just _add-helm-repo {{ nginx_repo_name }} {{ nginx_chart_url }}

_status-nginx:
    @just _status-helm-package {{ nginx_release_name }} {{ nginx_release_namespace }}

_install-nginx:
    @just _install-helm-package {{ nginx_chart_name }} {{ nginx_repo_name }} \
    {{ nginx_release_name }} {{ nginx_release_namespace }} {{ nginx_values_file }}

_update-nginx:
    @just _update-helm-package {{ nginx_chart_name }} {{ nginx_repo_name }} \
    {{ nginx_release_name }} {{ nginx_release_namespace }} {{ nginx_values_file }}

_check-nginx: _repo-nginx _kind-update-context
    #!/usr/bin/env bash
    set -e
    if [[ `just _status-nginx` == "0" ]]; then
        just _install-nginx
    elif [[ `just _status-nginx` == "1" ]]; then
        just _update-nginx
    fi

_repo-argocd:
    @just _add-helm-repo {{ argocd_repo_name }} {{ argocd_chart_url }}

_status-argocd:
    @just _status-helm-package {{ argocd_release_name }} {{ argocd_release_namespace }}

_install-argocd:
    @just _install-helm-package {{ argocd_chart_name }} {{ argocd_repo_name }} \
    {{ argocd_release_name }} {{ argocd_release_namespace }} {{ argocd_values_file }}

_update-argocd:
    @just _update-helm-package {{ argocd_chart_name }} {{ argocd_repo_name }} \
    {{ argocd_release_name }} {{ argocd_release_namespace }} {{ argocd_values_file }}

_check-argocd: _repo-argocd _kind-update-context
    #!/usr/bin/env bash
    set -e
    if [[ `just _status-argocd` == "0" ]]; then
        just _install-argocd
    elif [[ `just _status-argocd` == "1" ]]; then
        just _update-argocd
    fi

# Decide if app-of-apps should be applied or not
_check-argocd-deploy:
    #!/usr/bin/env bash
    set -e
    if [[ `just _status-argocd-deploy` == "0" ]]; then
        just _apply-argocd-deploy
    else
        echo 'ArgoCD {{ argocd_app_name }} app was already applied! 🚀'
    fi

# Check whether the app-of-apps is already applied
_status-argocd-deploy:
    #!/usr/bin/env bash
    set -e
    app_status=`kubectl get applications -A -o name | grep "app-of-apps" | wc -l`
    echo $app_status

# Apply the app-of-apps manifest
_apply-argocd-deploy:
    @kubectl apply -f {{ argocd_app_path }}

# Add helm repository
_add-helm-repo repo_name repo_url:
    @helm repo add {{ repo_name }} {{ repo_url }}

# Check status of a release with helm
_status-helm-package release_name release_namespace:
    #!/usr/bin/env bash
    set -e
    status=`helm -n {{ release_namespace }} ls | grep {{ release_name }} | wc -l`
    echo $status

# Install a release with helm
_install-helm-package chart_name repo_name release_name release_namespace values_file:
    helm install {{ release_name }} {{ repo_name }}/{{ chart_name }} \
    --namespace={{ release_namespace }} --values={{ values_file }} \
    --timeout={{ helm_timeout }} --create-namespace --wait

# Update a release with helm
_update-helm-package chart_name repo_name release_name release_namespace values_file:
    helm upgrade {{ release_name }} {{ repo_name }}/{{ chart_name }} \
    --namespace={{ release_namespace }} --values={{ values_file }} \
    --timeout={{ helm_timeout }} --wait

# 🐙 Prints ArgoCD instance url
argocd-url:
    @echo "\nEnvironment {{ cluster_name }} is ready, you can access ArgoCD at {{ argocd_url }} 🐙"

# 🧻 Cleans up the provisioned environment
clean-up:
    kind delete cluster --name={{ cluster_name }}
