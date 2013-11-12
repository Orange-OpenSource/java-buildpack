require 'rspec'
require_relative '../../../resources/jonas/diagnostics/jonas_diagnostics'

describe 'JonasDiagnostics' do

  ps_cmd_output = <<END_OF_STRING
Thu Sep 12 17:37:24 UTC 2013
UID PID PPID C SZ RSS PSR STIME TTY TIME CMD
root 1 0 0 248 296 3 17:37 ? 00:00:00 wshd: 17644ia17he
vcap 23 1 0 4431 1464 0 17:37 ? 00:00:00 /bin/bash
vcap 25 23 0 4432 748 1 17:37 ? 00:00:00 /bin/bash
vcap 26 25 0 4431 628 0 17:37 ? 00:00:00 /bin/bash
vcap 28 26 0 1020 308 3 17:37 ? 00:00:00 tee /home/vcap/logs/stdout.log
vcap 27 25 0 4431 644 2 17:37 ? 00:00:00 /bin/bash
vcap 30 27 0 1020 308 0 17:37 ? 00:00:00 tee /home/vcap/logs/stderr.log
vcap 32 25 0 4432 612 3 17:37 ? 00:00:00 /bin/bash
vcap 37 32 0 2359542 60552 3 17:37 ? 00:00:00 .java/bin/java -jar .jonas_root/deployme/deployme.jar -topologyFile=.jonas_root/deployme/topology.xml -domainName=singleDomain -serverName=singleServerName
vcap 36 32 0 2359542 31552 3 17:37 ? 00:00:00 .java/bin/java -jar .jonas_root/deployme/deployme.jar -topologyFile=.jonas_root/deployme/topology.xml -domainName=singleDomain -serverName=singleServerName
vcap 31 1 0 15097 11048 0 17:37 ? 00:00:00 ruby .jonas_root/diagnostics/diagnostics.rb
vcap 55 31 0 1039 572 3 17:37 ? 00:00:00 sh -c date;vmstat;ps -AFH --cols=2000;free
vcap 59 55 0 3758 1040 3 17:37 ? 00:00:00 ps -AFH --cols=2000
END_OF_STRING

  ps_process_cmd_output = <<-END_OF_STRING
Name: java
State:  S (sleeping)
Tgid: 10461
Pid:  10461
PPid: 10460
TracerPid:  0
Uid:  1000  1000 1000   1000
Gid:  1000  1000 1000   1000
FDSize: 256
Groups: 4 20 24 25 29 30 44 46 110 1000
VmPeak:    22844 kB
VmSize:    22780 kB
VmLck:         0 kB
VmHWM:      5784 kB
VmRSS:      5748 kB
VmData:     3788 kB
VmStk:        88 kB
VmExe:       876 kB
VmLib:      2120 kB
VmPTE:        64 kB
Threads:  1
SigQ: 0/16382
SigPnd: 0000000000000000
ShdPnd: 0000000000000000
SigBlk: 0000000000010000
SigIgn: 0000000000384004
SigCgt: 000000004b813efb
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: ffffffffffffffff
Cpus_allowed: 1
Cpus_allowed_list: 0
Mems_allowed: 1
Mems_allowed_list: 0
voluntary_ctxt_switches: 9787
nonvoluntary_ctxt_switches:  80
END_OF_STRING

  #Not clear why subject syntax fails to instanciate JonasDiagnotics by itself, instanciating it explicitly
  subject (:diagnostics) { JonasDiagnostics.new }

  it 'should extract largest vcap PIDs from ps output' do
    subject.extract_largest_pid(ps_cmd_output).should == '37'
  end


  it 'should sample static cmd and largest process' do
    subject.stub(:execute_cmd).with('date;ps -AFH --cols=2000').and_return(ps_cmd_output)
    subject.stub(:execute_cmd).with('cat /proc/37/status').and_return(ps_process_cmd_output)
    subject.stub(:update_gist)
    subject.should_receive(:update_gist).with('api_url', <<EXPECTED_OUTPUT)
Sample 1, elapsed 10 seconds
date;ps -AFH --cols=2000:
#{ps_cmd_output}

cat /proc/37/status:
#{ps_process_cmd_output}
EXPECTED_OUTPUT

    subject.sample_and_post('api_url', 1, 10)
  end
end