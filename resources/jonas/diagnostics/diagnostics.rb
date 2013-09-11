require_relative 'gist'


class Diagnostics

  def sample_and_post
    gist_url = create_initial_gist
    puts "gist will be accessible through #{gist_url}"
    while true do
      output = `vmstat;ps -ef`
      update_gist(gist_url, output)
      sleep 1
    end
  end

  # Create an initial gist that will be updated
  # @return the url or id of a gist to update
  def create_initial_gist
    options = base_options()
    Gist.gist('my content', options)
  end

  def base_options
    {:access_token => ENV['DEBUG_TOGIST_TOKEN'],
     :public => false,
    }
  end

  def update_gist(gist_url, content)
    specifics = {:update => gist_url}
    options = base_options.merge specifics
    Gist.gist(content, options)
  end

end