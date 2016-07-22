require 'docker'
require 'open3'
require 'open-uri'
require 'jenkins_api_client'

# Global configs
$jenkins_compose_yml = 'docker-compose-jenkins.yml'
$data_compose_yml = 'docker-compose-datacontainers.yml'
def project_name(str = nil)
  str ||= File.basename(Dir.pwd)
  str.gsub(/[^0-9A-Za-z]/, '').downcase
end
$project_name = project_name

# String Colorization
class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def pink
    colorize(35)
  end
end

def get_containers_containing(dock_cons, containing)
  containers = []
  to_include = containing
  dock_cons.entries.each_with_index do |con, _index|
    name = con.json.to_hash['Name']
    next unless name.include?(to_include)
    containers << name
  end
  containers
end

def get_jenkins_host_ports(dock_cons_running, containing)
  containers = []
  to_include = containing
  dock_cons_running.entries.each_with_index do |con, _index|
    name = con.json.to_hash['Name']
    next unless name.include?(to_include)
    host_port = con.json['NetworkSettings']['Ports']['8080/tcp'].first['HostPort']
    containers << { 'name' => name, 'host_port' => host_port }
  end
  containers
end

def get_all_host_ports(dock_cons_running, containing)
  containers = []
  to_include = containing
  dock_cons_running.entries.each_with_index do |con, _index|
    name = con.json.to_hash['Name']
    next unless name.include?(to_include)
    forwarded_ports = con.json['NetworkSettings']['Ports'].select { |p, _| !con.json['NetworkSettings']['Ports'][p].nil? }
    forwarded_ports.keys.each do |port|
      host_port = forwarded_ports[port].first['HostPort']
      containers << { 'name' => name, 'host_port' => host_port }
    end
  end
  containers
end

def docker_host
  host = if ENV['DOCKER_HOST']
           ENV['DOCKER_HOST']
         else
           'http://127.0.0.1'
         end
  URI.parse(host).host
end

def construct_url(host, port)
  URI::HTTP.build(:host => host, :port => port.to_i).to_s
end

def get_jenkins_names(dock_cons)
  containing = "#{$project_name}_jenkins_"
  get_containers_containing(dock_cons, containing)
end

def get_jenkins_images(dock_imgs)
  jenkins_images = []
  to_include = "#{$project_name}_jenkins"
  dock_imgs.entries.each_with_index do |img, _index|
    name = img.json.to_hash['RepoTags'].first
    name = name.split(':')[0] unless name.nil?
    next unless name == to_include
    jenkins_images << name
  end
  jenkins_images
end

def get_non_proj_containers
  all_containers = Docker::Container.all(:all => true)
  all_containers.select { |container| container.info['Names'][0] !~ %r{/"#{$project_name}"_} }
end

def delete_containers(containers)
  containers.each do |c|
    c.stop if c.info['State'] == 'running'
    c.delete(:force => true)
  end
end

def delete_non_proj_containers
  delete_containers(get_non_proj_containers)
end

def delete_all_containers
  delete_containers(Docker::Container.all(:all => true))
end

def remove_untagged_images(dock_imgs)
  dock_imgs.entries.each do |img|
    name = img.json.to_hash['RepoTags'].first
    img.remove(:force => true) if name.nil?
  end
end

def jenkins_current_scale(jenkins_containers)
  jenkins_containers.map { |name| name.split('jenkins_')[1].to_i }.max
end

def jenkins_container_numbers(jenkins_containers)
  jenkins_containers.map { |name| name.rpartition('_').last.to_i }.sort
end

def jenkins_scale_down_logic(jenkins_containers, scale, action, prefix = "#{$project_name}_jenkins_")
  jenkins_containers = jenkins_containers.split unless jenkins_containers.is_a?(Array)
  jenkins_container_numbers(jenkins_containers)[scale..-1].each do |num_del|
    temp_name = prefix + num_del.to_s
    next unless jenkins_containers.include?("/#{temp_name}")
    temp_container = Docker::Container.get(temp_name)
    word_map = { 'stop' => { 'action' => 'stopping', 'color' => 'yellow' },
                 'delete' => { 'action' => 'deleting', 'color' => 'pink' } }
    puts "#{word_map[action]['action'].capitalize} #{temp_name}...".public_send(word_map[action]['color'])
    temp_container.public_send(action)
  end
end

def jenkins_scale_stop(jenkins_running, scale)
  jenkins_scale_down_logic(jenkins_running, scale, 'stop')
end

def jenkins_scale_delete(jenkins_containers, scale)
  jenkins_scale_down_logic(jenkins_containers, scale, 'delete')
end

def jenkins_data_scale_delete(jenkins_containers, scale)
  jenkins_scale_down_logic(jenkins_containers, scale, 'delete', "#{$project_name}_jenkins-data_")
end

