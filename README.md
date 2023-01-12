# Run Watson NLP for Embed on an IBM Cloud Kubernetes cluster

This example project has two objectives.

1. Create an IBM Cloud Kubernetes cluster in a VPC environment with Terraform
2. Deploy Watson NLP for embed to the created cluster with helm

The example project reuses code from the  `https://github.com/thomassuedbroecker/terraform-vpc-kubernetes` project.

### Simplified IBM Cloud architecture diagram

Terraform will create and configure on IBM Cloud:

* 1 x VPC

    * 3 x Security Groups

      * 1 x Default
      * 2 x Related to the Kubernetes Cluster (created by the Kubernetes Service creation)
    
    * 1 x Access control list
    * 1 x Routing table
    * 1 x Virtual Private Endpoint Gateway (created by the Kubernetes Service creation)
    * 1 x Public load balancer (created by the Kubernetes Service creation)

* 1 x Kubernetes Cluster 

    * Including 3 [fully IBM managed master nodes](https://cloud.ibm.com/docs/containers?topic=containers-cs_ov)
    * Configured 2 Worker nodes (managed by IBM) ([see responsibilities](https://cloud.ibm.com/docs/containers?topic=containers-responsibilities_iks))
    * Enabled [Block Storage for VPC](http://ibm.biz/addon-state)
    * Enabled service endpoint for public and private communication

This is a simplified diagram of the created infrastructure with terraform.

![](images/VPC-Kubernetes-simplified-architecture.drawio.png)

### Prerequisites

To use the  bash automation you need following tools to be installed on your local computer  

* [IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
* Plugin VPC infrastructure
* Plugin Container-service
* [Terraform](https://www.terraform.io/)
* [Helm](https://helm.sh/)
* [kubectl](https://kubernetes.io/de/docs/tasks/tools/install-kubectl/)

## Example setup

The example setup contains two bash automations:

* [One for Terraform](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/tree/main/code/terraform_setup)
* [One for Helm](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/tree/main/code/helm_setup)

### Step 1: Clone the repo

```sh
git clone https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp.git
cd terraform-vpc-kubernetes-watson-nlp
```

## Create the Kubernetes cluster and VPC

### Step 1: Navigate to the `terraform_setup`

```sh
cd code/terraform_setup
```

### Step 2: Create a `.env` file

```sh
cat .env_template > .env
```

### Step 3: Add an IBM Cloud access key to your local `.env` file

```sh
nano .env
```

Content of the file:

```sh
export IC_API_KEY=YOUR_IBM_CLOUD_ACCESS_KEY
export REGION="us-east"
export GROUP="tsuedbro"
```

### Step 4: Verify the global variables in the bash script automation 

Inspect the bash automation [`create_vpc_kubernetes_cluster_with_terraform.sh`](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/terraform_setup/create_vpc_kubernetes_cluster_with_terraform.sh) and ajust the values to your need.

```sh
nano create_vpc_kubernetes_cluster_with_terraform.sh
```

```sh
#export TF_LOG=debug
export TF_VAR_flavor="bx2.4x16"
export TF_VAR_worker_count="2"
export TF_VAR_kubernetes_pricing="tiered-pricing"
export TF_VAR_resource_group=$GROUP
export TF_VAR_vpc_name="watson-nlp-tsuedbro"
export TF_VAR_region=$REGION
export TF_VAR_kube_version="1.25.5"
export TF_VAR_cluster_name="watson-nlp-tsuedbro"
```

### Step 5: Execute the bash automation

>The creation can take up to 1 hour, depending on the which region you are using.

```sh
sh create_vpc_kubernetes_cluster_with_terraform.sh
```

* Example output:

```sh
...
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
*********************************
```

## Deploy Watson NLP embed with helm

### Step 1: Navigate to the `helm_setup`

```sh
cd code/helm_setup
```

### Step 2: Create a `.env` file

```sh
cat .env_template > .env
```

### Step 3: Add an IBM Cloud access key to your local `.env` file

```sh
export IC_API_KEY=YOUR_IBM_CLOUD_ACCESS_KEY
export IBM_ENTITLEMENT_KEY="YOUR_KEY"
export IBM_ENTITLEMENT_EMAIL="YOUR_EMAIL"
export CLUSTER_ID="YOUR_CLUSTER"
export REGION="us-east"
export GROUP="tsuedbro"
```

### Step 4: Execute the bash automation

```sh
sh deploy-watson-nlp-to-kubernetes.sh
```

The script does following steps and link points to the relevant function in the bash automation:

1. [Log on to IBM Cloud with an IBM Cloud API key.](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/helm_setup/deploy-watson-nlp-to-kubernetes.sh#L13)
2. [It ensures that is connected to the cluster.](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/helm_setup/deploy-watson-nlp-to-kubernetes.sh#L26)
3. [It creates a `Docker Config File` which will be used for the container pull secret.](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/helm_setup/deploy-watson-nlp-to-kubernetes.sh#L37)
4. [It installs the helm chart for Watson NLP embed configured for REST API usage.](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/helm_setup/deploy-watson-nlp-to-kubernetes.sh#L53)
5. [It verifies that the container is running and invokes a REST API call inside the `runtime-container` of Watson NLP emded.](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/helm_setup/deploy-watson-nlp-to-kubernetes.sh#L94)
6. [It verifies that the exposed Kubernetes `URL` with a loadbalancer service is working and invokes a the same REST API call as before from the local machine.](https://github.com/thomassuedbroecker/terraform-vpc-kubernetes-watson-nlp/blob/main/code/helm_setup/deploy-watson-nlp-to-kubernetes.sh#L124)

* Example output:

```sh
*********************
loginIBMCloud
*********************

...

*********************
connectToCluster
*********************

OK
...

*********************
createDockerCustomConfigFile
*********************

IBM_ENTITLEMENT_SECRET: 
...

*********************
installHelmChart
*********************

...

*********************
verifyDeploment
*********************


------------------------------------------------------------------------
Check watson-nlp-container
Status: watson-nlp-container
2023-01-12 09:43:32 Status: watson-nlp-container is created
------------------------------------------------------------------------

*********************
verifyPod could take 10 min
*********************


------------------------------------------------------------------------
Check watson-nlp-container
Status: 0/1
2023-01-12 09:43:32 Status: watson-nlp-container(0/1)
------------------------------------------------------------------------
Status: 0/1
2023-01-12 09:44:33 Status: watson-nlp-container(0/1)
------------------------------------------------------------------------
Status: 1/1
2023-01-12 09:45:34 Status: watson-nlp-container is created
------------------------------------------------------------------------

*********************
verifyWatsonNLPContainer
*********************

Pod: watson-nlp-container-557d9fcf68-wm4vp

Result of the Watson NLP API request:
http://localhost:8080/v1/watson.runtime.nlp.v1/NlpService/SyntaxPredict

{"text":"This is a test sentence.", "producerId":{"name":"Izumo Text Processing", "version":"0.0.1"}, "tokens":[{"span":{"begin":0, "end":4, "text":"This"}, "lemma":"", "partOfSpeech":"POS_UNSET", "dependency":null, "features":[]}, {"span":{"begin":5, "end":7, "text":"is"}, "lemma":"", "partOfSpeech":"POS_UNSET", "dependency":null, "features":[]}, {"span":{"begin":8, "end":9, 
...
```

The image below shows the running container on the Kubernetes cluster.

![](images/watson-nlp-kubernetes-01.png)

