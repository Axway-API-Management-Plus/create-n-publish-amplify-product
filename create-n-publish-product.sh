#!/bin/bash

echo "Running the script"

# Sourcing user-provided env properties

source ./config/env.properties

####################################
# Utility function                 #
####################################
function error_exit {
   if [ $? -ne 0 ]
   then
      echo "$1"
      if [ $2 ]
      then
         echo "See $2 file for errors"
      fi
      exit 1
   fi
}


#######################################################################
###################################################
# Authenticate to the Amplify Platform using SA   #
###################################################

axway auth login --client-id $CLIENT_ID --client-secret $CLIENT_SECRET
axway auth switch --org "$ORGANIZATION"

error_exit "Problem with authentication to your account. Please, verify your credentials"


#######################################################################
###################################################
# Creating an asset and mapping service instances #
###################################################

# creating a working dir for JSON files
mkdir ./json_files

jq -n -f ./jq/asset.jq --arg title "$ASSET_TITLE" > ./json_files/asset.json
axway central create -f ./json_files/asset.json -o json -y > ./json_files/asset-created.json 

error_exit "Problem when creating an asset" "./json_files/asset-created.json"

# Setting ASSET_NAME that will be used by other commands
export ASSET_NAME=$(jq -r .[0].name ./json_files/asset-created.json)

axway central get apisi  -s $ENVIRONMENT_NAME -o json > ./json_files/api-instances.json
error_exit "Problem getting Service Instances" "./json_files/api-instances.json"

# Get the number of Service Instances for the given ENV

COUNT=$(jq '. | length' ./json_files/api-instances.json)



# Check if required Stage exists in the target ORG

export STAGE_COUNT=$(axway central get stages -q title=="\"$STAGE_TITLE\"" -o json | jq '.|length')

if [ $STAGE_COUNT -eq 0 ]
then
   echo "Creating new Stage"
   jq -n -f ./jq/stage.jq --arg stage_title "$STAGE_TITLE" --arg stage_description "$STAGE_DESCRIPTION" > ./json_files/stage.json
   axway central create -f ./json_files/stage.json -o json -y > ./json_files/stage-created.json
   export STAGE_NAME=$(jq -r .[0].name ./json_files/stage-created.json)
   error_exit "Problem creating a Stage" "./json_files/stage-created.json"
else  
   export STAGE_NAME=$(axway central get stages -q title=="\"$STAGE_TITLE\"" -o json | jq -r .[0].name)
fi

for (( i=0; i<$COUNT; i++ ))
do 
   # Get all necessary information about Service, Service Revision and Instance

   export INS_NAME=$(jq -r '.['$i'].name' ./json_files/api-instances.json)
   export RVN_NAME=$(jq -r '.['$i'].spec.apiServiceRevision' ./json_files/api-instances.json)
   export SRV_NAME=$(axway central get apisr $RVN_NAME -s $ENVIRONMENT_NAME -o json | jq -r '.spec.apiService')
   echo "$INS_NAME"

   # Create an asset mapping file to add a Service Instance to the asset

   jq -n -f ./jq/asset-mapping.jq --arg asset_name "$ASSET_NAME" --arg stage_name "$STAGE_NAME" --arg env_name "$ENVIRONMENT_NAME" > ./json_files/asset-mapping.json
   axway central create -f ./json_files/asset-mapping.json -y -o json > ./json_files/asset-mapping-created.json

   error_exit "Problem creating asset mapping" "./json_files/asset-mapping-created.json"

done

# Assign a category to the asset

CATEGORY_COUNT=$(axway central get category -q title=="\"$CATEGORY_TITLE\""  -o json | jq '.|length')

if [ $CATEGORY_COUNT -eq 0 ]
then
   echo "Creating new Category"
   jq -n -f ./jq/category.jq --arg category_title "$CATEGORY_TITLE" --arg description "$CATEGORY_DESCRIPTION" > ./json_files/category.json
   axway central create -f ./json_files/category.json -y -o json > ./json_files/category-created.json
   export categoryName=`jq -r .[0].name ./json_files/category-created.json`
else
   export categoryName=$(axway central get category -q title=="\"$CATEGORY_TITLE\""  -o json | jq -r .[0].name)
fi

axway central get asset $ASSET_NAME -o json | jq '.spec.categories |= . + [env.categoryName]' > ./json_files/asset-updated.json
error_exit "Problem assigning a Category to the Asset" "./json_files/asset-updated.json"

# Adding an image to the Asset

export encodedImage=`base64 -w 0 ./images/my-asset.png`
echo $(cat ./json_files/asset-updated.json | jq '.icon = "data:image/png;base64," + env.encodedImage') > ./json_files/asset-updated.json

# Now we change the state of the Asset to state "Active" and remove "references" element, as it gives us an error (it is a know issue)

echo $(cat ./json_files/asset-updated.json | jq '.state = "active"' | jq 'del(. | .references)') > ./json_files/asset-updated.json


axway central apply -f ./json_files/asset-updated.json
error_exit "Problem changing Asset to the active state"




# Now we need to add a release tag, otherwise Amplify won't allow us to use this asset in Product Foundry commands
# Create a release tag file from a template

jq --slurp -f ./jq/asset-release-tag.jq ./json_files/asset-created.json > ./json_files/asset-release-tag.json
axway central create -f ./json_files/asset-release-tag.json -o json -y > ./json_files/asset-release-tag-created.json

error_exit "Problem creating release tag" "./json_files/asset-release-tag-created.json"



#######################################################################
#######################################################
# Creating a Product and publishing it to Marketplace #
#######################################################

