require 'singleton'

module Singleton
  # Extends the Singleton module so that all calls to methods not defined by the class get forwarded to the instance.  This is
  # usually what is desired.  Note that this implementation is dependent on the class method extension pattern employed by the
  # Singleton module - especially the name 'SingletonClassMethods'.  Thus, this extension will need to be updated if this
  # pattern ever changes.
  module SingletonClassMethods
    def method_missing(method, *args, &block)
      instance.send(method, *args, &block)
    end

    def respond_to_missing?(*args)
      instance.respond_to?(*args)
    end
  end
end
