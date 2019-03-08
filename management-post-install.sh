#!/bin/bash

if [ "$(hostname)" != "management" ]; then
    echo "This script should be run on the management VM only"
    exit 1
fi

helm init
helm repo add cord https://charts.opencord.org
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo update

# The following are needed with newer version of kubernetes, but not the version deploy by default with Rancher
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
