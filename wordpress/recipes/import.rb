# AWS OpsWorks Recipe for Wordpress to be executed during the Configure lifecycle phase
# - Creates the config file wp-config-local.php with MySQL data.
# - Creates a Cronjob.
# - Imports a database backup if it exists.

require 'aws-sdk'

s3 = AWS::S3.new
s3_bucket = node[:wordpress][:s3]

# Set bucket and object name
obj = s3.buckets[ s3_bucket ].objects.with_prefix('db').collect(&:key)
obj.each do |options, block|
    # Read content to variable
    file_content = block.read

    # Log output (optional)
    Chef::Log.info(file_content)

    # Write content to file
    file '/tmp/import.sql' do
      owner 'root'
      group 'root'
      mode '0755'
      content file_content
      action :create
    end
end