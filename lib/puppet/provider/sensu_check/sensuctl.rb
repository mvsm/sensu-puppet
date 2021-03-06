require File.expand_path(File.join(File.dirname(__FILE__), '..', 'sensuctl'))

Puppet::Type.type(:sensu_check).provide(:sensuctl, :parent => Puppet::Provider::Sensuctl) do
  desc "Provider sensu_check using sensuctl"

  mk_resource_methods

  defaultfor :kernel => ['Linux','windows']

  def self.instances
    checks = []

    data = sensuctl_list('check')

    data.each do |d|
      check = {}
      check[:ensure] = :present
      check[:resource_name] = d['metadata']['name']
      check[:namespace] = d['metadata']['namespace']
      check[:name] = "#{check[:resource_name]} in #{check[:namespace]}"
      check[:labels] = d['metadata']['labels']
      check[:annotations] = d['metadata']['annotations']
      d.each_pair do |key,value|
        next if key == 'metadata'
        if !!value == value
          value = value.to_s.to_sym
        end
        if type_properties.include?(key.to_sym)
          check[key.to_sym] = value
        else
          next
        end
      end
      checks << new(check)
    end
    checks
  end

  def self.prefetch(resources)
    checks = instances
    resources.keys.each do |name|
      if provider = checks.find { |c| c.resource_name == resources[name][:resource_name] && c.namespace == resources[name][:namespace] }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  type_properties.each do |prop|
    define_method "#{prop}=".to_sym do |value|
      @property_flush[prop] = value
    end
  end

  def create
    spec = {}
    metadata = {}
    metadata[:name] = resource[:resource_name]
    type_properties.each do |property|
      value = resource[property]
      next if value.nil?
      next if value == :absent || value == [:absent]
      if [:true, :false].include?(value)
        value = convert_boolean_property_value(value)
      end
      if property == :namespace
        metadata[:namespace] = value
      elsif property == :labels
        metadata[:labels] = value
      elsif property == :annotations
        metadata[:annotations] = value
      else
        spec[property] = value
      end
    end
    begin
      sensuctl_create('CheckConfig', metadata, spec)
    rescue Exception => e
      raise Puppet::Error, "sensuctl create #{resource[:name]} failed\nError message: #{e.message}"
    end
    @property_hash[:ensure] = :present
  end

  def flush
    if !@property_flush.empty?
      spec = {}
      metadata = {}
      metadata[:name] = resource[:resource_name]
      type_properties.each do |property|
        if @property_flush[property]
          value = @property_flush[property]
        else
          value = resource[property]
        end
        next if value.nil?
        if [:true, :false].include?(value)
          value = convert_boolean_property_value(value)
        elsif value == :absent
          value = nil
        end
        if property == :namespace
          metadata[:namespace] = value
        elsif property == :labels
          metadata[:labels] = value
        elsif property == :annotations
          metadata[:annotations] = value
        else
          spec[property] = value
        end
      end
      begin
        sensuctl_create('CheckConfig', metadata, spec)
      rescue Exception => e
        raise Puppet::Error, "sensuctl create #{resource[:name]} failed\nError message: #{e.message}"
      end
    end
    @property_hash = resource.to_hash
  end

  def destroy
    begin
      sensuctl_delete('check', resource[:resource_name], resource[:namespace])
    rescue Exception => e
      raise Puppet::Error, "sensuctl delete check #{resource[:name]} failed\nError message: #{e.message}"
    end
    @property_hash.clear
  end
end

