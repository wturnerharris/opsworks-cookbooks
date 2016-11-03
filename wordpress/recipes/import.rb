# AWS OpsWorks Recipe to import WordPress files and database
# - Deploys 
# - Imports compressed tar files archive.
# - Imports compressed MySQL archive.

home = "/home/ec2-user"

# Create the Wordpress config file wp-config.php with corresponding values
node[:deploy].each do |app_name, deploy|
    
    Chef::Log.info("Importing files from backup...")
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
      not_if { ::File.exists?("#{home}/files_develop") }
    end

    # Import Wordpress database backup from file if it exists
    mysql_command = "/usr/bin/mysql -h #{deploy[:database][:host]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' :  "-p#{node[:mysql][:server_root_password]}"} #{deploy[:database][:database]}"

    Chef::Log.info("Importing Wordpress database from backup...")
    script "import_sql" do
      interpreter "bash"
      user "root"
      cwd "#{home}/"
      code <<-EOH
        HOME=#{home}
        FILE=$(ls -t entre*database.sql.gz | head -1)
        ROOT=#{deploy[:deploy_to]}/current
        WPCLI=`wp --info`

        if [ -f $FILE ]; then 
          #{mysql_command} < $FILE;
        fi;
        
        if ! type "$WPCLI" &>/dev/null; then 
          cd $HOME
          curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
          php wp-cli.phar --info
          chmod +x wp-cli.phar
          sudo mv wp-cli.phar /usr/local/bin/wp
        else
          cd $ROOT
          wp search-replace 'develop-entrepreneurs-roundtable-accelerator.pantheonsite.io' 'test.eranyc.com' --allow-root
          wp search-replace 'ec2-52-15-34-117.us-east-2.compute.amazonaws.com' 'test.eranyc.com' --allow-root
          wp search-replace 'era.dev' 'test.eranyc.com' --allow-root
          wp search-replace 'http://test.eranyc.com' 'https://test.eranyc.com' --allow-root
        fi

        EOH
    end

end