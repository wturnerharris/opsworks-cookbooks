# AWS OpsWorks Recipe for Wordpress to be executed during the Configure lifecycle phase
# - Creates the config file wp-config-local.php with MySQL data.
# - Creates a Cronjob.
# - Imports a database backup if it exists.

require 'uri'
require 'net/http'
require 'net/https'

uri = URI.parse("https://api.wordpress.org/secret-key/1.1/salt/")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)
keys = response.body
home = "/home/ec2-user"

# Create the Wordpress config file wp-config.php with corresponding values
node[:deploy].each do |app_name, deploy|

    template "#{deploy[:deploy_to]}/current/wp-config-local.php" do
        source "wp-config-local.php.erb"
        mode 0660
        group deploy[:group]

        if platform?("ubuntu")
          owner "www-data"
        elsif platform?("amazon")
          owner "apache"
        end

        variables(
            :database   => (deploy[:database][:database] rescue nil),
            :user       => (deploy[:database][:username] rescue nil),
            :password   => (deploy[:database][:password] rescue nil),
            :host       => (deploy[:database][:host] rescue nil),
            :keys       => (keys rescue nil)
        )
    end

    Chef::Log.debug("Deploying .htaccess template...")
    template "#{deploy[:deploy_to]}/current/.htaccess" do
        source "htaccess.erb"
        mode 0660
        group deploy[:group]

        if platform?("ubuntu")
          owner "www-data"
        elsif platform?("amazon")
          owner "apache"
        end
    end
    
    Chef::Log.debug("Importing files from backup...")
    script 'deploy_files' do
      interpreter "bash"
      user "root"
      cwd "#{home}/"
      code <<-EOH
        HOME=#{home}
        FILE=$(ls -t entre*files.tar.gz | head -1)
        ROOT=#{deploy[:deploy_to]}/current

        cd $HOME
        pwd
        tar -xvzf $FILE
        ls -la
        rm -rf $ROOT/wp-content/uploads
        mv $HOME/files_develop $ROOT/wp-content/uploads
        ls -la
        
        EOH
      not_if { ::File.exists?("/home/ec2-user/files_develop") }
    end

    # Import Wordpress database backup from file if it exists
    mysql_command = "/usr/bin/mysql -h #{deploy[:database][:host]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' :  "-p#{node[:mysql][:server_root_password]}"} #{deploy[:database][:database]}"

    Chef::Log.debug("Importing Wordpress database from backup...")
    script "import_sql" do
      interpreter "bash"
      user "root"
      cwd "#{home}/"
      code <<-EOH
        HOME=#{home}
        FILE=$(ls -t entre*database.sql.gz | head -1)

        if [ -f $FILE ]; then 
          #{mysql_command} < $FILE;
          rm $FILE;
        fi;

        EOH
    end

end

# Create a Cronjob for Wordpress
cron "wordpress" do
  hour "*"
  minute "*/15"
  weekday "*"
  command "wget -q -O - http://localhost/wp-cron.php?doing_wp_cron >/dev/null 2>&1"
end
