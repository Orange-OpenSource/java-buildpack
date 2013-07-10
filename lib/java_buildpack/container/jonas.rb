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
      @deployme_version, @deployme_uri = Jonas.find_deployme(@app_dir, @configuration)

      if @java_opts
        @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"
      else
        @java_opts = []
      end
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
      download_deployme
      puts 'Compile completed, release cmd to be run:'
      puts release
    end

    # Creates the command to run the Tomcat application.
    #
    # @return [String] the command to run the application.
    def release
      app_war_file = File.join JONAS_BASE, 'deploy' , 'app.war'
      if_jonas_base_exists_string = "(if test ! -d #{app_war_file} ; then"
      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string        = "JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\""
      export_base_vars_string     = "export JAVA_HOME JAVA_OPTS"
      export_deployme_vars_string     = "export JONAS_ROOT JONAS_BASE"
      deployme_var_string     = "JONAS_ROOT=#{JONAS_ROOT} JONAS_BASE=#{JONAS_BASE}"
      deployme_root = File.join JONAS_ROOT, 'deployme'
      topology_xml_erb_file = File.join deployme_root, 'topology.xml.erb'
      topology_xml_file = File.join deployme_root, 'topology.xml'
      deployme_jar_file = File.join deployme_root, 'deployme.jar'
      topology_erb_cmd_string = "erb #{topology_xml_erb_file} > #{topology_xml_file}"
      deployme_cmd_string     = "$JAVA_HOME/bin/java -jar #{deployme_jar_file} -topologyFile=#{topology_xml_file} -domainName=singleDomain -serverName=singleServerName"
      else_skip_string        = 'else echo "skipping jonas_base config as already present"; fi)'
      setenv_cmd_string = File.join JONAS_BASE, 'setenv'
      copyapp_cmd=   "mkdir -p #{app_war_file} && cp -r --dereference * #{app_war_file}/"
      start_script_string     = "source #{setenv_cmd_string} && jonas start -fg"

      "#{java_home_string} #{java_opts_string} && #{export_base_vars_string} && #{if_jonas_base_exists_string} #{deployme_var_string} && #{export_deployme_vars_string} && #{topology_erb_cmd_string} && #{deployme_cmd_string} && #{copyapp_cmd}; #{else_skip_string} && #{start_script_string}"
    end

    private

    KEY_HTTP_PORT = 'http.port'.freeze

    KEY_SUPPORT = 'support'.freeze

    RESOURCES = File.join('..', '..', '..', 'resources', 'jonas').freeze

    TOMCAT_HOME = '.tomcat'.freeze
    JONAS_ROOT = '.jonas_root'.freeze
    JONAS_BASE = '.jonas_base'.freeze

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

    def download_deployme
      download_start_time = Time.now
      print "-----> Downloading deployme#{@deployme_version} from #{@deployme_uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@deployme_uri) do |file|  # TODO Use global cache #50175265
        system "cp #{file.path} #{File.join jonas_root, 'deployme', 'deployme.jar'}"
        puts "(#{(Time.now - download_start_time).duration})"
      end
    end

    def expand(file, configuration)
      expand_start_time = Time.now
      print "-----> Expanding Jonas to #{JONAS_ROOT} "

      system "rm -rf #{jonas_root}"
      system "mkdir -p #{jonas_root}"
      system "rm -rf #{jonas_base}"
      system "mkdir -p #{jonas_base}"
      system "tar xzf #{file.path} -C #{jonas_root} --strip 1 --exclude webapps --exclude deploy/jonasAdmin.xml --exclude repositories/maven2-internal/org/ow2/jonas/jonas-admin --exclude deploy/doc.xml --exclude repositories/maven2-internal/org/ow2/jonas/documentation  --exclude webapps --exclude #{File.join 'conf', 'server.xml'} --exclude #{File.join 'conf', 'context.xml'} 2>&1"

      copy_resources jonas_root
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

    def self.find_deployme(app_dir, configuration)
      if web_inf? app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration["deployme"])
      else
        version = nil
        uri = nil
      end

      return version, uri
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


    def root
      File.join jonas_deploy, 'ROOT'
    end

    def jonas_root
      File.join @app_dir, JONAS_ROOT
    end
    def jonas_base
      File.join @app_dir, JONAS_BASE
    end

    def tomcat_home
      File.join @app_dir, TOMCAT_HOME
    end

    def jonas_deploy
      File.join jonas_base, 'deploy'
    end

    def self.web_inf?(app_dir)
      File.exists? File.join(app_dir, WEB_INF_DIRECTORY)
    end

  end

end
