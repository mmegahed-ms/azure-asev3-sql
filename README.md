
# About

This repository contains the iac for a terrafrom script that automate the deployment of azure app service enviroment with app service plan which hosts 2 app service apps and one function app connecting to azure sql db using serivce enpoint and using a common log analytics workspace as depicted below in the architecture.

# Architecture

![image](https://github.com/mmegahed-ms/azure-asev3-sql/blob/main/assets/arch.png)


# Prerequisites

To run the script, you will need the following:

# [Creating Azure service principle]

use the following command with the appropiate scope and role assigment 
az ad sp create-for-rbac --name "myApp" --role contributor \
                                --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
                                --sdk-auth                                
                                
for full instrcution check this link:https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Cwindows                                

# [Add the service principal as a GitHub secret]
In GitHub, go to your repository.

Select Security > Secrets and variables > Actions.

![image](https://github.com/mmegahed-ms/azure-asev3-sql/blob/main/assets/secrets.png)


![image](https://github.com/mmegahed-ms/azure-asev3-sql/blob/main/assets/actions.png)


Select New repository secret.

Paste the entire JSON output from the Azure CLI command into the secret's value field. Give the secret the name AZURE_CREDENTIALS.

Select Add secret

Also add any other secret required for the gihub action there

# [Store Terraform state in Azure Storage]

#!/bin/bash

RESOURCE_GROUP_NAME=tfstate
STORAGE_ACCOUNT_NAME=tfstate$RANDOM
CONTAINER_NAME=tfstate

#Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

#Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

#Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

update the backend part in the provider.tf file with your storage account 

  backend "azurerm" {
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = ""
    key                  = ""
  }

In this example, public network access is allowed to this Azure storage account. In a production deployment, it's recommended to restrict access to this storage account using a storage firewall, service endpoint, or private endpoint.

you can check full instructions here: https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage?tabs=azure-cli
