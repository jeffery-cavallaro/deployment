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
    # Used for extending including class.
    module ThreadSafeClassMethods
      # These methods define synchronized attribute accessors for the including class.
      def attr_reader(*names)
        names.each { |name| define_method(name) { synchronize { instance_variable_get("@#{name}") } } }
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

      # These methods define synchronized attribute accessors for a composite class that is not itself threadsafe.  For
      # example, suppose class A contains an instance of class B using attribute name '@b'.  Also suppose that class B has an
      # attribute '@c' that is accessed using accessor method ':c'.  To synchronize access to '@c' from an instance of A using
      # an accessor named ':d', include the following line in A's class definition:
      #
      #    attr_deep_accessor(:d, :@b, :c)
      #
      def attr_deep_reader(method, attribute, name = method)
        define_method(method) { synchronize { instance_variable_get(attribute).send(name) } }
      end

      def attr_deep_writer(method, attribute, name = method)
        define_method("#{method}=") { |value| synchronize { instance_variable_get(attribute).send("#{name}=", value) } }
      end

      def attr_deep_accessor(method, attribute, name = method)
        attr_deep_reader(method, attribute, name)
        attr_deep_writer(method, attribute, name)
      end
    end

    def self.included(base)
      base.extend ThreadSafeClassMethods
    end

    def initialize
      @mutex = Thread::Mutex.new
    end

    def synchronize
      @mutex.synchronize { yield }
    end
  end
end