# Create a Product JSON file from the JQ filter file

jq -n -f ./jq/product.jq --arg product_title "$PRODUCT_TITLE" --arg asset_name "$ASSET_NAME" --arg description "$PRODUCT_DESCRIPTION" > ./json_files/product.json
axway central create -f ./json_files/product.json -y -o json > ./json_files/product-created.json

error_exit "Problem creating a Product" "./json_files/product-created.json"

# Adding image to the Product object

export PRODUCT_NAME=`jq -r .[0].name ./json_files/product-created.json`
export encodedImage=`base64 -w 0 ./images/my-company.png`
axway central get product $PRODUCT_NAME -o json | jq '.icon = "data:image/png;base64," + env.encodedImage' > ./json_files/product-updated.json
echo $(cat ./json_files/product-updated.json | jq 'del(. | .references?)') > ./json_files/product-updated.json
axway central apply -f ./json_files/product-updated.json



# Now create DOCs for our PRODUCT

export articleTitle="Overview"
export articleContent=$(<./jq/doc_content.md)
jq -f ./jq/article.jq ./json_files/product-created.json > ./json_files/article.json
axway central create -f ./json_files/article.json -o json -y > ./json_files/article-created.json

error_exit "Problem creating an article"

# Based on the existing articles that we created in the previous step,
# we now create Documet object that will be part of the Product object

export docTitle="Product Overview"
axway central get resources -s $PRODUCT_NAME -o json > ./json_files/available-articles.json
jq -f ./jq/document.jq ./json_files/available-articles.json > ./json_files/document.json
axway central create -f ./json_files/document.json -o json -y > ./json_files/document-created.json

error_exit "Problem creating a product document" "./json_files/document-created.json"



# Query and create (if needed) a Product category

axway central get product $PRODUCT_NAME -o json | jq '.spec.categories |= . + [env.categoryName]' > ./json_files/product-updated.json
echo $(cat ./json_files/product-updated.json | jq 'del(. | .references?)') > ./json_files/product-updated.json
axway central apply -f ./json_files/product-updated.json

error_exit "Problem with assigning a Category to the Product"



# Change Product state to Active

axway central get product $PRODUCT_NAME -o json  | jq '.state = "active"' > ./json_files/product-updated.json
echo $(cat ./json_files/product-updated.json | jq 'del(. | .references?)') > ./json_files/product-updated.json
axway central apply -f ./json_files/product-updated.json

error_exit "Problem when changing Product state to Active"



# Create a Product release tag

jq -f ./jq/product-release-tag.jq ./json_files/product-created.json > ./json_files/product-release-tag.json
axway central create -f ./json_files/product-release-tag.json -o json -y > ./json_files/product-release-tag-created.json

error_exit "Problem creating a Product release tag" "./json_files/product-release-tag-created.json"



#  Create a Product Plan (Free)

jq -f ./jq/product-plan.jq ./json_files/product-created.json > ./json_files/product-plan.json
axway central create -f ./json_files/product-plan.json -o json -y > ./json_files/product-plan-created.json

error_exit "Problem when creating a Product plan" "./json_files/product-plan-created.json"

export PRODUCT_PLAN_NAME=`jq -r .[0].name ./json_files/product-plan-created.json`


# Create a quota in Product Plan. This is a required step
# First, create a quota JSON file with empty array for referenced asset resources.
# It will be populated in the following loop
# FYI, we get a list of Asset Resources from the latest release

jq -n -f jq/quota.jq --arg quota_title "$QUOTA_TITLE" --arg product_plan_name "$PRODUCT_PLAN_NAME" > json_files/quota.json

LATEST_RELEASE=$(axway central get assetreleases -o json | jq 'del(.[] | select(.spec.asset != $ENV.ASSET_NAME))' | jq -r '.|.[].spec.version' | sort -t= -nr -k3 - | head -1)

RELEASE_NAME=$(axway central get assetrelease -q spec.version=="$LATEST_RELEASE" -o json | jq -r '.[0].name')

axway central get assetresources -s "$RELEASE_NAME" -o json > json_files/asset-resource.json

COUNT=$(jq '. | length' json_files/asset-resource.json)

for (( i=0; i<$COUNT; i++ ))
do
    export ASSET_RESOURCE_NAME=$(jq -r '.['$i'].name' json_files/asset-resource.json)
    export RESOURCE_NAME=$ASSET_NAME/$ASSET_RESOURCE_NAME
    echo $(jq '.spec.resources += [{"kind": "AssetResource", "name": $ENV.RESOURCE_NAME}]' json_files/quota.json) > json_files/quota.json
done

axway central create -f json_files/quota.json -y -o json > json_files/quota-created.json

error_exit "Problem with creating Quota" "json_files/quota-created.json"


# Activate Product Plan

axway central get productplans $PRODUCT_PLAN_NAME -o json  | jq '.state = "active"' > ./json_files/product-plan-updated.json
echo $(cat ./json_files/product-plan-updated.json | jq 'del(. | .status?, .references?)') > ./json_files/product-plan-updated.json
axway central apply -f ./json_files/product-plan-updated.json

error_exit "Problem with change Product Plan to the active state"



# Publish to the Marketplace

axway central get marketplaces -o json > ./json_files/marketplace.json
jq --slurp -f ./jq/publish-product.jq ./json_files/marketplace.json ./json_files/product-created.json  > ./json_files/publish-product.json
axway central create -f ./json_files/publish-product.json -o json -y > ./json_files/publish-product-created.json

error_exit "Problem with pubishing a Product on Marketplace" "./json_files/publish-product-created.json"