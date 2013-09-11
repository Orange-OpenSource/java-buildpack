require_relative 'gist'
require_relative 'json'


class Diagnostics

  def sample_and_post
    output_hash = create_initial_gist
    api_url = output_hash['url']
    html_url = output_hash['html_url']
    puts "gist will be accessible through #{html_url}"
    while true do
      output = `date;vmstat;ps -AF --cols=2000`
      update_gist(api_url, output)
      sleep 1
    end
  end

  # Create an initial gist that will be updated
  # @return the hash of gist response
  def create_initial_gist
    specifics = {
        :output => :all,
        :filename => filename()
    }
    options = base_options()
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
