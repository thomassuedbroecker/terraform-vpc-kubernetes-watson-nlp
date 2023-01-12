#!/bin/bash

# **************** Global variables
source ./.env

export HELM_RELEASE_NAME=watson-nlp-kubernetes
export DEFAULT_NAMESPACE="default"

# **********************************************************************************
# Functions definition
# **********************************************************************************

function loginIBMCloud () {
    
    echo ""
    echo "*********************"
    echo "loginIBMCloud"
    echo "*********************"
    echo ""

    ibmcloud login --apikey $IC_API_KEY
    ibmcloud target -r $REGION
    ibmcloud target -g $GROUP
}

function connectToCluster () {

    echo ""
    echo "*********************"
    echo "connectToCluster"
    echo "*********************"
    echo ""

    ibmcloud ks cluster config -c $CLUSTER_ID
}

function createDockerCustomConfigFile () {

    echo ""
    echo "*********************"
    echo "createDockerCustomConfigFile"
    echo "*********************"
    echo ""

    sed "s+IBM_ENTITLEMENT_KEY+$IBM_ENTITLEMENT_KEY+g;s+IBM_ENTITLEMENT_EMAIL+$IBM_ENTITLEMENT_EMAIL+g" "$(pwd)/custom_config.json_template" > "$(pwd)/custom_config.json"
    IBM_ENTITLEMENT_SECRET=$(base64 -i "$(pwd)/custom_config.json")
    echo "IBM_ENTITLEMENT_SECRET: $IBM_ENTITLEMENT_SECRET"

    sed "s+IBM_ENTITLEMENT_SECRET+$IBM_ENTITLEMENT_SECRET+g" $(pwd)/charts/watson-nlp-kubernetes/values.yaml_template > $(pwd)/charts/watson-nlp-kubernetes/values.yaml
    cat $(pwd)/charts/watson-nlp-kubernetes/values.yaml
}

function installHelmChart () {

    echo ""
    echo "*********************"
    echo "installHelmChart"
    echo "*********************"
    echo ""

    TEMP_PATH_ROOT=$(pwd)
    cd $TEMP_PATH_ROOT/charts
    TEMP_PATH_EXECUTION=$(pwd)
    
    helm dependency update ./watson-nlp-kubernetes/
    helm install --dry-run --debug helm-test ./watson-nlp-kubernetes/

    helm lint
    helm install $HELM_RELEASE_NAME ./watson-nlp-kubernetes

    verifyDeploment
    verifyPod
        
    cd $TEMP_PATH_ROOT
}

function uninstallHelmChart () {

    echo ""
    echo "*********************"
    echo "uninstallHelmChart"
    echo "*********************"
    echo ""

    TEMP_PATH_ROOT=$(pwd)
    cd $TEMP_PATH_ROOT/charts
    TEMP_PATH_EXECUTION=$(pwd)

    helm uninstall $HELM_RELEASE_NAME

    cd $TEMP_PATH_ROOT
}

function verifyWatsonNLPContainer () {
    
    echo ""
    echo "*********************"
    echo "verifyWatsonNLPContainer"
    echo "*********************"
    echo ""

    export FIND="watson-nlp-container"
    POD=$(kubectl get pods -n $DEFAULT_NAMESPACE | grep $FIND | awk '{print $1;}')
    echo "Pod: $POD"
    # Needs to be verifed
    # COMMAND='''curl -X POST "http://localhost:8080/v1/watson.runtime.nlp.v1/NlpService/SyntaxPredict" -H "accept: application/json" -H "grpc-metadata-mm-model-id: syntax_izumo_lang_en_stock" -H "content-type: application/json" -d " { \"rawDocument\": { \"text\": \"It is so easy to embed Watson NLP in application. Very cool\" }}"'''
    RESULT=$(kubectl exec --stdin --tty $POD --container $FIND -- curl -X POST "http://localhost:8080/v1/watson.runtime.nlp.v1/NlpService/SyntaxPredict" -H "accept: application/json" -H "grpc-metadata-mm-model-id: syntax_izumo_lang_en_stock" -H "content-type: application/json" -d '{ "rawDocument": { "text": "This is a test sentence." }}')
    echo ""
    echo "Result of the Watson NLP API request:"
    echo "http://localhost:8080/v1/watson.runtime.nlp.v1/NlpService/SyntaxPredict"
    echo ""
    echo "$RESULT"
    echo ""
    echo "Verify the running pod on your cluster."
    kubectl get pods -n $DEFAULT_NAMESPACE
    echo "Verify in the deployment in the Kubernetes dashboard."
    echo ""
    open "https://cloud.ibm.com/kubernetes/clusters/$CLUSTER_ID/overview"
    echo ""

    read ANY_VALUE
}

