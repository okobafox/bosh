require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Agent::Message::Configure do

  before(:each) do
    @processor = Bosh::Agent::Message::Configure.new(nil)
    @processor.stub!(:info_get_ovfenv).and_return(ovf_xml)

    # We just want to avoid this to accidently be invoked on dev systems
    @processor.stub(:update_file)
  end

  it 'should read ovf xml' do
    @processor.load_ovf.keys.should include("networks")
    @processor.load_ovf.keys.should include("agent_id")
  end

  it 'should setup networking' do
    @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    @processor.load_ovf
    @processor.setup_networking
  end

  it "should fail when ovf mac doesn't match one on the system" do
    @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:71" => "eth0"})
    @processor.load_ovf
    lambda { @processor.setup_networking }.should raise_error(Bosh::Agent::MessageHandlerError, /from OVF not present in instance/)

  end

  it "should fail when network information is incomplete" do
    @processor.stub!(:info_get_ovfenv).and_return(incomplete_ovf_xml)
    @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    @processor.load_ovf
    lambda { @processor.setup_networking }.should raise_error(Bosh::Agent::MessageHandlerError, /Missing network value for netmask in/)
  end

  it "should generate ubuntu network files" do
    @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    @processor.stub!(:update_file) do |data, file|
      # FIMXE: clean this mess up 
      case file
      when '/etc/network/interfaces'
        data.should == "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet static\n    address 11.2.3.4\n    network 11.2.3.0\n    netmask 255.255.255.0\n    broadcast 11.2.3.255\n    gateway 11.2.3.1\n\n"
      when '/etc/resolv.conf'
        data.should == "nameserver 11.1.2.5\nnameserver 11.1.2.6\n"
      end
    end

    @processor.load_ovf
    @processor.setup_networking
  end

end

def ovf_xml
  %q{
    <?xml version="1.0" encoding="UTF-8"?>
    <Environment
         xmlns="http://schemas.dmtf.org/ovf/environment/1"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xmlns:oe="http://schemas.dmtf.org/ovf/environment/1"
         xmlns:ve="http://www.vmware.com/schema/ovfenv"
         oe:id="">
       <PlatformSection>
          <Kind>VMware ESXi</Kind>
          <Version>4.1.0</Version>
          <Vendor>VMware, Inc.</Vendor>
          <Locale>en</Locale>
       </PlatformSection>
       <PropertySection>
             <Property oe:key="Test_Property2" oe:value="{&quot;networks&quot;:{&quot;network_a&quot;:{&quot;mac&quot;:&quot;00:50:56:89:17:70&quot;,&quot;ip&quot;:&quot;1.2.3.4&quot;,&quot;cloud_properties&quot;:{&quot;name&quot;:&quot;vlan-c-172.30.38.0-21&quot;}}},&quot;agent_id&quot;:&quot;foo&quot;}"/>
             <Property oe:key="Bosh_Agent_Properties_old" oe:value="{&quot;networks&quot;:{&quot;network_a&quot;:{&quot;netmask&quot;:&quot;255.255.255.0&quot;,&quot;broadcast&quot;:&quot;11.2.3.255&quot;,&quot;mac&quot;:&quot;00:50:56:89:17:70&quot;,&quot;network&quot;:&quot;11.2.3.0&quot;,&quot;interface&quot;:&quot;eth0&quot;,&quot;ip&quot;:&quot;11.2.3.4&quot;,&quot;gw&quot;:&quot;11.2.3.1&quot;,&quot;cloud_properties&quot;:{&quot;name&quot;:&quot;vlan-c-172.30.38.0-21&quot;}}},&quot;agent_id&quot;:&quot;foo&quot;}"/>
             <Property oe:key="Bosh_Agent_Properties" oe:value="{&quot;networks&quot;:{&quot;network_a&quot;:{&quot;netmask&quot;:&quot;255.255.255.0&quot;,&quot;mac&quot;:&quot;00:50:56:89:17:70&quot;,&quot;gw&quot;:&quot;11.2.3.1&quot;,&quot;ip&quot;:&quot;11.2.3.4&quot;,&quot;dns&quot;:[&quot;11.1.2.5&quot;,&quot;11.1.2.6&quot;],&quot;cloud_properties&quot;:{&quot;name&quot;:&quot;vlan-c-172.30.38.0-21&quot;}}},&quot;agent_id&quot;:&quot;foo&quot;}"/>
       </PropertySection>
       <ve:EthernetAdapterSection>
          <ve:Adapter ve:mac="00:50:56:87:00:1a" ve:network="VLAN436"/>
          <ve:Adapter ve:mac="00:50:56:87:00:1b" ve:network="VLAN440"/>
       </ve:EthernetAdapterSection>
    </Environment>
  }
end

def incomplete_ovf_xml
  %q{
    <?xml version="1.0" encoding="UTF-8"?>
    <Environment
         xmlns="http://schemas.dmtf.org/ovf/environment/1"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xmlns:oe="http://schemas.dmtf.org/ovf/environment/1"
         xmlns:ve="http://www.vmware.com/schema/ovfenv"
         oe:id="">
       <PlatformSection>
          <Kind>VMware ESXi</Kind>
          <Version>4.1.0</Version>
          <Vendor>VMware, Inc.</Vendor>
          <Locale>en</Locale>
       </PlatformSection>
       <PropertySection>
             <Property oe:key="Test_Property2" oe:value="{&quot;networks&quot;:{&quot;network_a&quot;:{&quot;mac&quot;:&quot;00:50:56:89:17:70&quot;,&quot;ip&quot;:&quot;1.2.3.4&quot;,&quot;cloud_properties&quot;:{&quot;name&quot;:&quot;vlan-c-172.30.38.0-21&quot;}}},&quot;agent_id&quot;:&quot;foo&quot;}"/>
             <Property oe:key="Bosh_Agent_Properties_older" oe:value="{&quot;networks&quot;:{&quot;network_a&quot;:{&quot;netmask&quot;:&quot;255.255.255.0&quot;,&quot;broadcast&quot;:&quot;11.2.3.255&quot;,&quot;mac&quot;:&quot;00:50:56:89:17:70&quot;,&quot;network&quot;:&quot;11.2.3.0&quot;,&quot;interface&quot;:&quot;eth0&quot;,&quot;ip&quot;:&quot;11.2.3.4&quot;,&quot;gw&quot;:&quot;11.2.3.1&quot;,&quot;cloud_properties&quot;:{&quot;name&quot;:&quot;vlan-c-172.30.38.0-21&quot;}}},&quot;agent_id&quot;:&quot;foo&quot;}"/>
             <Property oe:key="Bosh_Agent_Properties" oe:value="{&quot;networks&quot;:{&quot;network_a&quot;:{&quot;mac&quot;:&quot;00:50:56:89:17:70&quot;,&quot;gw&quot;:&quot;11.2.3.1&quot;,&quot;ip&quot;:&quot;11.2.3.4&quot;,&quot;dns&quot;:[&quot;11.1.2.5&quot;,&quot;11.1.2.6&quot;],&quot;cloud_properties&quot;:{&quot;name&quot;:&quot;vlan-c-172.30.38.0-21&quot;}}},&quot;agent_id&quot;:&quot;foo&quot;}"/>
       </PropertySection>
       <ve:EthernetAdapterSection>
          <ve:Adapter ve:mac="00:50:56:87:00:1a" ve:network="VLAN436"/>
          <ve:Adapter ve:mac="00:50:56:87:00:1b" ve:network="VLAN440"/>
       </ve:EthernetAdapterSection>
    </Environment>
  }
end
