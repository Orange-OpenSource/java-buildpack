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

require 'spec_helper'
require 'java_buildpack/container/jonas'

module JavaBuildpack::Container

  describe Jonas do

    JONAS_VERSION = JavaBuildpack::Util::TokenizedVersion.new('5.2.1')

    JONAS_DETAILS = [JONAS_VERSION, 'test-tomcat-uri']

    SUPPORT_VERSION = JavaBuildpack::Util::TokenizedVersion.new('1.0.+')

    SUPPORT_DETAILS = [SUPPORT_VERSION, 'test-support-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect WEB-INF' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
        .and_return(JONAS_DETAILS, SUPPORT_DETAILS)
      detected = Jonas.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect

      expect(detected).to eq('jonas-5.2.1')
    end

    it 'should not detect when WEB-INF is absent' do
      detected = Jonas.new(
          :app_dir => 'spec/fixtures/container_main',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should fail when a malformed version is detected' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JavaBuildpack::Util::TokenizedVersion.new('7.0.40_0')) if block }
        .and_return(JONAS_DETAILS, SUPPORT_DETAILS)
      expect { Jonas.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect }.to raise_error(/Malformed\ Tomcat\ version/)
    end

    it 'should extract Jonas and deployme from a GZipped TAR, override resources, create .jonas_base and remove extra large files' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
          .and_return(JONAS_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-jonas.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Jonas.new(
          :app_dir => root,
          :configuration => { }
        ).compile

        jonas_root = File.join root, '.jonas_root'
        expect(File.exists?(jonas_root)).to be_true

        jonas_base = File.join root, '.jonas_base'
        expect(File.exists?(jonas_base)).to be_true

        #catalina = File.join jonas_root, 'bin', 'catalina.sh'
        #expect(File.exists?(catalina)).to be_true

        #Filtered out
        context = File.join jonas_root, 'repositories/maven2-internal/org/ow2/jonas/jonas-admin/5.2.4/jonas-admin-5.2.4.war'
        expect(File.exists?(context)).to be_false

        #Not yet filtered out but present in stub
        context = File.join jonas_root, 'lib/client.jar'
        expect(File.exists?(context)).to be_true

        deployme_dir = File.join jonas_root, 'deployme'
        context = File.join deployme_dir, 'topology.xml.erb'
        expect(File.exists?(context)).to be_true

        deployme = File.join jonas_root, 'deployme/deployme.jar'
        expect(File.exists?(deployme)).to be_true
      end
    end

    it 'should link the application directory to the jonas_base/deploy directory' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
          .and_return(JONAS_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Jonas.new(
          :app_dir => root,
          :configuration => { }
        ).compile

        root_webapp = File.join root, '.jonas_base', 'deploy', 'ROOT'
        expect(File.exists?(root_webapp)).to be_true
        expect(File.symlink?(root_webapp)).to be_true
        expect(File.readlink(root_webapp)).to eq('../..')
      end
    end

    it 'should link additional libraries to the ROOT webapp' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join root, 'WEB-INF'
        lib_directory = File.join root, '.lib'
        FileUtils.mkdir_p lib_directory

        Dir['spec/fixtures/additional_libs/*'].each { |file| system "cp #{file} #{lib_directory}" }

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
          .and_return(JONAS_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Jonas.new(
          :app_dir => root,
          :lib_directory => lib_directory,
          :configuration => { }
        ).compile

        lib = File.join root, '.tomcat', 'webapps', 'ROOT', 'WEB-INF', 'lib'
        test_jar_1 = File.join lib, 'test-jar-1.jar'
        test_jar_2 = File.join lib, 'test-jar-2.jar'
        test_text = File.join lib, 'test-text.txt'

        expect(File.exists?(test_jar_1)).to be_true
        expect(File.symlink?(test_jar_1)).to be_true
        expect(File.readlink(test_jar_1)).to eq('../../.lib/test-jar-1.jar')

        expect(File.exists?(test_jar_2)).to be_true
        expect(File.symlink?(test_jar_2)).to be_true
        expect(File.readlink(test_jar_2)).to eq('../../.lib/test-jar-2.jar')

        expect(File.exists?(test_text)).to be_false
      end
    end

    it 'should return command' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
        .and_return(JONAS_DETAILS, SUPPORT_DETAILS)

      command = Jonas.new(
        :app_dir => 'spec/fixtures/container_jonas',
        :java_home => 'test-java-home',
        :java_opts => [ 'test-opt-2', 'test-opt-1' ],
        :configuration => {}).release


      javaenv_cmd = 'JAVA_HOME=test-java-home JAVA_OPTS="-Dhttp.port=$PORT test-opt-1 test-opt-2" '
      deployme_cmd = 'JONAS_ROOT=.jonas_root JONAS_BASE=.jonas_base;'+
                     'export JONAS_ROOT JONAS_BASE JAVA_HOME JAVA_OPTS;' +
                     'erb .jonas_root/deployme/topology.xml.erb > .jonas_root/deployme/topology.xml && ' +
                     '$JAVA_HOME/bin/java -jar .jonas_root/deployme/deployme.jar -topologyFile=.jonas_root/deployme/topology.xml -domainName=singleDomain -serverName=singleServerName && '
      linkapp_cmd=   'ln -sf ../.. .jonas_base/deploy/app && '
      containerstart_cmd = 'source .jonas_base/setenv && jonas start -fg'
      expect(command).to eq(javaenv_cmd + deployme_cmd + linkapp_cmd + containerstart_cmd)
    end

  end

end
