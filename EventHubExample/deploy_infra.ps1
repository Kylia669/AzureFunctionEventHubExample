az group create --name akylfunc-rg --location westus

az deployment group create --resource-group akylfunc-rg --template-file deployment.bicep