require './jenkins_scale.rb'
require 'optparse'

$dock_cons = Docker::Container.all(:all => true)
$dock_cons_running = Docker::Container.all(all: true, filters: { status: ['running'] }.to_json)
$dock_imgs = Docker::Image.all
$jenkins_link_services = %w( devopsstack_artifactory_1 devopsstack_sonarqube_1 )

class Up < Thor
  desc "generate_pipeline SCALE", "Generate full DevOps pipeline with 1 Jenkins"
  method_option :scale, :aliases => "-s", :desc => "Scale Jenkins to n number"
  def generate_pipeline(scale = 1)
    scale ||= options[:scale]
    scale = scale.to_i
    puts "Scaling Jenkins to: #{scale}"
    full_generate_pipeline($dock_cons, $dock_cons_running, $dock_imgs, scale, $jenkins_link_services)
  end

  desc "scale_jenkins SCALE", "Make sure there are n Jenkins up"
  method_option :scale, :aliases => "-s", :desc => "Scale Jenkins to n number"
  method_option :stop, :aliases => "-o", :desc => "Stop any Jenkins containers above scale number"
  method_option :delete, :aliases => "-d", :desc => "Stop and delete any Jenkins containers above scale number"
  method_option :include, :aliases => "-i", :desc => "Include data containers in the deletion"
  def scale_jenkins(scale = nil, stop = nil, delete = nil)
    scale ||= options[:scale]
    stop = options[:stop] if options[:stop]
    delete = options[:delete] if options[:delete]
    d_include = options[:include] if options[:include]
    scale = scale.to_i
    puts "Scaling Jenkins to: #{scale}"
    jenkins_containers = get_jenkins_names($dock_cons)
    jenkins_running = get_jenkins_names($dock_cons_running)
    jenkins_data_containers = get_containers_containing($dock_cons, 'devopsstack_jenkins-data_')
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
end

class Destroy < Thor
  desc "destroy_pipeline", "Stop the full DevOps pipeline and delete containers"
  method_option :delete, :aliases => "-d", :desc => "Delete the data containers"
  def destroy_pipeline
    del_data = true if options[:delete]
    exterminate($dock_cons, $dock_cons_running, del_data)
  end
end

class Info < Thor
  desc "jenkins_urls", "Get the URLs for each running Jenkins container"
  def jenkins_urls
    running_jenkins = get_jenkins_host_ports($dock_cons_running, 'devopsstack_jenkins_')
    dock_host = docker_host
    running_jenkins.each do |jenkins|
      jenkins_url = contruct_jenkins_url(dock_host, jenkins['host_port'])
      print "#{jenkins['name']} available at "
      puts "#{jenkins_url}".blue
    end
  end
  desc "containers", "All containers that exist for the DevOps Stack"
  def containers
    get_containers_containing($dock_cons, 'devopsstack_').each do |con|
      puts con
    end
  end
  desc "running_containers", "Currently running containers that exist for the DevOps Stack"
  def running_containers
    get_containers_containing($dock_cons_running, 'devopsstack_').each do |con|
      puts con
    end
  end
end

class Down < Thor
  desc "stop_pipeline", "Stop all running containers, give your computer a break"
  def stop_pipeline
    pipeline_stop($dock_cons_running)
  end
end
