#!/bin/bash

set -e

shellScriptName=`basename $0`

USAGE="___________________________________________________________________________________________________\n
USAGE: ${shellScriptName} <options> 
OPTIONS:
[-k | --key-id (AWS Access Key ID)]
[-s | --secret (AWS Secret Access Key)]
[-c | --merchant-code (Merchant Code Given by L1)]
[-f | --local-file (Full location to local file)]
[-b | --bucket (Bucket name where you put the file)]
[-t | --content-type (OPTIONAL - Content Type of the file)]
[-h | --help (OPTIONAL - print this help menu)]

EXAMPLES:
./${shellScriptName} --merchant-code folder1 --key-id ABCKEYID --secret ABCSECRETACCESSKEY123 --local-file ./fileName.png --bucket bucket-Name-On-S3

./${shellScriptName} -c folder1 -k ABCKEYID -s ABCSECRETACCESSKEY123 -f /Users/ksalera/temp/fileName.png -b bucket-Name-On-S3

Override default content-type
./${shellScriptName} -c folder1 -k ABCKEYID -s ABCSECRETACCESSKEY123 -f ./fileName.png -t image/png -b bucket-Name-On-S3
___________________________________________________________________________________________________
"

if [ $# -eq 0 ]; then
    echo "No arguments provided"
    echo "${USAGE}"
  exit 1
fi

while [ "$1" != "" ]; do
    case "$1" in
      "-k" | "--key-id")
        shift
        AWSAccessKeyId=$1
        ;;      
      "-s" | "--secret")
        shift
        YourSecretAccessKeyID=$1
        ;;      
      "-c" | "--merchant-code")
        shift
        MerchantCode=$1
        ;;      
      "-f" | "--local-file")
        shift
        LocalFilePath=$1
        LocalFileName=`basename $LocalFilePath`
        ;;      
      "-b" | "--bucket")
        shift
        Bucket=$1
        ;;      
      "-t" | "--content-type")
        shift
        ContentType=$1
        ;;      
      "-h" | "--help")
        echo "${USAGE}"
        exit 0
        ;;
      *)
        echo "${USAGE}"
        exit 1
        ;;
    esac
    shift
done

if [ -z $AWSAccessKeyId ] || [ -z $YourSecretAccessKeyID ] || [ -z $MerchantCode ] || [ -z $LocalFilePath ] || [ -z $LocalFileName ] || [ -z $Bucket ]; then
    echo "All parameters not passed"
    echo "${USAGE}"
    exit 1
fi

if [ -z $Bucket ]; then Bucket="bucket-default-test1"; fi
if [ -z $ContentType ]; then ContentType="text/plain"; fi

ContentLength=$(wc -c ${LocalFilePath} | awk '{print $1}')
echo "${LocalFilePath} of type ${ContentType} is of ${ContentLength} bytes"

# https://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html#RESTAuthenticationConstructingCanonicalizedAmzHeaders
CanonicalizedAmzHeaders="x-amz-server-side-encryption:AES256\n"
echo "CanonicalizedAmzHeaders is: ${CanonicalizedAmzHeaders}"

# https://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html#ConstructingTheCanonicalizedResourceElement
CanonicalizedResource="/${Bucket}/${MerchantCode}/${LocalFileName}"
echo "CanonicalizedResource is: ${CanonicalizedResource}"

Date="`date +'%a, %d %b %Y %H:%M:%S %z'`"
echo "Date is: ${Date}"

StringToSign="PUT\n\n${ContentType}\n${Date}\n${CanonicalizedAmzHeaders}${CanonicalizedResource}"
echo "StringToSign is: ${StringToSign}"

Signature=`echo -en "${StringToSign}" | openssl sha1 -hmac ${YourSecretAccessKeyID} -binary | base64`
echo "Signature is: ${Signature}"

Authorization="AWS ${AWSAccessKeyId}:${Signature}"
echo "Authorization is: ${Authorization}"

curl    -X PUT -T "${LocalFilePath}" \
        -H "Date: ${Date}" \
        -H "Content-Type: ${ContentType}" \
        -H "Content-Length: ${ContentLength}" \
        -H "X-Amz-Server-Side-Encryption: AES256" \
        -H "Authorization: ${Authorization}" \
        "https://s3.amazonaws.com${CanonicalizedResource}"
