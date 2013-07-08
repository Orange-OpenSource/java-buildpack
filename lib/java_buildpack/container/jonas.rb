# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Jonas applications.
  class Jonas

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @jonas_version, @tomcat_uri = Jonas.find_tomcat(@app_dir, @configuration)
      @support_version, @support_uri = Jonas.find_support(@app_dir, @configuration)
    end

    # Detects whether this application is a Tomcat application.
    #
    # @return [String] returns +tomcat-<version>+ if and only if the application has a +WEB-INF+ directory, otherwise
    #                  returns +nil+
    def detect
      @jonas_version ? id(@jonas_version) : nil
    end

    # Downloads and unpacks a Tomcat instance and support JAR
    #
    # @return [void]
    def compile
      download_jonas
      link_application
      link_libs
    end

    # Creates the command to run the Tomcat application.
    #
    # @return [String] the command to run the application.
    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"

      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      start_script_string = ContainerUtils.space(File.join TOMCAT_HOME, 'bin', 'catalina.sh')

      "#{java_home_string}#{java_opts_string}#{start_script_string} run"
    end

    private

    KEY_HTTP_PORT = 'http.port'.freeze

    KEY_SUPPORT = 'support'.freeze

    RESOURCES = File.join('..', '..', '..', 'resources', 'jonas').freeze

    TOMCAT_HOME = '.tomcat'.freeze

    WEB_INF_DIRECTORY = 'WEB-INF'.freeze

    def copy_resources(tomcat_home)
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      system "cp -r #{File.join resources, '*'} #{tomcat_home}"
    end

    def download_jonas
      download_start_time = Time.now
      print "-----> Downloading Jonas #{@jonas_version} from #{@tomcat_uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@tomcat_uri) do |file|  # TODO Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        expand(file, @configuration)
      end
    end

    def expand(file, configuration)
      expand_start_time = Time.now
      print "-----> Expanding Jonas to #{TOMCAT_HOME} "

      system "rm -rf #{tomcat_home}"
      system "mkdir -p #{tomcat_home}"
      system "tar xzf #{file.path} -C #{tomcat_home} --strip 1 --exclude webapps --exclude deploy/jonasAdmin.xml --exclude repositories/maven2-internal/org/ow2/jonas/jonas-admin --exclude deploy/doc.xml --exclude repositories/maven2-internal/org/ow2/jonas/documentation  --exclude webapps --exclude #{File.join 'conf', 'server.xml'} --exclude #{File.join 'conf', 'context.xml'} 2>&1"

      copy_resources tomcat_home
      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_tomcat(app_dir, configuration)
      if web_inf? app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration) do |version|
          raise "Malformed Tomcat version #{version}: too many version components" if version[3]
        end
      else
        version = nil
        uri = nil
      end

      return version, uri
    rescue => e
      raise RuntimeError, "Tomcat container error: #{e.message}", e.backtrace
    end

    def self.find_support(app_dir, configuration)
      if web_inf? app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration[KEY_SUPPORT])
      else
        version = nil
        uri = nil
      end

      return version, uri
    end

    def id(version)
      "jonas-#{version}"
    end

    def link_application
      system "rm -rf #{root}"
      system "mkdir -p #{webapps}"
      system "ln -s #{File.join '..', '..'} #{root}"
    end

    def link_libs
      libs = ContainerUtils.libs(@app_dir, @lib_directory)

      if libs
        FileUtils.mkdir_p(web_inf_lib) unless File.exists?(web_inf_lib)
        libs.each { |lib| system "ln -s #{File.join '..', '..', lib} #{web_inf_lib}" }
      end
    end

    def root
      File.join webapps, 'ROOT'
    end

    def tomcat_home
      File.join @app_dir, TOMCAT_HOME
    end

    def webapps
      File.join tomcat_home, 'webapps'
    end

    def web_inf_lib
      File.join root, 'WEB-INF', 'lib'
    end

    def self.web_inf?(app_dir)
      File.exists? File.join(app_dir, WEB_INF_DIRECTORY)
    end

  end

end
