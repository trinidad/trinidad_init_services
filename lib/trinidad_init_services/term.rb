module Trinidad
  module InitServices
    class Term

      def initialize(stdin = STDIN, stdout = STDOUT)
        @stdin, @stdout = stdin, stdout
      end

      def ask_path(question, default = nil)
        File.expand_path(ask(question, default))
      end

      def ask(question, default = nil)
        return nil if not @stdin.tty?

        question << " [#{default}]" if default && !default.empty?

        result = nil

        while result.nil?
          @stdout.print(question + "  ")
          @stdout.flush

          result = @stdin.gets

          if result
            result.chomp!

            result = case result
            when /^$/
              default
            else
              result
            end
          end
        end
        return result
      end
    end
  end
end