function verifyWatsonNLPLoadbalancer () {

    echo ""
    echo "*********************"
    echo "verifyWatsonNLP_loadbalancer"
    echo "this can take up to 10 min"
    echo "*********************"
    echo ""

    verifyLoadbalancer

    SERVICE=watson-nlp-container-vpc-nlb
    EXTERNAL_IP=$(kubectl get svc $SERVICE | grep  $SERVICE | awk '{print $4;}')
    echo "EXTERNAL_IP: $EXTERNAL_IP"
    echo "Verify invocation of Watson NLP API from the local machine:"
    curl -X POST "http://$EXTERNAL_IP:8080/v1/watson.runtime.nlp.v1/NlpService/SyntaxPredict" -H "accept: application/json" -H "grpc-metadata-mm-model-id: syntax_izumo_lang_en_stock" -H "content-type: application/json" -d '{ "rawDocument": { "text": "This is a test sentence." }}'
}

# ************ functions used internal **************


function verifyLoadbalancer () {

    echo ""
    echo "*********************"
    echo "verifyLoadbalancer"
    echo "*********************"
    echo ""

    export max_retrys=10
    j=0
    array=("watson-nlp-container-vpc-nlb")
    export STATUS_SUCCESS=""
    for i in "${array[@]}"
        do
            echo ""
            echo "------------------------------------------------------------------------"
            echo "Check $i"
            j=0
            export FIND=$i
            while :
            do      
            ((j++))
            STATUS_CHECK=$(kubectl get svc $FIND -n $DEFAULT_NAMESPACE | grep $FIND | awk '{print $4;}')
            echo "Status: $STATUS_CHECK"
            if ([ "$STATUS_CHECK" != "$STATUS_SUCCESS" ] && [ "$STATUS_CHECK" != "<pending>" ]); then
                    echo "$(date +'%F %H:%M:%S') Status: $FIND is created ($STATUS_CHECK)"
                    echo "------------------------------------------------------------------------"
                    break
                elif [[ $j -eq $max_retrys ]]; then
                    echo "$(date +'%F %H:%M:%S') Maybe a problem does exists!"
                    echo "------------------------------------------------------------------------"
                    exit 1              
                else
                    echo "$(date +'%F %H:%M:%S') Status: $FIND($STATUS_CHECK)"
                    echo "------------------------------------------------------------------------"
                fi
                sleep 60
            done
        done
}

function verifyDeploment () {

    echo ""
    echo "*********************"
    echo "verifyDeploment"
    echo "*********************"
    echo ""

    export max_retrys=4
    j=0
    array=("watson-nlp-container")
    export STATUS_SUCCESS="watson-nlp-container"
    for i in "${array[@]}"
        do
            echo ""
            echo "------------------------------------------------------------------------"
            echo "Check $i"
            j=0
            export FIND=$i
            while :
            do      
            ((j++))
            STATUS_CHECK=$(kubectl get deployment $FIND -n $DEFAULT_NAMESPACE | grep $FIND | awk '{print $1;}')
            echo "Status: $STATUS_CHECK"
            if [ "$STATUS_CHECK" = "$STATUS_SUCCESS" ]; then
                    echo "$(date +'%F %H:%M:%S') Status: $FIND is created"
                    echo "------------------------------------------------------------------------"
                    break
                elif [[ $j -eq $max_retrys ]]; then
                    echo "$(date +'%F %H:%M:%S') Maybe a problem does exists!"
                    echo "------------------------------------------------------------------------"
                    exit 1              
                else
                    echo "$(date +'%F %H:%M:%S') Status: $FIND($STATUS_CHECK)"
                    echo "------------------------------------------------------------------------"
                fi
                sleep 10
            done
        done
}

function verifyPod () {

    echo ""
    echo "*********************"
    echo "verifyPod could take 10 min"
    echo "*********************"
    echo ""

    export max_retrys=10
    j=0
    array=("watson-nlp-container")
    export STATUS_SUCCESS="1/1"
    for i in "${array[@]}"
        do
            echo ""
            echo "------------------------------------------------------------------------"
            echo "Check $i"
            j=0
            export FIND=$i
            while :
            do      
            ((j++))
            STATUS_CHECK=$(kubectl get pods -n $DEFAULT_NAMESPACE | grep $FIND | awk '{print $2;}')
            echo "Status: $STATUS_CHECK"
            if [ "$STATUS_CHECK" = "$STATUS_SUCCESS" ]; then
                    echo "$(date +'%F %H:%M:%S') Status: $FIND is created"
                    echo "------------------------------------------------------------------------"
                    break
                elif [[ $j -eq $max_retrys ]]; then
                    echo "$(date +'%F %H:%M:%S') Maybe a problem does exists!"
                    echo "------------------------------------------------------------------------"
                    exit 1              
                else
                    echo "$(date +'%F %H:%M:%S') Status: $FIND($STATUS_CHECK)"
                    echo "------------------------------------------------------------------------"
                fi
                sleep 60
            done
        done
}


#**********************************************************************************
# Execution
# *********************************************************************************

loginIBMCloud

connectToCluster

createDockerCustomConfigFile

installHelmChart

verifyWatsonNLPContainer

verifyWatsonNLPLoadbalancer

#uninstallHelmChart
