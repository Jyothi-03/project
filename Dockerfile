# The base image is a TaaS Jenkins Ubuntu image for ephemeral slaves
FROM docker-na-public.artifactory.swg-devops.com/ip-ftm-v4-team-docker-virtual/jonk/agent-jnlp:latest as baseos

USER root
RUN apt-get -q update && \
    apt-get install -y \
    chrony \
    rsync \
    unzip \
    xauth \
    xvfb \
    gtk2.0 \
    zip


#############
# mwbase-base
#############
FROM baseos as squash
ARG ARTIFACTORY_USER
ARG ARTIFACTORY_PASSWORD
# setup root jfrog creds for downloads
RUN curl -XGET "https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf/[RELEASE]/jfrog-cli-linux-amd64/jf"  -L -k -g > /usr/bin/jf && \
    chmod +x /usr/bin/jf && \
    mkdir -p  /root/.jfrog && \
    jf config add na \
    --interactive=false \
    --insecure-tls=true  \
    --url=https://na-public.artifactory.swg-devops.com \
    --user=${ARTIFACTORY_USER} \
    --access-token=${ARTIFACTORY_PASSWORD}

###############
# mwbase-gradle
###############
USER jenkins
RUN mkdir -p         /home/jenkins/middleware/ && \
    mkdir -p         /home/jenkins/.gradle && \
    mkdir -p         /home/jenkins/driveD/scratch
COPY --chown=jenkins:jenkins gradle.properties /home/jenkins/.gradle/

##############
# mwbase-jfrog
##############
USER jenkins
RUN  mkdir -p             /home/jenkins/.jfrog
COPY --chown=jenkins:jenkins  jfrog-cli.conf                     /home/jenkins/.jfrog/jfrog-cli.conf
RUN mkdir -p  /home/jenkins/bin && \
    cp /usr/bin/jf   /home/jenkins/bin/ && \
    chmod +x  /home/jenkins/bin/jf && \
    sed -E -i 's%^(artifactory_cli_cmd ).*%\1   = /home/jenkins/bin/jf%g' /home/jenkins/.gradle/gradle.properties

############
# mwbase-iim
############
USER root
RUN jf rt dl --flat ip-devops-team-generic-local/middleware/linux/iim/v1.9/agent.installer.linux.gtk.x86_64_1.9.0.20190715_0328.zip && \
    mkdir -p                                                     /home/jenkins/installs && \
    mv agent.installer.linux.gtk.x86_64_1.9.0.20190715_0328.zip  /home/jenkins/installs/iim.zip && \
    chown -R jenkins:jenkins                                         /home/jenkins/installs

USER jenkins
RUN  cd /home/jenkins/installs/ \
     && pwd \
     && ls -la \
     && unzip iim.zip \
     && ls -la \
     && cd /home/jenkins \
     && pwd \
     && /home/jenkins/installs/userinstc -h \
     && /home/jenkins/installs/userinstc -installationDirectory /home/jenkins/middleware/IBM/InstallationManager -acceptLicense \
     && rm -rf /home/jenkins/installs \
     && sed -E -i 's%^(systemProp.machine.appLoc.iim ).*%\1                     = /home/jenkins/middleware/IBM/InstallationManager%g' /home/jenkins/.gradle/gradle.properties

############
# mwbase-ant
############
USER root
RUN jf rt dl --flat ip-devops-team-generic-local/middleware/linux/ant/v1.9.15/apache-ant-1.9.15-bin.tar.gz && \
    mkdir -p                               /home/jenkins/installs && \
    mv apache-ant-1.9.15-bin.tar.gz     /home/jenkins/installs/ant.tgz && \
    chown -R jenkins:jenkins                   /home/jenkins/installs
USER jenkins
RUN  mkdir -p /home/jenkins/middleware/NON-IBM \
     && cd    /home/jenkins/middleware/NON-IBM \
     && tar -xvzf /home/jenkins/installs/ant.tgz \
     && rm -rf /home/jenkins/installs \
    && sed -E -i 's%^(systemProp.machine.appLoc.ant1915 ).*%\1                  = /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15%g' /home/jenkins/.gradle/gradle.properties

