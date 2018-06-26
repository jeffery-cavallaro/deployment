module Grnds
  # AWS Support Library
  module AWS
    require 'aws-sdk'

    # The superclass for all VPC-related exceptions.  The name can actually be either a VPC name or ID.
    class VPCError < RuntimeError
      attr_reader :name

      def initialize(name, message)
        @name = name
        msg = ''
        msg << "#{name}: " if name
        msg << message
        super msg
      end
    end

    # Raised by the initializer when a specified VPC cannot be found by name or ID.
    class VPCNotFoundError < VPCError
      def initialize(name)
        super(name, 'No matching VPC found')
      end
    end

    # Raised by the search-by-name method when more than one VPC with a matching name tag is found.
    class VPCMultipleFoundError < VPCError
      def initialize(name, ids)
        super(name, "Multiple VPCs found: #{ids.join(', ')}")
        @ids = ids
      end
    end

    # Raised by the create method when a VPC with the specified name already exists.  Although AWS allows VPCs to have
    # duplicate name tags, this module does not.
    class VPCAlreadyExistsError < VPCError
      def initialize(name)
        super(name, 'VPC already exists')
      end
    end

    # Virtual Private Cloud
    class VPC
      def self.client
        Aws::EC2::Resource.new
      end

      private_class_method :new

      # Returns a list of VPCs matching the specified ID (maximum one), and/or a specified name (should only be one; however,
      # AWS allows duplicate name tags), or all defined for the current account if neither the ID nor a name are specified.
      # The returned list is sorted by ID.
      def self.find(**options)
        options ||= {}
        id = options[:id]
        name = options[:name]

        vpcs = []
        client.vpcs.each do |vpc|
          vpc = new(vpc)
          next if id && vpc.id != id
          next if name && vpc.name != name
          vpcs << vpc
        end
        vpcs.sort_by! &:id
      end

      # Finds an existing VPC by ID, or the first found VPC if no ID is specified.
      def self.with_id(id = nil)
        vpc = self.find(id: id).first
        raise VPCNotFoundError.new(id) unless vpc
        vpc
      end

      # Finds an existing VPC by name.  Duplicate names are not allowed.  If no name is specified then this specifically
      # matches VPCs with no name tag.
      def self.with_name(name = nil)
        vpcs = self.find(name: name)
        vpcs = vpcs.select { |vpc| !vpc.name } unless name

        case vpcs.size
        when 0
          raise VPCNotFoundError.new(name)
        when 1
          vpcs.first
        else
          raise VPCMultipleFoundError.new(name, vpcs.collect(&:id))
        end        
      end

      # The name tag is copied to an attribute for convenience.
      def initialize(vpc)
        @vpc = vpc
        @name = find_tag_value('Name')
      end

      def id
        @vpc.id
      end

      def name
        @name
      end

      def find_tag_value(key)
        tag = @vpc.tags.find { |tag| tag.key = key }
        tag ? tag.value : nil
      end
    end
  end
end
