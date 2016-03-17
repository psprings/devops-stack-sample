require 'docker'
require 'open3'

$jenkins_compose_yml = 'docker-compose-jenkins.yml'
$data_compose_yml = 'docker-compose-datacontainers.yml'

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

def get_jenkins_names(dock_cons)
  containing = 'devopsstack_jenkins_'
  get_containers_containing(dock_cons, containing)
end

def get_jenkins_images(dock_imgs)
  jenkins_images = []
  to_include = 'devopsstack_jenkins'
  dock_imgs.entries.each_with_index do |img, _index|
    name = img.json.to_hash['RepoTags'].first.split(':')[0]
    next unless name.include?(to_include)
    jenkins_images << name
  end
  jenkins_images
end

def jenkins_current_scale(jenkins_containers)
  jenkins_containers.map { |name| name.split('jenkins_')[1].to_i }.max
end

def jenkins_up_to_scale(scale, jenkins_containers, jenkins_running, jenkins_link_services)
  success = true
  0.upto(scale - 1) do |loop_index|
    number = loop_index + 1
    jenkins_name = "devopsstack_jenkins_#{number}"
    next if jenkins_running.include?("/#{jenkins_name}")
    if jenkins_containers.include?("/#{jenkins_name}")
      cmd = "docker start #{jenkins_name}"
    else
      links = ''
      jenkins_link_services.each do |service|
        links << " --link #{service}"
      end
      cmd = "docker run#{links} -d -p 8080"\
            " --volumes-from devopsstack_jenkins-data_#{number}"\
            " --name #{jenkins_name} devopsstack_jenkins"
    end
    result = system(cmd)
    success &&= result
  end
  success
end

def jenkins_image_build(no_cache = false)
  params = ''
  params = ' --no-cache' if no_cache
  build_cmd = "docker-compose -f #{$jenkins_compose_yml} build#{params} -d"
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

def exterminate(dock_cons, dock_cons_running, del_data = false)
  containing = 'devopsstack_'
  all_containers = get_containers_containing(dock_cons, containing)
  running_containers = get_containers_containing(dock_cons_running, containing)
  all_containers.each do |container|
    next if !del_data && container.include?('devopsstack_jenkins-data_')
    temp_container = Docker::Container.get(container[1..-1])
    if running_containers.include?(container)
      puts "Stopping #{container[1..-1]}..."
      temp_container.stop
    end
    puts "Deleting #{container[1..-1]}..."
    temp_container.delete
  end
  puts 'Finished.'
end

def execute_it(cmd)
  exit_status = nil
  Open3.popen3(cmd) do |_stdin, _stdout, _stderr, wait_thr|
    exit_status = wait_thr.value
  end
  exit_status.success?
end

scale = ARGV[0].to_i
scale ||= 1

dock_cons = Docker::Container.all(:all => true)
dock_cons_running = Docker::Container.all(all: true, filters: { status: ['running'] }.to_json)
dock_imgs = Docker::Image.all
jenkins_link_services = %w( devopsstack_artifactory_1 devopsstack_sonarqube_1 )

if ARGV[0].to_i > 0
  # If Jenkins images is empty we need to build a new image
  jenkins_images = get_jenkins_images(dock_imgs)
  jenkins_image_build if jenkins_images.empty?

  jenkins_containers = get_jenkins_names(dock_cons)
  jenkins_running = get_jenkins_names(dock_cons_running)

  # Once we know the image exists, we can provision x number of Jenkins containers
  # and data containers
  devops_up_the_rest # Spin up artifactory, sonarqube, etc
  jenkins_data_up # provision the jenkins-data containers for "volumes-from"
  jenkins_data_scale(scale) # Scale if necessary
  jenkins_up_to_scale(scale, jenkins_containers, jenkins_running, jenkins_link_services) # Create a `docker start` or `docker run` for each
  # Figure out Jenkins ports for 8080 and append to boot2docker (or equivalent)
  # open in default browser
else
  exterminate(dock_cons, dock_cons_running) # If number passed in is 0 or if text, then stop/delete
end
