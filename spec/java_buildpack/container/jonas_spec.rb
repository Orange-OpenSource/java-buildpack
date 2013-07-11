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

    JONAS_SUPPORT_DETAILS = [SUPPORT_VERSION, 'test-support-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect WEB-INF' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
        .and_return(JONAS_DETAILS, JONAS_SUPPORT_DETAILS)
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
        .and_return(JONAS_DETAILS, JONAS_SUPPORT_DETAILS)
      expect { Jonas.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect }.to raise_error(/Malformed\ Tomcat\ version/)
    end

    it 'should remove jcl-over-slf4 jars from WEB-INF/lib as it conflicts with jonas embedded slf4j-jcl' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
        .and_return(JONAS_DETAILS, JONAS_SUPPORT_DETAILS)


        dir = File.join(root, 'WEB-INF', 'lib')
        Dir.mkdir dir
        touch(dir, 'jcl-over-slf4j.jar')
        touch(dir, 'jcl-over-slf4j-1.5.10.jar')
        touch(dir, 'random.jar')

        command = Jonas.new(
            :app_dir => root,
            :java_home => 'test-java-home',
            :java_opts => [ 'test-opt-2', 'test-opt-1' ],
            :configuration => {}).remove_jcl_over_slf


        expected_deleted_jars = Dir.glob(File.join dir, 'jcl-over-slf4*.jar')

        expected_random_file_untouched = Dir.glob(File.join dir, 'random.jar')

        expect(expected_random_file_untouched).to_not be_empty
        expect(expected_deleted_jars).to be_empty
      end
    end

    it 'should extract Jonas and deployme from a GZipped TAR, override resources, create .jonas_base and remove extra large files' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
          .and_return(JONAS_DETAILS, JONAS_SUPPORT_DETAILS)

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

    it 'should return command' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JONAS_VERSION) if block }
        .and_return(JONAS_DETAILS, JONAS_SUPPORT_DETAILS)

      command = Jonas.new(
        :app_dir => 'spec/fixtures/container_jonas',
        :java_home => 'test-java-home',
        :java_opts => [ 'test-opt-2', 'test-opt-1' ],
        :configuration => {}).release


      javaenv_cmd = 'JAVA_HOME=test-java-home JAVA_OPTS="-Dhttp.port=$PORT test-opt-1 test-opt-2" && ' +
                    'export JAVA_HOME JAVA_OPTS && '
      deployme_cmd = '(if test ! -d .jonas_base/deploy/app.war ; then ' +
                     'JONAS_ROOT=.jonas_root JONAS_BASE=.jonas_base && '+
                     'export JONAS_ROOT JONAS_BASE && ' +
                     'erb .jonas_root/deployme/topology.xml.erb > .jonas_root/deployme/topology.xml && ' +
                     '$JAVA_HOME/bin/java -jar .jonas_root/deployme/deployme.jar -topologyFile=.jonas_root/deployme/topology.xml -domainName=singleDomain -serverName=singleServerName && ' +
                     'mkdir -p .jonas_base/deploy/app.war && cp -r --dereference * .jonas_base/deploy/app.war/; '+
                     'else echo "skipping jonas_base config as already present"; fi) && '
      containerstart_cmd = 'source .jonas_base/setenv && jonas start -fg'
      expect(command).to eq(javaenv_cmd + deployme_cmd + containerstart_cmd)
    end

    def touch(dir, name)
      file = File.join(dir, name)
      File.open(file, 'w') { |f| f.write('foo') }
      file
    end

  end

end