############
# mwbase-jdk8
############
USER root
RUN jf rt dl --flat ip-devops-team-generic-local/middleware/linux/java/SDKs/ibm-java-sdk-8.0-5.37-linux-x86_64.tgz && \
    mkdir -p                                                          /home/jenkins/installs && \
    mv ibm-java-sdk-8.0-5.37-linux-x86_64.tgz                         /home/jenkins/installs/jdk8.tgz && \
    chown -R jenkins:jenkins                                              /home/jenkins/installs
USER jenkins
RUN  cd /home/jenkins/middleware/ \
     && tar -xvzf /home/jenkins/installs/jdk8.tgz \
     && rm -rf /home/jenkins/installs \
     && sed -E -i 's%^(systemProp.machine.appLoc.java8 ).*%\1                   = /home/jenkins/middleware/ibm-java-x86_64-80%g' /home/jenkins/.gradle/gradle.properties

##############
# mwbase-rsa97
##############
USER root
RUN jf rt dl --flat ip-devops-team-generic-local/middleware/linux/rsa/v9.7/RSAD_WS_9.7_Setup.zip && \
    jf rt dl --flat ip-devops-team-generic-local/middleware/linux/rsa/v9.7/RSAD_WS_9.7_1.zip && \
    jf rt dl --flat ip-devops-team-generic-local/middleware/linux/rsa/v9.7/RSAD_WS_9.7_2.zip && \
    jf rt dl --flat ip-devops-team-generic-local/middleware/linux/rsa/v9.7/RSADWS_9.7_Activation_Kit.zip && \
    mkdir -p                                           /home/jenkins/installs && \
    mv RSAD_WS_9.7_Setup.zip                        /home/jenkins/installs/rsa1.zip && \
    mv RSAD_WS_9.7_1.zip                            /home/jenkins/installs/rsa2.zip && \
    mv RSAD_WS_9.7_2.zip                            /home/jenkins/installs/rsa3.zip && \
    mv RSADWS_9.7_Activation_Kit.zip                /home/jenkins/installs/rsaAK.zip
COPY response97.xml                                 /home/jenkins/installs/response97.xml
RUN chown -R jenkins:jenkins                               /home/jenkins/installs
USER jenkins
RUN  cd    /home/jenkins/installs && \
     unzip /home/jenkins/installs/rsa1.zip && \
     unzip /home/jenkins/installs/rsa2.zip && \
     unzip /home/jenkins/installs/rsa3.zip && \
     unzip /home/jenkins/installs/rsaAK.zip
