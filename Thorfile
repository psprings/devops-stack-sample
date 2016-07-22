require './jenkins_scale.rb'
require 'optparse'

begin
  Timeout.timeout(10) do
    $dock_cons = Docker::Container.all(:all => true)
    $dock_cons_running = Docker::Container.all(all: true, filters: { status: ['running'] }.to_json)
    $dock_imgs = Docker::Image.all
    $project_name = project_name
    $jenkins_link_services = %W( #{$project_name}_artifactory_1 #{$project_name}_sonarqube_1 )
  end
rescue Timeout::Error, Docker::Error::TimeoutError, Excon::Errors::SocketError, Excon::Errors::Timeout => exception
  puts 'ERROR - Cannot connect to Docker, make sure the service is started or boot2docker is running'.red + "\n"
  puts exception.to_s.red
  puts 'DOCKER CONNECTION DETAILS'.red + "\n====================\n".red
  puts Docker.connection.to_yaml.red + "\n============\n".red
end

# When `thor list` is run, all of the unusable jenkins_api_client Classes
# that inherit Thor are displayed. We will remove these to remove confusion
check_em = JenkinsApi::CLI.constants
check_em.each do |c|
  cl = Kernel.const_get("JenkinsApi::CLI::#{c}")
  cl.ancestors.each_with_index do |ancestor, index|
    next unless ancestor.to_s == 'Thor'
    mtr = cl.new.methods - cl.ancestors[index].new.methods
    next if mtr.empty?
    mtr.push('help') # if this is not included, jenkins_api will still print
    mtr.each do |m|
      cl.remove_task m
    end
  end
end


class Up < Thor
  desc 'generate_pipeline SCALE', 'Generate full DevOps pipeline with 1 Jenkins'
  method_option :scale, :aliases => '-s', :type => :numeric, :desc => 'Scale Jenkins to n number'
  def generate_pipeline(scale = options[:scale])
    scale ||= 1
    scale = scale.to_i
    puts "Scaling Jenkins to: #{scale}".yellow
    full_generate_pipeline($dock_cons, $dock_cons_running, $dock_imgs, scale, $jenkins_link_services)
    sleep(1 * scale)
    $dock_cons_running = Docker::Container.all(all: true, filters: { status: ['running'] }.to_json)
    puts "=========================\n#{'PIPELINE INFO'.blue}\n=========================\n"
    i = Info.new
    i.all_urls
    sleep(1 * scale)
    puts "=========================\n#{'CONFIGURING JENKINS'.yellow}\n=========================\n"
    u = Up.new
    loop do
      begin
        u.generate_jobs
        break
      rescue
        sleep(1 * scale)
      end
    end
  end
  desc 'generate_jobs', 'Generate/fix the base jobs needed for the pipeline'
  def generate_jobs
    running_jenkins = get_jenkins_host_ports($dock_cons_running, "#{$project_name}_jenkins_")
    dock_host = docker_host
    running_jenkins.each do |jenkins|
      init_jenkins_client({:server_ip => dock_host, :server_port => jenkins['host_port']})
      jenkins_wait_for_ready
      jobs = %w( github_root_project build_quality_sonar build_compile_maven )
      jobs.each do |job_name|
        jobs_create_or_fix(job_name)
      end
    end
    config_delivery_pipeline('Pipeline')
  end

  desc 'scale_jenkins SCALE', 'Make sure there are n Jenkins up'
  method_option :scale, :aliases => '-s', :type => :numeric, :desc => 'Scale Jenkins to n number'
  method_option :stop, :aliases => '-o', :desc => 'Stop any Jenkins containers above scale number'
  method_option :delete, :aliases => '-d', :desc => 'Stop and delete any Jenkins containers above scale number'
  method_option :include, :aliases => '-i', :desc => 'Include data containers in the deletion'
  def scale_jenkins(scale = nil, stop = nil, delete = nil)
    scale ||= options[:scale]
    stop = options[:stop] if options[:stop]
    delete = options[:delete] if options[:delete]
    d_include = options[:include] if options[:include]
    scale = scale.to_i
    puts "Scaling Jenkins to: #{scale}"
    jenkins_containers = get_jenkins_names($dock_cons)
    jenkins_running = get_jenkins_names($dock_cons_running)
    jenkins_data_containers = get_containers_containing($dock_cons, "#{$project_name}_jenkins-data_")
    if scale > jenkins_running.size
      jenkins_create($dock_cons, $dock_cons_running, $dock_imgs, scale, $jenkins_link_services)
    elsif !stop.nil? || !delete.nil?
      jenkins_scale_stop(jenkins_running, scale)
      unless delete.nil?
        jenkins_scale_delete(jenkins_containers, scale)
        jenkins_data_scale_delete(jenkins_data_containers, scale) unless d_include.nil?
      end
    else
      puts "#{jenkins_running.size} Jenkins containers already running"
      puts "\nTo decrease this number, pass the '-o' or '--stop' parameter".yellow
      puts "\nTo permanently delete, pass the '-d' or '--delete' parameter".pink
    end
  end

  desc 'proxy_fix', 'Check environment variables for existence of http_proxy/'\
                    'https_proxy and add to boot2docker profile if needed'
  def proxy_fix(del = true)
    checks = %w( http_proxy https_proxy )
    file_content = ''
    boot2docker_proxy = false
    checks.each do |check|
      proxy = ENV[check] || ENV[check].upcase
      file_content << "export #{check}=#{proxy}\n" if proxy
    end
    cmd = 'boot2docker --version'
    begin
      Open3.popen3(cmd)
    rescue Errno::ENOENT
      puts 'Proxy environment variables currently set, unset if you are '\
           'having proxy issues' if file_content
    end
    cmd = "boot2docker ssh \"sudo cat /var/lib/boot2docker/profile\""
    stdout = Open3.popen3(cmd)[1].read
    existing_contents = !stdout.empty?
    cmd = nil
    if existing_contents
      # Parse bash profile for env variables to hash
      variables = stdout.scan(%r(^export\s([\S]+)=([\S]+)\n)m).to_h
      # Check hash for existence of proxy environment variables
      checks.each do |check|
        boot2docker_proxy ||= variables.keys.map(&:upcase).member?(check.upcase)
      end
      if del
        cmd = 'boot2docker ssh '\
              "\"sudo cat /dev/null >| ./profile; "\
              "sudo mv ./profile /var/lib/boot2docker/profile\""
        puts "Proxy configuration currently set with:\n\n#{stdout}\n"\
             'Erasing contents...'
      else
        file_content = if boot2docker_proxy
                         "#{stdout}\n"
                       else
                         "#{stdout}\n#{file_content}"
                       end
        cmd = 'boot2docker ssh '\
              "\"cat > ./profile <<- EOM\n"\
              "#{file_content}"\
              "EOM\n"\
              "sudo mv ./profile /var/lib/boot2docker/profile\"" if file_content
        puts "Setting proxy configuration to:\n\n#{file_content}" if file_content
      end
    else
      cmd = 'boot2docker ssh '\
            "\"cat > ./profile <<- EOM\n"\
            "#{file_content}"\
            "EOM\n"\
            "sudo mv ./profile /var/lib/boot2docker/profile\"" if file_content
      puts "Setting proxy configuration to:\n\n#{file_content}" if file_content
    end
    if cmd
      wait_thr = Open3.popen3(cmd)[3]
      wait_thr.value.success?
    end
  end
end

class Destroy < Thor
  desc 'destroy_pipeline', 'Stop the full DevOps pipeline and delete containers'
  method_option :delete, :aliases => '-d', :desc => 'Delete the data containers'
  def destroy_pipeline
    del_data = true if options[:delete]
    exterminate($dock_cons, $dock_cons_running, del_data)
  end

  desc 'untagged_images', 'Clean up space by removing all untagged images'
  def untagged_images
    remove_untagged_images($dock_imgs)
  end
end

class Info < Thor
  desc 'jenkins_urls', 'Get the URLs for each running Jenkins container'
  def jenkins_urls
    running_jenkins = get_jenkins_host_ports($dock_cons_running, "#{$project_name}_jenkins_")
    dock_host = docker_host
    running_jenkins.each do |jenkins|
      jenkins_url = construct_url(dock_host, jenkins['host_port'])
      print "#{jenkins['name']} available at "
      puts "#{jenkins_url}".blue
    end
  end
  desc 'all_urls', 'Get the URLs for each running container'
  def all_urls
    running_containers = get_all_host_ports($dock_cons_running, "#{$project_name}_")
    dock_host = docker_host
    running_containers.each do |container|
      container_url = construct_url(dock_host, container['host_port'])
      print "#{container['name']} available at "
      puts "#{container_url}".blue
    end
  end
  desc 'containers', 'All containers that exist for the DevOps Stack'
  def containers
    cons = get_containers_containing($dock_cons, "#{$project_name}_")
    if cons.empty?
      puts "No #{$project_name} containers exist"
    else
      cons.each do |con|
        puts con
      end
    end
  end
  desc 'running_containers', 'Currently running containers that exist for the DevOps Stack'
  def running_containers
    cons = get_containers_containing($dock_cons_running, "#{$project_name}_")
    if cons.empty?
      puts "No #{$project_name} containers currently running"
    else
      cons.each do |con|
        puts con
      end
    end
  end
end

class Down < Thor
  desc 'stop_pipeline', 'Stop all running containers, give your computer a break'
  def stop_pipeline
    pipeline_stop($dock_cons_running)
  end
end

class Build < Thor
  desc 'jenkins_image', 'Build/rebuild jenkins_image(s)'
  method_option :no_cache, :aliases => '-n', :type => :boolean, :desc => 'Docker build with "--no-cache" flag'
  method_option :exclude, :aliases => '-e', :desc => 'Exclude data containers in the build/rebuild'
  def jenkins_image
    no_cache = if options[:no_cache]
                 true
               else
                 false
               end
    exclude = true if options[:exclude]
    puts "Building image: #{$project_name}_jenkins"
    jenkins_image_build(no_cache)
    unless exclude
      puts "Building image: #{$project_name}_jenkins-data"
      jenkins_data_image_build(no_cache)
    end
  end

  desc 'jenkins_data_image', 'Build/rebuild jenkins_data image'
  method_option :no_cache, :aliases => '-n', :type => :boolean, :desc => 'Docker build with "--no-cache" flag'
  def jenkins_data_image
    no_cache = if options[:no_cache]
                 true
               else
                 false
               end
    puts "Building image: #{$project_name}_jenkins-data"
    jenkins_data_image_build(no_cache)
  end
end
