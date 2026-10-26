module Expression
  # The external tool that prints a database's structure: its executable, arguments and extra
  # environment. Secrets go in the environment or in a file, never in the arguments, which other
  # users of the machine can read.
  record StructureDumpCommand, command : String, args : Array(String), env : Hash(String, String) = {} of String => String do
    # Runs the tool and returns what it printed. Raises `CQL::Error` with its stderr when it
    # fails, or when it cannot be started.
    def run : String
      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run(command, args, env: env, output: output, error: error)
      return output.to_s if status.success?

      raise CQL::Error.new("#{command} failed (#{failure(status)}): #{error.to_s.strip}")
    rescue ex : File::Error
      raise CQL::Error.new("#{command} could not be started: #{ex.message}")
    end

    # Names the environment variables but not their values, which hold passwords.
    def inspect(io : IO) : Nil
      io << self.class.name << "(@command=" << command.inspect << ", @args=" << args.inspect << ", @env="
      env.transform_values { "[FILTERED]" }.inspect(io)
      io << ')'
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    def pretty_print(pp) : Nil
      pp.text(inspect)
    end

    private def failure(status : Process::Status) : String
      status.exit_signal?.try { |signal| "signal #{signal}" } || "exit code #{status.exit_code}"
    end
  end
end
