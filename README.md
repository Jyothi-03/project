# docker-pipeline-ant-build-common-mw406

This code helps in creating an image for ephemeral slave of TaaS Jenkins (Ubuntu) 

```shell
export IMAGE_NAME=pipeline/ant-build-common-mw406
podman build \
    --build-arg ARTIFACTORY_URL=https://na-public.artifactory.swg-devops.com/artifactory \
    --build-arg ARTIFACTORY_USER=<yourUsername> \
    --build-arg ARTIFACTORY_PASSWORD=<yourAPIToken> \
    -t $IMAGE_NAME:test \
    .
export REPO_URL=docker-na-public.artifactory.swg-devops.com/ip-ftm-v4-team-dev-docker-local/devops/ip-sps
podman tag $IMAGE_NAME:test $REPO_URL/$IMAGE_NAME:latest
podman push $REPO_URL/$IMAGE_NAME
``` 

# Usage of this image

This image will be used for application which will require ant build,RSA9.7 and ACEv12 .
Applications like IP,HVP,CBPR,T2,Euro
This image should be used only through Jenkins configuration as nodes

Link to TaaS Ubuntu DockerFile - https://github.ibm.com/TAAS/demo-kubernetes-pod-image/blob/main/Dockerfile-taas-ubuntu
