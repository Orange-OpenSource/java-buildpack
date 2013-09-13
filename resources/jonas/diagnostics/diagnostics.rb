require_relative 'gist'
require_relative 'json'

class Diagnostics

  def main
    if ENV['DEBUG_TOGIST']
      sample_and_post
    else
      puts 'Diagnostics disabled'
    end
  end

  def sample_and_post
    output_hash = create_initial_gist
    api_url = output_hash['url']
    html_url = output_hash['html_url']
    puts "gist will be accessible through #{html_url} and collecting #{cmd}"

    sample=0
    start = Time.now
    while true do
      cmd_output = execute_cmd(cmd)

      elapsed = Time.now - start
      update_gist(api_url, "Sample #{sample}, elapsed #{elapsed} seconds \n" + cmd_output)
      sleep 1
      sample+=1
    end
  end

  def execute_cmd(cmd_string)
    f = IO.popen([cmd_string, :err=>[:child, :out]])
    cmd_output = f.readlines
    f.close
    cmd_output.join
  end

  def cmd
    ENV['DEBUG_TOGIST_CMD'] || 'date;vmstat;ps -AFH --cols=2000;free'
  end

  # Create an initial gist that will be updated
  # @return the hash of gist response
  def create_initial_gist
    specifics = {
    }
    initial_cmd = 'cgget -r cpuset.cpus -r memory.limit_in_bytes; free'
    initial_content = "tracing with cmd #{cmd} \nAlso #{initial_cmd} returns:\n#{execute_cmd(initial_cmd)}"

    options = base_options().merge specifics
    Gist.gist(initial_content, options)
  end

  def filename
    vcap_app = ENV['VCAP_APPLICATION']
    if vcap_app
      json = JSON.parse(vcap_app)
      #-#{json['name']}
      "diagnostics-Index#{json['instance_index']}-Id#{json['instance_id']}-Start#{json['start']}"
    else
      "filename"
    end
  end

  def base_options
    {:access_token => ENV['DEBUG_TOGIST_TOKEN'],
     :private => true,
     :filename => filename()
    }
  end

  def update_gist(gist_url, content)
    specifics = {:update => gist_url}
    options = base_options.merge specifics
    Gist.gist(content, options)
  end

end


diagnostics = Diagnostics.new
diagnostics.sample_and_post
