# encoding: utf-8
# --
# The MIT License (MIT)
#
# Copyright (C) 2013 Gitorious AS
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++
require "use_case/outcome"
require "use_case/validator"
require "ostruct"

module UseCase
  def input_class(input_class)
    @input_class = input_class
  end

  def pre_condition(pc)
    pre_conditions << pc
  end

  def command(command, options = {})
    @commands ||= []
    @commands << {
      :command => command,
      :builder => options[:builder],
      :validators => Array(options[:validators] || options[:validator])
    }
  end

  def execute(params)
    input = @input_class && @input_class.new(params) || params

    if outcome = verify_pre_conditions(input)
      return outcome
    end

    execute_commands(@commands, input)
  end

  private
  def execute_commands(commands, params)
    result = commands.inject(params) do |input, cmd|
      begin
        input = prepare_input(input, cmd[:builder])
      rescue Exception => err
        return PreConditionFailed.new(self, err)
      end

      if outcome = validate_params(input, cmd[:validators])
        return outcome
      end

      cmd[:command].send(cmd[:command].respond_to?(:execute) ? :execute : :call, input)
    end

    SuccessfulOutcome.new(self, result)
  end

  def verify_pre_conditions(input)
    pre_conditions.each do |pc|
      begin
        return PreConditionFailed.new(self, pc) if !pc.satisfied?(input)
      rescue Exception => err
        return PreConditionFailed.new(self, err)
      end
    end
    nil
  end

  def prepare_input(input, builder)
    return input if !builder
    return builder.build(input) if builder.respond_to?(:build)
    builder.call(input)
  end

  def validate_params(input, validators)
    validators.each do |validator|
      result = validator.call(input)
      return FailedOutcome.new(self, result) if !result.valid?
    end
    nil
  end

  def pre_conditions; @pre_conditions ||= []; end
end