def jenkins_up_to_scale(scale, jenkins_containers, jenkins_running, jenkins_link_services)
  success = true
  0.upto(scale - 1) do |loop_index|
    number = loop_index + 1
    jenkins_name = "#{$project_name}_jenkins_#{number}"
    next if jenkins_running.include?("/#{jenkins_name}")
    if jenkins_containers.include?("/#{jenkins_name}")
      cmd = "docker start #{jenkins_name}"
    else
      links = ''
      jenkins_link_services.each do |service|
        links << " --link #{service}"
      end
      cmd = "docker run#{links} -d -p 8080"\
            " --volumes-from #{$project_name}_jenkins-data_#{number}"\
            " --name #{jenkins_name} #{$project_name}_jenkins"
    end
    # result = system(cmd)
    result = execute_it(cmd)
    success &&= result
  end
  success
end

def jenkins_image_build(no_cache = false)
  params = ''
  params = ' --no-cache' if no_cache
  build_cmd = "docker-compose -f #{$jenkins_compose_yml} build#{params}"
  system(build_cmd)
end

def jenkins_data_image_build(no_cache = false)
  params = ''
  params = ' --no-cache' if no_cache
  params += " --build-arg host_in=#{URI::HTTP.build(:host => docker_host).to_s}"
  build_cmd = "docker-compose -f #{$data_compose_yml} build#{params}"
  build_cmd = "docker build -t #{$project_name}_jenkins-data#{params} dockerfiles/data/jenkins"
  system(build_cmd)
end

def jenkins_data_up
  cmd = "docker-compose -f #{$data_compose_yml} up -d"
  system(cmd)
end

def jenkins_data_scale(scale)
  cmd = "docker-compose -f #{$data_compose_yml}"\
        " scale jenkins-data=#{scale}"
  system(cmd)
end

def devops_up_the_rest
  cmd = 'docker-compose up -d'
  system(cmd)
end

def exterminate(dock_cons, dock_cons_running, del_data = false, containing = nil)
  containing ||= "#{$project_name}_"
  all_containers = get_containers_containing(dock_cons, containing)
  running_containers = get_containers_containing(dock_cons_running, containing)
  all_containers.each do |container|
    next if !del_data && container.include?("#{containing}jenkins-data_")
    temp_container = Docker::Container.get(container[1..-1])
    if running_containers.include?(container)
      puts "Stopping #{container[1..-1]}...".yellow
      temp_container.stop
    end
    puts "Deleting #{container[1..-1]}...".pink
    temp_container.delete
  end
  puts 'Finished.'.green
end

def pipeline_stop(running_containers, containing = nil)
  containing ||= "#{$project_name}_"
  stop_containers = get_containers_containing(running_containers, containing)
  stop_containers.each do |container|
    temp_container = Docker::Container.get(container[1..-1])
    puts "Stopping #{container[1..-1]}...".yellow
    temp_container.stop
  end
  puts 'Finished.'.green
end

def execute_it(cmd)
  exit_status = nil
  Open3.popen3(cmd) do |_stdin, _stdout, _stderr, wait_thr|
    exit_status = wait_thr.value
  end
  exit_status.success?
end

def full_generate_pipeline(dock_cons, dock_cons_running, dock_imgs, scale, jenkins_link_services)
  # If Jenkins images is empty we need to build a new image
  jenkins_images = get_jenkins_images(dock_imgs)
  jenkins_image_build if jenkins_images.empty?
  jenkins_containers = get_jenkins_names(dock_cons)
  jenkins_running = get_jenkins_names(dock_cons_running)
  # Once we know image exists, we can provision x number of Jenkins containers
  # and data containers
  devops_up_the_rest # Spin up artifactory, sonarqube, etc
  jenkins_data_up # provision the jenkins-data containers for "volumes-from"
  jenkins_data_scale(scale) # Scale if necessary
  jenkins_up_to_scale(scale, jenkins_containers, jenkins_running, jenkins_link_services) # Create a `docker start` or `docker run` for each
end

def jenkins_create(dock_cons, dock_cons_running, dock_imgs, scale, jenkins_link_services)
  # If Jenkins images is empty we need to build a new image
  jenkins_images = get_jenkins_images(dock_imgs)
  jenkins_image_build if jenkins_images.empty?

  jenkins_containers = get_jenkins_names(dock_cons)
  jenkins_running = get_jenkins_names(dock_cons_running)
  jenkins_data_up # provision the jenkins-data containers for "volumes-from"
  jenkins_data_scale(scale) # Scale if necessary
  jenkins_up_to_scale(scale, jenkins_containers, jenkins_running, jenkins_link_services) # Create a `docker start` or `docker run` for each
end

def init_jenkins_client(args)
  @jenkins_client = JenkinsApi::Client.new(:server_ip => args[:server_ip], :server_port => args[:server_port])
end

def jenkins_wait_for_ready
  @jenkins_client.system.wait_for_ready
end

def jobs_create_or_fix(job_name, xml = nil)
  xml ||= File.open(File.expand_path("dockerfiles/jenkins/files/job_configs/#{job_name}-config.xml", File.dirname(__FILE__))).read
  @jenkins_client.job.create_or_update(job_name, xml)
end

def includes_view(view_name)
  @jenkins_client.view.list.include?(view_name)
end

