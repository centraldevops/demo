#!/bin/bash

cd iac

export BUILD_VERSION=`sed 's/BUILD_VERSION=//g' .env`
export PROVISIONED=`dig +short centraldevops.$CLOUDFLARE_ZONE_NAME`
export KUBECTL_CMD=`which kubectl`

echo "$DIGITALOCEAN_PRIVATE_KEY" > /tmp/.id_rsa

if [ -f "/tmp/.id_rsa" ]; then
  chmod og-rwx /tmp/.id_rsa
fi

if [ -z "$KUBECTL_CMD" ]; then
  KUBECTL_CMD=./kubectl
fi

if [ -z "$PROVISIONED" ]; then
  TERRAFORM_CMD=`which terraform`

  if [ -z "$TERRAFORM_CMD" ]; then
    TERRAFORM_CMD=./terraform
  fi

  $TERRAFORM_CMD init
  $TERRAFORM_CMD apply -auto-approve \
                       -var "digitalocean_token=$DIGITALOCEAN_TOKEN" \
                       -var "digitalocean_public_key=$DIGITALOCEAN_PUBLIC_KEY" \
                       -var "digitalocean_private_key=$DIGITALOCEAN_PRIVATE_KEY" \
                       -var "cloudflare_email=$CLOUDFLARE_EMAIL" \
                       -var "cloudflare_api_key=$CLOUDFLARE_API_KEY" \
                       -var "cloudflare_zone_id=$CLOUDFLARE_ZONE_ID" \
                       -var "cloudflare_zone_name=$CLOUDFLARE_ZONE_NAME" \
                       -var "datadog_agent_key=$DATADOG_AGENT_KEY"

  CENTRALDEVOPS_IP=`cat centraldevops-ip`

  rm centraldevops-ip

  scp -i /tmp/.id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$CLUSTER_MANAGER_IP:/etc/rancher/k3s/k3s.yaml ./.kubeconfig

  sed -i -e 's|127.0.0.1|'"$CLUSTER_MANAGER_IP"'|g' ./.kubeconfig

  cp ./kubernetes.yml /tmp/kubernetes.yml

  sed -i -e 's|${BUILD_VERSION}|'"$BUILD_VERSION"'|g' /tmp/kubernetes.yml

  $KUBECTL_CMD --kubeconfig=./.kubeconfig apply -f /tmp/kubernetes.yml

  rm -d /tmp/kubernetes.yml
else
  scp -i /tmp/.id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@cluster-manager.$CLOUDFLARE_ZONE_NAME:/etc/rancher/k3s/k3s.yaml ./.kubeconfig

  sed -i -e 's|127.0.0.1|'"cluster-manager.$CLOUDFLARE_ZONE_NAME"'|g' ./.kubeconfig

  $KUBECTL_CMD --kubeconfig=./.kubeconfig set image deployment database database=divand/demo-database:$BUILD_VERSION
  $KUBECTL_CMD --kubeconfig=./.kubeconfig set image daemonset backend backend=divand/fvilarinho/demo-backend:$BUILD_VERSION
  $KUBECTL_CMD --kubeconfig=./.kubeconfig set image daemonSet frontend frontend=divand/fvilarinho/demo-frontend:$BUILD_VERSION
fi

rm -f ./.kubeconfig*
rm -f /tmp/.id_rsa

cd ..
