#!/bin/bash -x

export buildRC=0

function trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

function parseProperty() {
  propFile=${1}
  propName=${2}
  propFileData=$(cat ${propFile} )
  propVarLine1=$(echo "${propFileData}" | grep -i "^${propName}" )
  propVarLine2=$(echo "${propVarLine1}" | sed s/${propName}// )
  propVarLine3=$(echo "${propVarLine2}" | sed s/=// )
  propVarLine4=$(echo "${propVarLine3}" | sed s/[\"\']//g )
  propVarLine5=$(echo "${propVarLine4}" | sed s/[[:blank:]]//g )
  propVarLine6=$( trim "${propVarLine5}" )
  printf '%s' "${propVarLine6}"
}

function setup_Lang() {
  export LANG="en_US.UTF-8"
  export LANGUAGE="en_US"
  export LC_CTYPE="en_US.UTF-8"
  export LC_NUMERIC="en_US.UTF-8"
  export LC_TIME="en_US.UTF-8"
  export LC_COLLATE="en_US.UTF-8"
  export LC_MONETARY="en_US.UTF-8"
  export LC_MESSAGES="en_US.UTF-8"
  export LC_PAPER="en_US.UTF-8"
  export LC_NAME="en_US.UTF-8"
  export LC_ADDRESS="en_US.UTF-8"
  export LC_TELEPHONE="en_US.UTF-8"
  export LC_MEASUREMENT="en_US.UTF-8"
  export LC_IDENTIFICATION="en_US.UTF-8"
  export LC_ALL="en_US.UTF-8"
}

function buildBannerDash(){
  echo "----------------------------------------------------------------------"
  echo "${1}"
  echo "----------------------------------------------------------------------"
}

function buildBannerPound(){
  echo "######################################################################"
  echo "${1}"
  echo "######################################################################"
}


function setup_JAVA_HOME() {
  javaVersion=${1}
  case ${javaVersion} in

    JAVA6)
      buildBannerPound "Set default JVM for Gradle environment to [/home/jenkins/middleware/ibm-java-x86_64-60]:"
      export JAVA_HOME=/home/jenkins/middleware/ibm-java-x86_64-60
      ;;

    JAVA7)
      buildBannerPound "Set default JVM for Gradle environment to [/home/jenkins/middleware/ibm-java-x86_64-70]:"
      export JAVA_HOME=/home/jenkins/middleware/ibm-java-x86_64-70
      ;;
    JAVA8)
      buildBannerPound "Set default JVM for Gradle environment to [/home/jenkins/middleware/ibm-java-x86_64-80]:"
      export JAVA_HOME=/home/jenkins/middleware/ibm-java-x86_64-80
      ;;
    *)
      buildBannerPound "Set default JVM for Gradle environment to [/usr/lib/jvm/java-1.8.0]:"
      export JAVA_HOME=/usr/lib/jvm/java-1.8.0
      ;;
  esac
  export PATH=${JAVA_HOME}/bin:${PATH}
}

function setup_source_folder(){
  srcDir=${1}
  dstDir=${2}
  buildBannerPound "Copying source tree to the source build directory from [${srcDir}/] to [${dstDir}/]"
  rsync -a ${srcDir}/* ${dstDir}/
}

function setup_Xvfb() {
  buildBannerPound "Setting up Xvfb virtual display for IIB 10 to [DISPLAY=:99]"
  /usr/bin/Xvfb :99 -screen 0 1280x1024x24 &
  export DISPLAY=:99
}

# this function will expec 'cmd' variable to have complete command to run with arguments
function runBuildCommand(){
  workingDir=${1}
  logFile=${2}
  buildBannerPound "Changing directory to the source build directory [${workingDir}]"
  cd "${workingDir}" || exit 13
  buildBannerPound "Starting the build script:"
  buildBannerPound "#### cmd: ====>${cmd}<===="
  mkdir -p "$(dirname "${logFile}")"
  ${cmd} 2>&1 | tee ${logFile}
  buildRC=${PIPESTATUS[0]}
  echo ""
  buildBannerPound "returned from build script call. rc: [${buildRC}]"
  echo "###################################################################################################################"
  if [ $buildRC -ne 0 ]
  then
    echo " *****************************************************************"
    echo ""
    echo " 		*************  Error  *************"
    echo ""
    echo " 		build FAILED with return code: [${buildRC}]"
    echo ""
    echo " 		*************  Error  *************"
    echo ""
    echo " *****************************************************************"
    # force an error condition for Build
  fi
  buildBannerPound "build command is complete."
}

function setup_Build_Output() {
  srcDir=${1}
  dstDir=${2}
  mkdir -p             ${dstDir}
  rsync -a ${srcDir}/* ${dstDir}/
}


function BUILD_COMMON() {

# start the COMMON Build
  cd /home/jenkins || exit 13
  echo "Reading source from  inside container at /home/jenkins/driveD/SrcWorkspace"
  echo "writing build output inside container at /home/jenkins/buildOutput/common/${buildLabel}"

  setup_Lang

  buildBannerDash "startBuild.sh is starting."
  echo "Starting COMMON Ant build with the following arguments:"
  echo ""
  echo $*
  echo ""
  
  setup_JAVA_HOME ${JAVAVERSION}
  echo ""

  
  
  cd /home/jenkins
  buildBannerDash "downloading from Artifactory to set the eclipse workspace file"
  curl -H "Authorization: Bearer ${ARTIFACTORY_PASS}" https://na.artifactory.swg-devops.com/artifactory/ip-ftm-v4-team-dev-misc-generic-local/commonip-jenkins-ubuntu/ftmip.zip -O
  unzip -o /home/jenkins/ftmip.zip -d /home/jenkins
  chmod +x /home/jenkins/create-ftmip-rsa-workspace.sh
  /home/jenkins/create-ftmip-rsa-workspace.sh

  buildBannerPound "Changing directory to the source build directory [/home/jenkins/driveD/SrcWorkspace/FTM Common Build]"
  cd '/home/jenkins/driveD/SrcWorkspace/FTM Common Build' || exit 13
  echo ""

  setup_Xvfb
  echo ""
  
  export ANT_HOME=/home/jenkins/middleware/NON-IBM/apache-ant-1.9.15
  
  cmd=""
  cmd="${cmd} /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15/bin/ant"
  cmd="${cmd} -Djbe.build.dir=/home/jenkins/driveF/buildOutput"
  cmd="${cmd} -DbuildLabel=${buildLabel}"
  cmd="${cmd} -f build.xml"
  cmd="${cmd} ${ftm_ip_args}"
  runBuildCommand '/home/jenkins/driveD/SrcWorkspace/FTM Common Build' /home/jenkins/driveF/common_${buildLabel}.log

  setup_Build_Output /home/jenkins/driveF/buildOutput        /home/jenkins/buildOutput/common/${buildLabel}
  rsync -a           /home/jenkins/driveF/common_${buildLabel}.log /home/jenkins/buildOutput/common/
}

function BUILD_IP() {
# start the IP Build
  cd /home/jenkins || exit 13
  echo "Reading source from  inside container at /home/jenkins/driveD/SrcWorkspace"
  echo "writing build output inside container at /home/jenkins/buildOutput/ip/${buildLabel}"

  setup_Lang

  buildBannerDash "startBuild.sh is starting."
  echo "Starting IP Ant build with the following arguments:"
  echo ""
  echo $*
  echo ""
  
  setup_JAVA_HOME ${JAVAVERSION}
  echo ""
  
  cd /home/jenkins
  buildBannerDash "downloading from Artifactory to set the eclipse workspace file"
  curl -H "Authorization: Bearer ${ARTIFACTORY_PASS}" https://na.artifactory.swg-devops.com/artifactory/ip-ftm-v4-team-dev-misc-generic-local/commonip-jenkins-ubuntu/ftmip.zip -O
  unzip -o /home/jenkins/ftmip.zip -d /home/jenkins
  chmod +x /home/jenkins/create-ftmip-rsa-workspace.sh
  /home/jenkins/create-ftmip-rsa-workspace.sh

  buildBannerPound "Changing directory to the source build directory [/home/jenkins/driveD/SrcWorkspace/FTM IP Build]"
  cd '/home/jenkins/driveD/SrcWorkspace/FTM IP Build' || exit 13
  echo ""

  setup_Xvfb
  echo ""
  
  export ANT_HOME=/home/jenkins/middleware/NON-IBM/apache-ant-1.9.15

  cmd=""
  cmd="${cmd} /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15/bin/ant"
  cmd="${cmd} -Djbe.build.dir=/home/jenkins/driveF/buildOutput"
  cmd="${cmd} -Dbuild-local=true"
  cmd="${cmd} -DbuildLabel=${buildLabel}"
  cmd="${cmd} -f build.xml"
  cmd="${cmd} ${ftm_ip_args}"
  runBuildCommand '/home/jenkins/driveD/SrcWorkspace/FTM IP Build' /home/jenkins/driveF/ip_${buildLabel}.log

  setup_Build_Output /home/jenkins/driveF/buildOutput        /home/jenkins/buildOutput/ip/${buildLabel}
  rsync -a           /home/jenkins/driveF/ip_${buildLabel}.log /home/jenkins/buildOutput/ip/

}

function BUILD_CBPR() {

# start the CBPRPlus Build
  cd /home/jenkins || exit 13
  echo "Reading source from  inside container at /home/jenkins/driveD/SrcWorkspace"
  echo "writing build output inside container at /home/jenkins/buildOutput/cbprplus/${buildLabel}"

  setup_Lang

  buildBannerDash "startBuild.sh is starting."
  echo "Starting CBPR+ Ant build with the following arguments:"
  echo ""
  echo $*
  echo ""
  
  setup_JAVA_HOME ${JAVAVERSION}
  echo ""
  
  cd /home/jenkins
  buildBannerDash "downloading from Artifactory to set the eclipse workspace file"
  curl -H "Authorization: Bearer ${ARTIFACTORY_PASS}" https://na.artifactory.swg-devops.com/artifactory/ip-ftm-v4-team-dev-misc-generic-local/commonip-jenkins-ubuntu/ftmip.zip -O
  unzip -o /home/jenkins/ftmip.zip -d /home/jenkins
  chmod +x /home/jenkins/create-ftmip-rsa-workspace.sh
  /home/jenkins/create-ftmip-rsa-workspace.sh

  buildBannerPound "Changing directory to the source build directory [/home/jenkins/driveD/SrcWorkspace/FTM CBPR Build]"
  cd '/home/jenkins/driveD/SrcWorkspace/FTM CBPR Build' || exit 13
  echo ""

  setup_Xvfb
  echo ""
  
  export ANT_HOME=/home/jenkins/middleware/NON-IBM/apache-ant-1.9.15

  cmd=""
  cmd="${cmd} /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15/bin/ant"
  cmd="${cmd} -Djbe.build.dir=/home/jenkins/driveF/buildOutput"
  cmd="${cmd} -DbuildLabel=${buildLabel}"
  cmd="${cmd} -f build.xml"
  cmd="${cmd} ${ftm_ip_args}"
  runBuildCommand '/home/jenkins/driveD/SrcWorkspace/FTM CBPR Build' /home/jenkins/driveF/cbprplus_${buildLabel}.log

  setup_Build_Output /home/jenkins/driveF/buildOutput        /home/jenkins/buildOutput/cbprplus/${buildLabel}
  rsync -a           /home/jenkins/driveF/cbprplus_${buildLabel}.log /home/jenkins/buildOutput/cbprplus/

}
function BUILD_T2() {

# start the T2 Build
  cd /home/jenkins || exit 13
  echo "Reading source from  inside container at /home/jenkins/driveD/SrcWorkspace"
  echo "writing build output inside container at /home/jenkins/buildOutput/t2/${buildLabel}"

  setup_Lang

  buildBannerDash "startBuild.sh is starting."
  echo "Starting T2 Ant build with the following arguments:"
  echo ""
  echo $*
  echo ""
  
  setup_JAVA_HOME ${JAVAVERSION}
  echo ""
  
  cd /home/jenkins
  buildBannerDash "downloading from Artifactory to set the eclipse workspace file"
  curl -H "Authorization: Bearer ${ARTIFACTORY_PASS}" https://na.artifactory.swg-devops.com/artifactory/ip-ftm-v4-team-dev-misc-generic-local/commonip-jenkins-ubuntu/ftmip.zip -O
  unzip -o /home/jenkins/ftmip.zip -d /home/jenkins
  chmod +x /home/jenkins/create-ftmip-rsa-workspace.sh
  /home/jenkins/create-ftmip-rsa-workspace.sh

  buildBannerPound "Changing directory to the source build directory [/home/jenkins/driveD/SrcWorkspace/FTM T2 Build]"
  cd '/home/jenkins/driveD/SrcWorkspace/FTM T2 Build' || exit 13
  echo ""

  setup_Xvfb
  echo ""
  
  export ANT_HOME=/home/jenkins/middleware/NON-IBM/apache-ant-1.9.15

  cmd=""
  cmd="${cmd} /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15/bin/ant"
  cmd="${cmd} -Djbe.build.dir=/home/jenkins/driveF/buildOutput"
  cmd="${cmd} -DbuildLabel=${buildLabel}"
  cmd="${cmd} -f build.xml"
  cmd="${cmd} ${ftm_ip_args}"
  runBuildCommand '/home/jenkins/driveD/SrcWorkspace/FTM T2 Build' /home/jenkins/driveF/t2_${buildLabel}.log

  setup_Build_Output /home/jenkins/driveF/buildOutput        /home/jenkins/buildOutput/t2/${buildLabel}
  rsync -a           /home/jenkins/driveF/t2_${buildLabel}.log /home/jenkins/buildOutput/t2/

}


function BUILD_EURO1() {

# start the Euro1 Build
  cd /home/jenkins || exit 13
  echo "Reading source from  inside container at /home/jenkins/driveD/SrcWorkspace"
  echo "writing build output inside container at /home/jenkins/buildOutput/euro1/${buildLabel}"

  setup_Lang

  buildBannerDash "startBuild.sh is starting."
  echo "Starting Euro1 Ant build with the following arguments:"
  echo ""
  echo $*
  echo ""
  
  setup_JAVA_HOME ${JAVAVERSION}
  echo ""
  
  cd /home/jenkins
  buildBannerDash "downloading from Artifactory to set the eclipse workspace file"
  curl -H "Authorization: Bearer ${ARTIFACTORY_PASS}" https://na.artifactory.swg-devops.com/artifactory/ip-ftm-v4-team-dev-misc-generic-local/commonip-jenkins-ubuntu/ftmip.zip -O
  unzip -o /home/jenkins/ftmip.zip -d /home/jenkins
  chmod +x /home/jenkins/create-ftmip-rsa-workspace.sh
  /home/jenkins/create-ftmip-rsa-workspace.sh

  buildBannerPound "Changing directory to the source build directory [/home/jenkins/driveD/SrcWorkspace/FTM Euro1 Build]"
  cd '/home/jenkins/driveD/SrcWorkspace/FTM Euro1 Build' || exit 13
  echo ""

  setup_Xvfb
  echo ""
  
  export ANT_HOME=/home/jenkins/middleware/NON-IBM/apache-ant-1.9.15

  cmd=""
  cmd="${cmd} /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15/bin/ant"
  cmd="${cmd} -Djbe.build.dir=/home/jenkins/driveF/buildOutput"
  cmd="${cmd} -DbuildLabel=${buildLabel}"
  cmd="${cmd} -f build.xml"
  cmd="${cmd} ${ftm_ip_args}"
  runBuildCommand '/home/jenkins/driveD/SrcWorkspace/FTM Euro1 Build' /home/jenkins/driveF/euro1_${buildLabel}.log

  setup_Build_Output /home/jenkins/driveF/buildOutput        /home/jenkins/buildOutput/euro1/${buildLabel}
  rsync -a           /home/jenkins/driveF/euro1_${buildLabel}.log /home/jenkins/buildOutput/euro1/

}

function get_lower_word {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

function BUILD_GENERIC() {
  PRODUCT_ID=$1 # Main name format
  PRODUCT_ID_LOWER=$(get_lower_word $PRODUCT_ID)

  # start the generic Build
  cd /home/jenkins || exit 13
  echo "Reading source from  inside container at /home/jenkins/driveD/SrcWorkspace"
  echo "writing build output inside container at /home/jenkins/buildOutput/${PRODUCT_ID_LOWER}/${buildLabel}"

  setup_Lang

  buildBannerDash "startBuild.sh is starting."
  echo "Starting ${PRODUCT_ID} Ant build with the following arguments:"
  echo ""
  echo $*
  echo ""
  
  setup_JAVA_HOME ${JAVAVERSION}
  echo ""
  
  cd /home/jenkins
  buildBannerDash "downloading from Artifactory to set the eclipse workspace file"
  curl -H "Authorization: Bearer ${ARTIFACTORY_PASS}" https://na.artifactory.swg-devops.com/artifactory/ip-ftm-v4-team-dev-misc-generic-local/commonip-jenkins-ubuntu/ftmip.zip -O
  unzip -o /home/jenkins/ftmip.zip -d /home/jenkins
  chmod +x /home/jenkins/create-ftmip-rsa-workspace.sh
  /home/jenkins/create-ftmip-rsa-workspace.sh

  buildBannerPound "Changing directory to the source build directory [/home/jenkins/driveD/SrcWorkspace/FTM ${PRODUCT_ID} Build]"
  cd "/home/jenkins/driveD/SrcWorkspace/FTM ${PRODUCT_ID} Build" || exit 13
  echo ""

  setup_Xvfb
  echo ""
  
  export ANT_HOME=/home/jenkins/middleware/NON-IBM/apache-ant-1.9.15

  cmd=""
  cmd="${cmd} /home/jenkins/middleware/NON-IBM/apache-ant-1.9.15/bin/ant"
  cmd="${cmd} -Djbe.build.dir=/home/jenkins/driveF/buildOutput"
  cmd="${cmd} -DbuildLabel=${buildLabel}"
  cmd="${cmd} -f build.xml"
  cmd="${cmd} ${ftm_ip_args}"
  runBuildCommand "/home/jenkins/driveD/SrcWorkspace/FTM ${PRODUCT_ID} Build" /home/jenkins/driveF/${PRODUCT_ID_LOWER}_${buildLabel}.log

  setup_Build_Output /home/jenkins/driveF/buildOutput        /home/jenkins/buildOutput/${PRODUCT_ID_LOWER}/${buildLabel}
  rsync -a           /home/jenkins/driveF/${PRODUCT_ID_LOWER}_${buildLabel}.log /home/jenkins/buildOutput/${PRODUCT_ID_LOWER}/

}


cd /home/jenkins || exit 13

case "${FTM_PROD}" in
    Common)
        echo "reading source from  inside container at /SrcWorkspace"
        echo "writing build output inside container at /buildOutput/common/${buildLabel}"

        BUILD_COMMON $*

        echo "returned from COMMON build call. buildRC: [${buildRC}]"
    ;;
    IP)
        echo "reading source from  inside container at /SrcWorkspace"
        echo "writing build output inside container at /buildOutput/ip/${buildLabel}"
        BUILD_IP $*
        echo "returned from IP build call. buildRC: [${buildRC}]"
    ;;
    CBPR)
        echo "reading source from  inside container at /SrcWorkspace"
        echo "writing build output inside container at /buildOutput/cbprplus/${buildLabel}"

        BUILD_CBPR $*

       
        echo "returned from CBPRPlus build call. buildRC: [${buildRC}]"
    ;;
    T2)
        echo "reading source from  inside container at /SrcWorkspace"
        echo "writing build output inside container at /buildOutput/t2/${buildLabel}"

        BUILD_T2 $*

       
        echo "returned from T2 build call. buildRC: [${buildRC}]"
    ;;
    Euro1)
        echo "reading source from  inside container at /SrcWorkspace"
        echo "writing build output inside container at /buildOutput/euro1/${buildLabel}"

        BUILD_EURO1 $*

       
        echo "returned from EURO build call. buildRC: [${buildRC}]"
    ;;    
    # ALL)
    #     echo "reading source from  inside container at /baseSrcWorkspace"
    #     echo "writing build output inside container at /buildOutput/base/${buildLabel}"
    #     BUILD_Hemi $*
    #     echo "returned from Hemi build call. buildRC: [${buildRC}]"
    #     if [ $buildRC -eq 0 ]
    #     then
    #         echo "reading source from  inside container at /SrcWorkspace"
    #         echo "writing build output inside container at /buildOutput/ip/${buildLabel}"
    #         BUILD_IP $*
    #         echo "returned from IP build call. buildRC: [${buildRC}]"
    #         if [ $buildRC -eq 0 ]
    #         then
    #             echo "reading source from  inside container at /SrcWorkspace"
    #             echo "writing build output inside container at /buildOutput/Charger/${buildLabel}"
    #             BUILD_Charger $*
    #             echo "returned from Charger build call. buildRC: [${buildRC}]"
    #         fi
    #     fi
    # ;;
    *)
        echo "Attempting a generic build for FTM_PROD == ${FTM_PROD}"
        LOWER_CASE_FTM_PROD=$(get_lower_word $FTM_PROD)
        echo "Lower case product calculated as: ${LOWER_CASE_FTM_PROD}"
        
        echo "reading source from  inside container at /SrcWorkspace"
        echo "writing build output inside container at /buildOutput/${LOWER_CASE_FTM_PROD}/${buildLabel}"

        BUILD_GENERIC "${FTM_PROD}" $*

        echo "returned from GENERIC build call. buildRC: [${buildRC}]"

    # echo "The only valid options for FTM_PROD environment variable is 'Common', 'IP', 'CBPR', 'T2', 'Euro1'"
    # echo "now exiting"
    # exit 1
    ;;
esac
exit $buildRC