def config_delivery_pipeline(view_name)
  plugin_name = 'delivery-pipeline-plugin'
  unless @jenkins_client.plugin.list_installed.include?(plugin_name)
    @jenkins_client.plugin.install(plugin_name)
    @jenkins_client.system.restart(true) if @jenkins_client.plugin.restart_required?
    jenkins_wait_for_ready
  end
  initial_post_params = { 'name' => view_name, 'mode' => 'se.diabol.jenkins.pipeline.DeliveryPipelineView', "json" => { 'name' => view_name, 'mode' => 'se.diabol.jenkins.pipeline.DeliveryPipelineView', "componentSpecs"=>[{"name" => "Default", "firstJob"=>"github_root_project", "lastJob"=>""}]}.to_json}
  @jenkins_client.api_post_request('/createView', initial_post_params) unless includes_view(view_name)
  @jenkins_client.api_post_request("/view/#{view_name}/configSubmit", initial_post_params)
end



module SonarQube
  class Client
    attr_reader :host, :port, :api_endpoint, :api_token
    def initialize(options)
      options[:port] ||= 9000
      @host = options[:host]
      @port = options[:port]
      @api_endpoint = URI::HTTP.build(:host => options[:host], :port => options[:port], :path => '/api')
      @username = options[:username]
      @api_token = options[:api_token]
    end

    module Connection
      def http_request_base(input = nil)
        if input.is_a?(String)
          uri = URI.parse(input)
        elsif input.is_a?(Hash)
          uri = URI::HTTP.build(input)
        else
          uri = @api_endpoint
        end
        http = Net::HTTP.new(uri.host, uri.port)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if uri.scheme == 'https'
        http
      end

      def authorize_request(request)
        if @username && @password
          request.basic_auth(@username, @password)
        elsif @api_token
          request.basic_auth(@api_token, nil)
        end
        request
      end
    end

    module Languages
      def supported_languages
        http = http_request_base
        request = Net::HTTP::Get.new('/api/languages/list')
        response = http.request(request)
        response.body
      end
    end

    module System
      def system_status
        http = http_request_base
        request = Net::HTTP::Get.new('/api/system/status')
        response = http.request(request)
        response.body
      end

      def system_restart
        http = http_request_base
        request = Net::HTTP::Post.new('/api/system/restart')
        request = authorize_request(request)
        response = http.request(request)
        response.body
      end
    end

    module Plugins
      def installed_plugins(input = nil)
        http = http_request_base(input)
        request = Net::HTTP::Get.new('/api/plugins/installed')
        response = http.request(request)
        response.body
      end

      def available_plugins
        http = http_request_base
        request = Net::HTTP::Get.new('/api/plugins/available')
        response = http.request(request)
        response.body
      end

      def install_plugin(plugin_name)
        http = http_request_base
        request = Net::HTTP::Post.new("/api/plugins/install?key=#{plugin_name}")
        request = authorize_request(request)
        response = http.request(request)
        response.body
      end

      def uninstall_plugin(plugin_name)
        # requires restart to completely uninstall
        http = http_request_base
        request = Net::HTTP::Post.new("/api/plugins/uninstall?key=#{plugin_name}")
        request = authorize_request(request)
        response = http.request(request)
        response.body
      end
    end

    include SonarQube::Client::Connection
    include SonarQube::Client::Plugins
    include SonarQube::Client::Languages
    include SonarQube::Client::System
  end
end
# s = SonarQube::Client.new(:host => '192.168.59.103')
if __FILE__ == $0
  unless ARGV[0].nil?
    scale = ARGV[0].to_i

    dock_cons = Docker::Container.all(:all => true)
    dock_cons_running = Docker::Container.all(all: true, filters: { status: ['running'] }.to_json)
    dock_imgs = Docker::Image.all
    jenkins_link_services = %W( #{$project_name}_artifactory_1 #{$project_name}_sonarqube_1 )

    if ARGV[0].to_i > 0
      # If Jenkins images is empty we need to build a new image
      jenkins_images = get_jenkins_images(dock_imgs)
      jenkins_image_build if jenkins_images.empty?

      jenkins_containers = get_jenkins_names(dock_cons)
      jenkins_running = get_jenkins_names(dock_cons_running)

      # Once we know the image exists, we can provision x number of Jenkins
      # containers and data containers
      devops_up_the_rest # Spin up artifactory, sonarqube, etc
      jenkins_data_up # provision the jenkins-data containers for "volumes-from"
      jenkins_data_scale(scale) # Scale if necessary
      jenkins_up_to_scale(scale, jenkins_containers, jenkins_running, jenkins_link_services) # Create a `docker start` or `docker run` for each
      # Figure out Jenkins ports for 8080 and append to boot2docker
      # (or equivalent) open in default browser
      running_jenkins = get_jenkins_host_ports(dock_cons_running, "#{$project_name}_jenkins_")
      dock_host = docker_host
      running_jenkins.each do |jenkins|
        jenkins_url = contruct_jenkins_url(dock_host, jenkins['host_port'])
        puts "#{jenkins['name']} available at #{jenkins_url}".green
      end
    else
      exterminate(dock_cons, dock_cons_running) # If number passed in is 0 or if text, then stop/delete
    end
  end
end
