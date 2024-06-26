# frozen_string_literal: true

class Pry
  class Command
    class Ls < Pry::ClassCommand
      match 'ls'
      group 'Context'
      description 'Show the list of vars and methods in the current scope.'
      command_options shellwords: false, interpolate: false

      banner <<-'BANNER'
        Usage: ls [-m|-M|-p|-pM] [-q|-v] [-c|-i] [Object]
               ls [-g] [-l]

        ls shows you which methods, constants and variables are accessible to Pry. By
        default it shows you the local variables defined in the current shell, and any
        public methods or instance variables defined on the current object.

        The colours used are configurable using Pry.config.ls.*_color, and the separator
        is Pry.config.ls.separator.

        Pry.config.ls.ceiling is used to hide methods defined higher up in the
        inheritance chain, this is by default set to [Object, Module, Class] so that
        methods defined on all Objects are omitted. The -v flag can be used to ignore
        this setting and show all methods, while the -q can be used to set the ceiling
        much lower and show only methods defined on the object or its direct class.

        Also check out `find-method` command (run `help find-method`).
      BANNER

      def options(opt)
        opt.on :m, :methods, "Show public methods defined on the Object"
        opt.on :M, "instance-methods", "Show public methods defined in a " \
                                       "Module or Class"
        opt.on :p, :ppp, "Show public, protected (in yellow) and private " \
                         "(in green) methods"
        opt.on :q, :quiet, "Show only methods defined on object.singleton_class " \
                           "and object.class"
        opt.on :v, :verbose, "Show methods and constants on all super-classes " \
                             "(ignores Pry.config.ls.ceiling)"
        opt.on :g, :globals, "Show global variables, including those builtin to " \
                             "Ruby (in cyan)"
        opt.on :l, :locals, "Show hash of local vars, sorted by descending size"
        opt.on :c, :constants, "Show constants, highlighting classes (in blue), " \
                               "and exceptions (in purple).\n" \
                               "#{' ' * 32}Constants that are pending autoload? " \
                               "are also shown (in yellow)"
        opt.on :i, :ivars, "Show instance variables (in blue) and class " \
                           "variables (in bright blue)"
        opt.on :G, :grep, "Filter output by regular expression", argument: true

        if Object.respond_to?(:deprecate_constant)
          opt.on :d, :dconstants, "Show deprecated constants"
        end

        return unless Helpers::Platform.jruby?

        opt.on :J, "all-java", "Show all the aliases for methods from java " \
                               "(default is to show only prettiest)"
      end

      # Exclude -q, -v and --grep because they,
      # don't specify what the user wants to see.
      def no_user_opts?
        !(opts[:methods] || opts['instance-methods'] || opts[:ppp] ||
          opts[:globals] || opts[:locals] || opts[:constants] || opts[:ivars])
      end

      def process
        @interrogatee = args.empty? ? target_self : target.eval(args.join(' '))
        raise_errors_if_arguments_are_weird
        ls_entity = LsEntity.new(
          interrogatee: @interrogatee,
          no_user_opts: no_user_opts?,
          opts: opts,
          args: args,
          pry_instance: pry_instance
        )

        pry_instance.pager.page ls_entity.entities_table
      end

      private

      def error_list
        any_args = args.any?
        # rubocop:disable Style/CaseEquality
        non_mod_interrogatee = !(Module === @interrogatee)
        # rubocop:enable Style/CaseEquality
        [
          ['-l does not make sense with a specified Object', :locals, any_args],
          ['-g does not make sense with a specified Object', :globals, any_args],
          ['-q does not make sense with -v', :quiet, opts.present?(:verbose)],
          [
            '-M only makes sense with a Module or a Class', 'instance-methods',
            non_mod_interrogatee
          ],
          [
            '-c only makes sense with a Module or a Class', :constants,
            any_args && non_mod_interrogatee
          ]
        ]
      end

      def raise_errors_if_arguments_are_weird
        error_list.each do |message, option, invalid_expr|
          raise Pry::CommandError, message if opts.present?(option) && invalid_expr
        end
      end
    end

    Pry::Commands.add_command(Pry::Command::Ls)
  end
end
