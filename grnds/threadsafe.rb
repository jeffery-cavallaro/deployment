module Grnds
  # The ThreadSafe mixin adds a hidden mutex attribute to the including class and uses it to synchronize access to the class's
  # instance variables by overriding the accessor definition class methods.  The class's instance members can also use the
  # 'synchronize' method to synchronize sections of code.
  #
  # CAVEATS:
  #
  #    1.  The including class must define an 'initialize' method that includes a call to 'super()', so that the mutex
  #        attribute is properly initialized.
  #
  #    2.  Code within a synchronize block must access attributes using instance variable syntax (e.g., '@a') - not accessors.
  #        Otherwise, deadlock will occur.
  #
  module ThreadSafe
    module ClassMethods
      def attr_reader(*names)
        names.each { |name| define_method("#{name}") { synchronize { instance_variable_get("@#{name}") } } }
      end

      def attr_writer(*names)
        names.each { |name| define_method("#{name}=") { |value| synchronize { instance_variable_set("@#{name}", value) } } }
      end

      def attr_accessor(*names)
        names.each do |name|
          attr_reader(name)
          attr_writer(name)
        end
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

    def initialize
      @mutex = Thread::Mutex.new
    end

    def synchronize
      @mutex.synchronize { yield }
    end
  end
end
