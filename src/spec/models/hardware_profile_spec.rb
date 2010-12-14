require 'spec_helper'

describe HardwareProfile do
  before(:each) do
    @hp = Factory.create(:mock_hwp1)
  end

  it "should create a new hardware profile" do
    @hp.should be_valid
  end

  it "should not validate for missing name" do
    [nil, ""].each do |value|
      @hp.name = value
      @hp.should_not be_valid
    end

    @hp.name = 'valid name'
    @hp.should be_valid
  end

  it "should require unique names" do
    hp2 = Factory.create(:mock_hwp2)
    @hp.should be_valid
    hp2.should be_valid

    hp2.name = @hp.name
    hp2.should_not be_valid
  end

  it "should require valid amount of memory" do
    [nil, "hello", -1].each do |fail_value|
      @hp.memory.value = fail_value
      @hp.should_not be_valid
    end
  end

  it "should require valid amount of storage" do
    [nil, "hello", -1].each do |fail_value|
      @hp.storage.value = fail_value
      @hp.should_not be_valid
    end
  end

  it "should require valid amount of CPU" do
    [nil, "hello", -1].each do |fail_value|
      @hp.cpu.value = fail_value
      @hp.should_not be_valid
    end
  end

  it "should allow numerical amount of CPU" do
    [2, 2.2].each do |fail_value|
      @hp.cpu.value = fail_value
      @hp.should be_valid
    end
  end

  it "should allow Aggregator profiles only for provider profiles" do
    @hp.provider = nil

    @hp.aggregator_hardware_profiles << @hp
    @hp.should have(1).error_on(:aggregator_hardware_profiles)
    @hp.errors.on(:aggregator_hardware_profiles).should eql(
      "Aggregator profiles only allowed for provider profiles")

    @hp.aggregator_hardware_profiles.clear
    @hp.should be_valid
  end

  it "should allow Provider profiles only for aggregator profiles" do
    @hp.provider = Provider.new

    @hp.aggregator_hardware_profiles << @hp
    @hp.should have(1).error_on(:provider_hardware_profiles)
    @hp.errors.on(:provider_hardware_profiles).should eql(
      "Provider profiles only allowed for aggregator profiles")

    @hp.provider_hardware_profiles.clear
    @hp.should be_valid
  end

  it "should have 'kind' attribute of hardware profile property set to string (not symbol)" do
    api_prop = mock('DeltaCloud::HWP::FloatProperty', :unit => 'MB', :name => 'memory', :kind => :fixed, :value => 12288.0)
    @hp.memory =@hp.new_property(api_prop)
    @hp.memory.kind.should equal(@hp.memory.kind.to_s)
  end

  it "should calculate all the correct matches of provider hardware profiles against a given hardware profile" do
    provider = Factory(:mock_provider)
    HardwareProfile.find(:all, :conditions => {:provider_id => provider.id}).each do |hwp|
      hwp.destroy
    end

    # hwpp memory
    hwpp_mem_match_all = Factory(:hwpp_range, :name => 'memory', :unit => 'MB', :range_first => '1', :range_last => '4096', :value => '256')
    hwpp_mem_match_none = Factory(:hwpp_fixed, :name => 'memory', :unit => 'MB', :value => '8192')
    hwpp_mem_match_2 = create_hwpp_enum(['256', '1024'], {:name => 'memory', :unit => 'MB'})

    hwpp_mem_range = Factory(:hwpp_range, :name => 'memory', :unit => 'MB', :range_first => '256', :range_last => '512', :value => '256')
    hwpp_mem_fixed = Factory(:hwpp_fixed, :name => 'memory', :unit => 'MB', :value => '4096')
    hwpp_mem_enum = create_hwpp_enum(['1024', '3072', '4096'], {:name => 'memory', :unit => 'MB'})

    # hwpp cpu
    hwpp_cpu_match_all = Factory(:hwpp_range, :name => 'cpu', :unit => 'count', :range_first => '1', :range_last => '32', :value => '2')
    hwpp_cpu_match_none = Factory(:hwpp_fixed, :name => 'cpu', :unit => 'count', :value => '64')
    hwpp_cpu_match_2 = create_hwpp_enum(['8', '16'], {:name => 'cpu', :unit => 'count'})

    hwpp_cpu_range = Factory(:hwpp_range, :name => 'cpu', :unit => 'count', :range_first => '1', :range_last => '16', :value => '4')
    hwpp_cpu_fixed = Factory(:hwpp_fixed, :name => 'cpu', :unit => 'count', :value => '32')
    hwpp_cpu_enum = create_hwpp_enum(['16', '32'], {:name => 'cpu', :unit => 'count'})

    # hwpp storage
    hwpp_storage_match_all = Factory(:hwpp_range, :name => 'storage', :unit => 'GB', :range_first => '100', :range_last => '4000', :value => '250')
    hwpp_storage_match_none = Factory(:hwpp_fixed, :name => 'storage', :unit => 'GB', :value => '4000')
    hwpp_storage_match_2 = create_hwpp_enum(['1000', '2000'], {:name => 'storage', :unit => 'GB'})

    hwpp_storage_range = Factory(:hwpp_range, :name => 'storage', :unit => 'GB', :range_first => '100', :range_last => '1000', :value => '250')
    hwpp_storage_fixed = Factory(:hwpp_fixed, :name => 'storage', :unit => 'GB', :value => '3000')
    hwpp_storage_enum = create_hwpp_enum(['2000', '4000'], {:name => 'storage', :unit => 'GB'})

    # hwpp arch
    hwpp_arch_i386 = Factory(:hwpp_arch, :value => 'i386')
    hwpp_arch_i386_enum = create_hwpp_enum(['i386', 'x86_64'], {:name => 'architecture', :unit => 'label'})

    hwp_match_all = Factory(:hardware_profile, :memory => hwpp_mem_match_all,
                                               :cpu => hwpp_cpu_match_all,
                                               :storage => hwpp_storage_match_all,
                                               :architecture => hwpp_arch_i386)

    hwp_match_none = Factory(:hardware_profile, :memory => hwpp_mem_match_none,
                                                :cpu => hwpp_cpu_match_none,
                                                :storage => hwpp_storage_match_none,
                                                :architecture => hwpp_arch_i386)

    hwp_match_2 = Factory(:hardware_profile, :memory => hwpp_mem_match_2,
                                             :cpu => hwpp_cpu_match_2,
                                             :storage => hwpp_storage_match_2,
                                             :architecture => hwpp_arch_i386)

    hwp1 = Factory(:hardware_profile, :memory => hwpp_mem_range,
                                      :cpu => hwpp_cpu_range,
                                      :storage => hwpp_storage_range,
                                      :architecture => hwpp_arch_i386,
                                      :provider => provider)

    hwp2 = Factory(:hardware_profile, :memory => hwpp_mem_fixed,
                                      :cpu => hwpp_cpu_fixed,
                                      :storage => hwpp_storage_fixed,
                                      :architecture => hwpp_arch_i386,
                                      :provider => provider)

    hwp3 = Factory(:hardware_profile, :memory => hwpp_mem_enum,
                                      :cpu => hwpp_cpu_enum,
                                      :storage => hwpp_storage_enum,
                                      :architecture => hwpp_arch_i386_enum,
                                      :provider => provider)

    hwp4 = Factory(:hardware_profile, :memory => hwpp_mem_enum,
                                      :cpu => nil,
                                      :storage => hwpp_storage_enum,
                                      :architecture => hwpp_arch_i386,
                                      :provider => provider)

    HardwareProfile.matching_hwps(hwp_match_all).size.should == 3
    HardwareProfile.matching_hwps(hwp_match_none).empty?.should == true
    HardwareProfile.matching_hwps(hwp_match_2).size.should == 2

  end

  it "should calculate the correct array for hardware profile properties of kind: 'fixed' and 'enum'" do
    hwp_fixed = Factory(:hwpp_fixed, :value => '256')

    enum_array = ['256', '512', '1024', '2048']
    hwp_enum = create_hwpp_enum(enum_array)

    HardwareProfile.create_array_from_property(hwp_fixed).should == ['256']
    (HardwareProfile.create_array_from_property(hwp_enum) & enum_array).should == enum_array
  end

  it "should determine match for 2 hardware profiles" do
    hwpp_mem_range = Factory(:hwpp_range, :name => 'memory', :unit => 'MB', :range_first => '256', :range_last => '512', :value => '256')
    hwpp_mem_fixed = Factory(:hwpp_fixed, :name => 'memory', :unit => 'MB', :value => '1024')
    hwpp_mem_enum = create_hwpp_enum(['2048', '3072', '4096'], {:name => 'memory', :unit => 'MB'})

    hwpp_cpu_range = Factory(:hwpp_range, :name => 'cpu', :unit => 'count', :range_first => '1', :range_last => '4', :value => '2')
    hwpp_cpu_fixed = Factory(:hwpp_fixed, :name => 'cpu', :unit => 'count', :value => '8')
    hwpp_cpu_enum = create_hwpp_enum(['16', '32'], {:name => 'cpu', :unit => 'count'})

    hwpp_storage_range = Factory(:hwpp_range, :name => 'storage', :unit => 'GB', :range_first => '100', :range_last => '500', :value => '250')
    hwpp_storage_fixed = Factory(:hwpp_fixed, :name => 'storage', :unit => 'GB', :value => '1000')
    hwpp_storage_enum = create_hwpp_enum(['2000', '4000'], {:name => 'storage', :unit => 'GB'})

    hwpp_arch_i386 = Factory(:hwpp_arch, :value => 'i386')
    hwpp_arch_x86_64 = Factory(:hwpp_arch, :value => 'x86_64')

    hwp1 = Factory(:hardware_profile, :memory => hwpp_mem_range, :cpu => hwpp_cpu_range, :storage => hwpp_storage_range, :architecture => hwpp_arch_i386)
    hwp2 = Factory(:hardware_profile, :memory => hwpp_mem_fixed, :cpu => hwpp_cpu_fixed, :storage => hwpp_storage_fixed, :architecture => hwpp_arch_i386)
    hwp3 = Factory(:hardware_profile, :memory => hwpp_mem_enum, :cpu => hwpp_cpu_enum, :storage => hwpp_storage_enum, :architecture => hwpp_arch_i386)
    hwp4 = Factory(:hardware_profile, :memory => hwpp_mem_enum, :cpu => hwpp_cpu_enum, :storage => hwpp_storage_enum, :architecture => hwpp_arch_x86_64)
    hwp5 = Factory(:hardware_profile, :memory => hwpp_mem_enum, :cpu => hwpp_cpu_enum, :storage => nil, :architecture => hwpp_arch_x86_64)

    # Check memory match
    match_map = HardwareProfile.check_properties(hwp1, hwp1)
    match_map[:memory].kind.should == 'range'
    match_map[:memory].range_first.should == '256'
    match_map[:memory].range_last.should == '512'

    match_map[:cpu].kind.should == 'range'
    match_map[:cpu].range_first.should == '1'
    match_map[:cpu].range_last.should == '4'

    match_map[:storage].kind.should == 'range'
    match_map[:storage].range_first.should == '100'
    match_map[:storage].range_last.should == '500'

    # Check fixed match
    match_map = HardwareProfile.check_properties(hwp2, hwp2)
    match_map[:memory].kind.should == 'fixed'
    match_map[:memory].value.should == '1024'

    match_map[:cpu].kind.should == 'fixed'
    match_map[:cpu].value.should == '8'

    match_map[:storage].kind.should == 'fixed'
    match_map[:storage].value.should == '1000'

    # Check enums match
    match_map = HardwareProfile.check_properties(hwp3, hwp3)
    match_map[:memory].kind.should == 'enum'
    check_enum_entries_match(match_map[:memory], ['2048', '3072', '4096'])

    match_map[:cpu].kind.should == 'enum'
    check_enum_entries_match(match_map[:cpu], ['16', '32'])

    match_map[:storage].kind.should == 'enum'
    check_enum_entries_match(match_map[:storage], ['2000', '4000'])

    HardwareProfile.check_properties(hwp1, hwp2).should == nil
    HardwareProfile.check_properties(hwp2, hwp3).should == nil
    HardwareProfile.check_properties(hwp3, hwp4).should == nil
    HardwareProfile.check_properties(hwp4, hwp5).should == nil
  end

  it "should calculate matches for range on hardware profile properties" do
    hwp_range = Factory(:hwpp_range, :range_first => '256', :range_last => '512', :value => '256')

    hwp_range_match = Factory(:hwpp_range, :range_first => '512', :range_last => '1024', :value => '512')
    hwp_range_fail = Factory(:hwpp_range, :range_first => '2048', :range_last => '2048', :value => '8192')

    hwp_fixed_match = Factory(:hwpp_fixed, :value => '256')
    hwp_fixed_fail = Factory(:hwpp_fixed, :value => '4096')

    hwp_enum_match = create_hwpp_enum(['256', '512', '1024', '2048'])
    hwp_enum_fail = create_hwpp_enum(['2048', '4096', '8192', '16384'])

    hwpp = HardwareProfile.calculate_range_match(hwp_range, hwp_range_match)
    hwpp.kind.should == 'range'
    hwpp.range_first.should == '512'
    hwpp.range_last.should == '512'

    hwpp = HardwareProfile.calculate_range_match(hwp_range, hwp_fixed_match)
    hwpp.kind.should == 'fixed'
    hwpp.value.should == '256'

    hwpp = HardwareProfile.calculate_range_match(hwp_range, hwp_enum_match)
    check_enum_entries_match(hwpp, ['256', '512'])

    [hwp_range_fail, hwp_fixed_fail, hwp_enum_fail].each do |hwpp|
      HardwareProfile.calculate_range_match(hwp_range, hwpp).should == nil
    end
  end

  it "should calculate correct matches for each hwp property" do
    hwp_range1 = Factory(:hwpp_range, :range_first => '256', :range_last => '512', :value => '512')
    hwp_range2 = Factory(:hwpp_range, :range_first => '512', :range_last => '1024', :value => '768')
    hwp_range3 = Factory(:hwpp_range, :range_first => '2048', :range_last => '4096', :value => '3072')

    hwp_fixed1 = Factory(:hwpp_fixed, :value => '256')
    hwp_fixed2 = Factory(:hwpp_fixed, :value => '4096')
    hwp_fixed3 = Factory(:hwpp_fixed, :value => '8192')

    hwp_enum1 = create_hwpp_enum(['256', '512', '1024'])
    hwp_enum2 = create_hwpp_enum(['1024', '2048', '3072'])
    hwp_enum3 = create_hwpp_enum(['8192', '16384', '32768'])

    # == Test HWPP against Ranges ==
    # -- Expected Matches
    hwpp = HardwareProfile.check_hwp_property(hwp_range1, hwp_range2)
    hwpp.kind.should == 'range'
    hwpp.range_first.should == '512'
    hwpp.range_last.should == '512'

    hwpp = HardwareProfile.check_hwp_property(hwp_range1, hwp_fixed1)
    hwpp.kind.should == 'fixed'
    hwpp.value.should == '256'

    hwpp = HardwareProfile.check_hwp_property(hwp_range1, hwp_enum1)
    hwpp.kind.should == 'enum'
    check_enum_entries_match(hwpp, ['256', '512'])

    # -- Expected Failures
    HardwareProfile.check_hwp_property(hwp_range1, hwp_enum3).should == nil
    HardwareProfile.check_hwp_property(hwp_range1, hwp_range3).should == nil
    HardwareProfile.check_hwp_property(hwp_range1, hwp_fixed3).should == nil

    # == Test HWPP Against Fixed ==
    # -- Expected Matches
    hwpp = HardwareProfile.check_hwp_property(hwp_fixed1, hwp_range1)
    hwpp.kind.should == 'fixed'
    hwpp.value.should == '256'

    hwpp = HardwareProfile.check_hwp_property(hwp_fixed1, hwp_fixed1)
    hwpp.kind.should == 'fixed'
    hwpp.value.should == '256'

    hwpp = HardwareProfile.check_hwp_property(hwp_fixed1, hwp_enum1)
    hwpp.kind.should == 'fixed'
    hwpp.value == '512'

    # -- Expected Failures
    HardwareProfile.check_hwp_property(hwp_fixed1, hwp_range3).should == nil
    HardwareProfile.check_hwp_property(hwp_fixed1, hwp_fixed2).should == nil
    HardwareProfile.check_hwp_property(hwp_fixed1, hwp_enum3).should == nil

    # == Test HWPP Aginsts Enums ==
    # --Expected Matches
    hwpp = HardwareProfile.check_hwp_property(hwp_enum1, hwp_range1)
    hwpp.kind.should == 'enum'
    check_enum_entries_match(hwpp, ['256', '512'])

    hwpp = HardwareProfile.check_hwp_property(hwp_enum1, hwp_fixed1)
    hwpp.kind.should == 'fixed'
    hwpp.value.should == '256'

    hwpp = HardwareProfile.check_hwp_property(hwp_enum1, hwp_enum2)
    hwpp.kind.should == 'enum'
    check_enum_entries_match(hwpp, ['1024'])

    # -- Expected Failures
    HardwareProfile.check_hwp_property(hwp_enum1, hwp_range3).should == nil
    HardwareProfile.check_hwp_property(hwp_enum1, hwp_fixed2).should == nil
    HardwareProfile.check_hwp_property(hwp_enum1, hwp_enum3).should == nil
  end

  def create_hwpp_enum(value_array, properties = {})
    hwpp_enum = Factory(:hwpp_enum, properties)
    value_array.each do |value|
      hwpp_enum.property_enum_entries << Factory(:property_enum_entry, :value => value, :hardware_profile_property => hwpp_enum)
    end
    return hwpp_enum
  end

  def check_enum_entries_match(hwpp, value_array)
    enum_set = []
    hwpp.property_enum_entries.each do |enum|
      enum_set << enum.value
    end
    enum_set.should == value_array
  end
end
