module Grnds
  # Process Logging
  module Loggable
    require 'logger'
    require 'singleton'

    # The Loggable class provides a standardized logging capability via a singleton.  It is simply a wrapper to the standard
    # ruby logger class.
    #
    # The standardized log message format is as follows:
    #
    #    program(pid:tid)[n/m]: YYYYMMDDTHHMMSS.mmm: severity: message\n
    #
    # where:
    #
    #    program            User-defined program name.
    #
    #    pid                Process ID.  Program name must be enabled.
    #
    #    tid                Thread ID.  Process ID must be enabled.
    #
    #    n/m                Line number 'n' of 'm' lines of a multi-line log message (e.g., a stack dump).  Not shown for
    #                       single-line messages.
    #
    #    YYYYMMDDTHHMMSS    UTC date/time stamp.
    #
    #    mmm                Millisecond part of date/time stamp.
    #
    #    severity           Severity level: FATAL, ERROR, WARN, INFO, DEBUG.
    #
    #    message            Actual log message information.  Multiple lines are split up, stripped of leading and trailing
    #                       whitespace, and prefixed as necessary.
    #
    #    \n                 Each line is terminated by a newline.
    #
    # All parts, with the exception of the message and newline parts, are optional.
    class Log
      include Singleton

      DEFAULT_KEEP_FILES = 0
      DEFAULT_MAX_SIZE = 100 * 1024 * 1024 # 100Mb

      # IO logging is minimal (message only) and is suitable for screen output.
      private def io_logging(program)
        @logger.progname = program
        @pid = false
        @tid = false
        @lineno = false
        @timestamp = false
        @milliseconds = false
        @level = false
      end

      # File logging enables all fields.
      private def file_logging(program)
        @logger.progname = program
        @pid = true
        @tid = true
        @lineno = true
        @timestamp = true
        @milliseconds = true
        @level = true
      end

      private def install_formatter
        @logger.formatter = proc { |*args| formatter(*args) }
      end

      # Use to establish logging to STDERR by default.
      def initialize
        @logger = Logger.new(STDERR)
        install_formatter
        io_logging(nil)
        @mutex = Thread::Mutex.new
      end

      # Restart IO logging.  This is the most general case, and can be used to route log messages to any IO stream.
      def start(program = nil, io = STDERR)
        @mutex.synchronize do
          @logger.close
          @logger = Logger.new(io)
          install_formatter
          io_logging(program)
        end
      end

      # Restart file logging.  The rotation scheme is a limited number of files of limited size; this is generally better than
      # something like day files, since the logger package does not size-limit such files and UTC/local issues may cause a
      # day's messages to span files anyway.
      def start_file(program, filename, keep_files = DEFAULT_KEEP_FILES, max_size = DEFAULT_MAX_SIZE)
        @mutex.synchronize do
          @logger.close
          @logger = Logger.new(filename, keep_files, max_size)
          install_formatter
          file_logging(program)
        end
      end

      def program
        @mutex.synchronize { @logger.progname }
      end

      def program=(name)
        @mutex.synchronize { @logger.progname = name }
      end

      %i[pid tid lineno timestamp milliseconds level].each do |method|
        member = "@#{method}"
        define_method(method) { @mutex.synchronize { instance_variable_get(member) } }
        define_method("#{method}=") { |value| @mutex.synchronize { instance_variable_set(member, value) } }
      end

      def threshold
        @mutex.synchronize { @logger.level }
      end

      def threshold=(min_level)
        @mutex.synchronize { @logger.level = min_level }
      end

      %i[add fatal error warn info debug].each do |method|
        define_method(method) { |*args, &block| @logger.send(method, *args, &block) }
      end

      def self.method_missing(method, *args, &block)
        instance.send(method, *args, &block)
      end

      def self.respond_to_missing?(*args)
        instance.respond_to?(*args)
      end

      private def formatter(severity, datetime, progname, message)
        lines = []
        if Exception === message
          lines << "#{message.class}: #{message}"
          lines.concat(message.backtrace)
        else
          lines = message.each_line.collect(&:strip)
        end
        nlines = lines.size

        program_part = ''
        if progname
          program_part << progname
          if pid
            program_part << "(#{Process.pid}"
            program_part << ":#{Thread.current.object_id}" if tid
            program_part << ')'
          end
        end

        timestamp_part = ''
        if timestamp
          format = '%Y%m%dT%H%M%S'
          format << '.%L' if milliseconds
          timestamp_part << datetime.utc.strftime(format)
        end

        nlines.times do |iline|
          prefix_part = ''
          prefix_part << program_part unless program_part.empty?
          prefix_part << "[#{iline + 1}/#{nlines}]" if lineno && nlines > 1

          parts = []
          parts << prefix_part unless prefix_part.empty?
          parts << timestamp_part unless timestamp_part.empty?
          parts << severity.to_s if level
          parts << "#{lines[iline]}\n"
          lines[iline] = parts.join(': ')
        end

        lines.join
      end
    end
  end
end
