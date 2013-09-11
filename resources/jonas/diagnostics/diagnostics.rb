require_relative 'gist'
require_relative 'json'


class Diagnostics

  def sample_and_post
    output_hash = create_initial_gist
    api_url = output_hash['url']
    html_url = output_hash['html_url']
    puts "gist will be accessible through #{html_url} and collecting #{cmd}"
    while true do
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        update_gist(api_url, stderr.read + stdout.read)
      end
      sleep 1
    end
  end

  def cmd
    ENV['DEBUG_TOGIST_CMD'] || 'date;vmstat;ps -AF --cols=2000;vmstat -s'
  end

  # Create an initial gist that will be updated
  # @return the hash of gist response
  def create_initial_gist
    specifics = {
        :filename => filename()
    }
    options = base_options().merge specifics
    Gist.gist('my content', options)
  end

  def filename
    json = JSON.parse(ENV['VCAP_APPLICATION'])
    #-#{json['name']}
    "'diagnostics-Index#{json['instance_index']}-Id#{json['instance_id']}-Start#{json['start']}"
  end

  def base_options
    {:access_token => ENV['DEBUG_TOGIST_TOKEN'],
     :private => true,
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
