#!/bin/bash
ROLE_NAME="DTAClusterIAMRole"
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query Role.Arn --output text)
ACM_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='roelvanstapelreverseproxy.be'].CertificateArn" --output text)
aws eks --region us-west-2 update-kubeconfig --name dtacluster
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
kubectl apply -f rbac-role-alb-ingress-controller.yaml
kubectl annotate serviceaccount -n kube-system alb-ingress-controller eks.amazonaws.com/role-arn=$ROLE_ARN
helm install aws-load-balancer-controller eks/aws-load-balancer-controller --set clusterName=dtacluster -n kube-system --set serviceAccount.create=false --set serviceAccount.name=alb-ingress-controller
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
cd ./dev
kubectl apply -k .
cd ../test
kubectl apply -k .
cd ../acc
kubectl apply -k .
cd ..
helm install datadogagent -f values.yaml --set apikey datadog/datadog --set targetSystem=linux
sleep 60
aws elbv2 describe-load-balancers --query 'LoadBalancers[1].[DNSName]' --output text > albnamedta
