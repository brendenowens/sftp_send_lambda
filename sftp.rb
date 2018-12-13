require 'json'
require 'aws-sdk-s3'
require 'aws-sdk-secretsmanager'
require 'aws-sdk-sns'
require 'net/sftp'
=begin
   Creator: Brenden Owens (bowens3)
   Created:  12/13/2018
   Modified By: Brenden Owens (bowens3)
   Modified on: 12/13/2018

   Description: This is a lambda function script for sending files out of S3 using SFTP. 
                This script was to help make up for AWS Transfer for SFTP didn't do. 
                The setup needed is: 
                    1. create a deployment package for a ruby lambda function.
                    2. upload the package to lambda
                    3. create a trigger on an S3 bucket to execute the lambda function
                    4. create a config file that details where to send it and other info
=end
# this is the main lambda function that will be called
def lambda_handler(event:, context:)
    # parse the event object to get the S3 object that was modified/created
    event["Records"].each do |record|
         bucket = record["s3"]["bucket"]["name"]
         key = record["s3"]["object"]["key"]
         # get the file that triggered the event and it's config file
         get_files_from_s3(bucket, key)
         # load in the config json file
         file = File.read('/tmp/config.json')
         config_hash = JSON.parse(file)
         # send the file to the destination
         send_file_to_destination(key.split("/")[-1],config_hash)
         # notify the sns topic of the results
         send_sns_notification(config_hash["topic"], 
           "SFTP Success for #{key.split("/")[0]} in the #{key.split("/")[1]} environment", 
           "The file, #{key.split("/")[-1]}, has successfuly been sent to the destination."
        )        
    end
end

# This function gets the files from S3 that triggered the event
def get_files_from_s3(bucket, key)
    # create the s3 resource object
    s3 = Aws::S3::Resource.new(region: 'us-east-1')

    # Create the object to retrieve
    obj = s3.bucket(bucket).object(key)

    # Get the item's content and save it to a file
    obj.get(response_target: '/tmp/'+key.split("/")[-1])
    # Get the config file and save it
    obj2 = s3.bucket(bucket).object(key.split("/")[0]+"/"+key.split("/")[1]+"/config.json")
    obj2.get(response_target: '/tmp/config.json')
    return true
end

# this is the main mover function that will send the file to the destination
def send_file_to_destination(file,config_hash)
    # create a secrets manager client
    client = Aws::SecretsManager::Client.new(region: 'us-east-1')
    # get the secret that holds the ssh keys from the config hash
    resp = client.get_secret_value({
      secret_id: config_hash["secret_name"] 
    })
    # extract the public and private keys from the secret_string field from secrets manager
    ssh_key = JSON.parse(resp.secret_string)["ssh_key"]
    public_key = JSON.parse(resp.secret_string)["public_key"]
    # change to the /tmp directory since that is the only writable place in lambda
    Dir.chdir("/tmp")
    # write the data for the keys to a file
    private_key_file = open("id_rsa", 'w')
    private_key_file.write(ssh_key)
    private_key_file.close()
    public_key_file = open("id_rsa.pub", 'w')
    public_key_file.write(public_key)
    public_key_file.close()
    # Start a sftp session and make it use the ssh key that we just pulled
    Net::SFTP.start(config_hash["hostname"], config_hash["username"], keys: ["id_rsa"], keys_only: true) do |sftp|
        # upload a file to the remote host
        sftp.upload!("/tmp/"+file, config_hash["destination"]+file)
    end
    return true
end

# this function is to send a notification to an sns topic
def send_sns_notification(sns_topic,subject,message)
    # create the sns client object
    client = Aws::SNS::Client.new(region: 'us-east-1')
    # publish the message to the sns topic
    resp = client.publish(topic_arn: sns_topic,
        message: message,
        subject: subject
    )
end