RUN  mv    /home/jenkins/installs/RSA4WS_SETUP/* /home/jenkins/installs/ && \
    mv    /home/jenkins/installs/RSA4WS/disk1   /home/jenkins/installs/ && \
    mv    /home/jenkins/installs/RSA4WS/disk2   /home/jenkins/installs/
RUN  echo "install RSA 9.7" \
     && /home/jenkins/middleware/IBM/InstallationManager/eclipse/tools/imcl \
            input /home/jenkins/installs/response97.xml \
            -log /home/jenkins/installs/RSA97_install_log.xml \
            -acceptLicense
RUN  sed -E -i 's%^(systemProp.machine.appLoc.rsa97 ).*%\1                   = /home/jenkins/IBM/RSA97%g' /home/jenkins/.gradle/gradle.properties

##############
# mwbase-ace12
##############
USER root
RUN jf rt dl --flat ip-devops-team-generic-local/middleware/linux/ace/V12.0.5/IBM_ACE_12.0.5_Linux_x84.tar.gz && \
    mkdir -p                                       /home/jenkins/installs && \
    mv IBM_ACE_12.0.5_Linux_x84.tar.gz             /home/jenkins/installs/ace.tgz && \
    chown -R jenkins:jenkins                           /home/jenkins/installs
USER jenkins
RUN  mkdir -p /home/jenkins/middleware/IBM && \
     cd       /home/jenkins/middleware/IBM/ && \
     tar -xvzf /home/jenkins/installs/ace.tgz \
     && rm -rf /home/jenkins/installs
RUN /home/jenkins/middleware/IBM/ace-12.0.5.0/ace accept license silently && \
    /home/jenkins/middleware/IBM/ace-12.0.5.0/ace verify all && \
    sed -E -i 's%^(systemProp.machine.appLoc.ace12r0m5f0 ).*%\1             = /home/jenkins/middleware/IBM/ace-12.0.5.0%g' /home/jenkins/.gradle/gradle.properties 

FROM baseos
COPY --from=squash --chown=jenkins:jenkins /home/jenkins/ /home/jenkins/

USER root
RUN rm -rf /root && \
    ln -s  /home/jenkins   /root && \
    chown jenkins:jenkins  /root


USER jenkins
RUN echo "artifactory_base_domain_name                       = artifactory.swg-devops.com"                                           >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_contextUrl                             = https://na-public.artifactory.swg-devops.com/artifactory"                    >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_user                                   = yourId@us.ibm.com"                                                    >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_password                               = yourAPItoken"                                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_publish_repo                           = ip-devops-team-maven-virtual"                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_resolve_repo                           = ip-devops-team-maven-virtual"                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo ""                                                                                                                          >> /home/jenkins/.gradle/gradle.properties && \
    echo "#ask Adam before using this resolve_repo"                                                                                  >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_dev_resolve_repo                       = ip-devops-team-maven-virtual"                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_docker_registry                        = ip-ftm-charger-build-docker-local"                                    >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_git_lfs                                = ip-ftm-charger-build-gitlfs-local"                                    >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_public_plugin_repo                     = ip-devops-team-maven-virtual"                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo ""                                                                                                                          >> /home/jenkins/.gradle/gradle.properties && \
    echo "# new upload/download repo path"                                                                                           >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_fs103_repo                             = ip-clt-build-misc-generic-local"                                      >> /home/jenkins/.gradle/gradle.properties && \
    echo ""                                                                                                                          >> /home/jenkins/.gradle/gradle.properties && \
    echo "# other misc repo paths for future use"                                                                                    >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_upload_repo                            = ip-devops-team-generic-local"                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_plugin_repo                            = ip-devops-team-maven-virtual"                                         >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_cache_repo                             = ip-clt-build-gradle-kache-generic-local"                              >> /home/jenkins/.gradle/gradle.properties && \
    echo "artifactory_docker_generic                         = ip-ftm-charger-build-release-generic-local"                           >> /home/jenkins/.gradle/gradle.properties

ENV FTM_PROD=""
# java version to use if not JAVA8
ENV JAVAVERSION="JAVA8"
# Artifactory user used to download dependencies
ENV ARTIFACTORY_USER=yourId@us.ibm.com
# Artifactory API Key used to download dependencies
ENV ARTIFACTORY_PASS=YourArtifactoryAPIkey
# buildLabel used in artifacts or generated if empty
ENV buildLabel=""
# args that will be passed to gradlew to run build
ENV ftm_gradle_args="-is"


#############
# mw406-build
#############
COPY --chown=jenkins:jenkins startBuild.sh /home/jenkins/startBuild.sh
RUN  chmod +x  /home/jenkins/startBuild.sh && \
    mkdir -p /home/jenkins/driveD/SrcWorkspace && \
    mkdir -p /home/jenkins/driveF/builds && \
    mkdir -p /home/jenkins/buildOutput && \
    mkdir -p /home/jenkins/driveD/IBM/FTM && \
    chown -R jenkins:jenkins /home/jenkins/

ENV GRADLE_USER_HOME=/home/jenkins/.gradle

LABEL   author='Vidhya Prakash'
USER    jenkins
WORKDIR /home/jenkins
SHELL ["/bin/bash", "-c"]
# ENTRYPOINT ["/home/jenkins/startBuild.sh"]
