require_relative 'gist'
require_relative 'json'

#module JavaBuildpack::Container

  class JonasDiagnostics

    def main
      if ENV['DEBUG_TOGIST']
        sample_and_post_forever
      else
        puts 'Diagnostics disabled'
      end
    end

    def sample_and_post_forever
      output_hash = create_initial_gist
      api_url = output_hash['url']
      html_url = output_hash['html_url']
      puts "gist will be accessible through #{html_url} and collecting #{cmd}"

      sample=0
      start = Time.now
      while true do
        elapsed = Time.now - start

        sample_and_post(api_url, sample, elapsed)
        sleep 1
        sample+=1
      end
    end

    def sample_and_post(api_url, sample, elapsed)
      ps_cmd_output = execute_cmd(cmd)
      pid = extract_largest_pid(ps_cmd_output)
      expanded_pid_cmd = process_cmd % {:largest_process_pid => pid}
      largest_process_detail = execute_cmd(expanded_pid_cmd)

      update_gist(api_url, "Sample #{sample}, elapsed #{elapsed} seconds\n#{cmd}:\n#{ps_cmd_output}\n\n#{expanded_pid_cmd}:\n#{largest_process_detail}\n")
    end

    def execute_cmd(cmd_string)
      f = IO.popen(cmd_string, :err => [:child, :out] )
      cmd_output = f.readlines
      f.close
      cmd_output.join
    end

    def cmd
      ENV['DEBUG_TOGIST_CMD'] || 'date;ps -AFH --cols=2000'
    end
    def process_cmd
      ENV['DEBUG_TOGIST_PROCESS_CMD'] || 'cat /proc/%{largest_process_pid}/status'
    end

    # Create an initial gist that will be updated
    # @return the hash of gist response
    def create_initial_gist
      specifics = {
      }
      initial_cmd = 'cgget -r cpuset.cpus -r memory.limit_in_bytes; free'
      initial_content = "tracing with cmd #{cmd} followed by #{process_cmd} \nAlso #{initial_cmd} returns:\n#{execute_cmd(initial_cmd)}"

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

    def extract_largest_pid(ps_cmd_output)
      largest_rss = 0
      largest_pid = nil
      ps_cmd_output.each_line do |line|
        line.strip!
        if line =~ /^vcap/
          user, pid, ppid, c, sz, rss, psr, stime, tty, time, cmd =line.chomp.split(/\s+/)
          if rss.to_i > largest_rss
            largest_pid = pid
            largest_rss = rss.to_i
          end
        end
      end
      largest_pid
    end

  end

#end



