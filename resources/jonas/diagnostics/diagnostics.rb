require_relative 'gist'


class Diagnostics

  def sample_and_post
    output_hash = create_initial_gist
    api_url = output_hash['url']
    html_url = output_hash['html_url']
    puts "gist will be accessible through #{html_url}"
    while true do
      output = `vmstat;ps -ef`
      update_gist(api_url, output)
      sleep 1
    end
  end

  # Create an initial gist that will be updated
  # @return the hash of gist response
  def create_initial_gist
    specifics = {:output => :all}
    options = base_options()
    Gist.gist('my content', options)
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
