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

module UseCase
  class Outcome
    attr_reader :use_case

    def initialize(use_case = nil)
      @use_case = use_case
    end

    def pre_condition_failed?; false; end
    def success?; false; end
    def success; end
    def result; end
    def pre_condition_failed; end
    def failure; end
  end

  class SuccessfulOutcome < Outcome
    def initialize(use_case = nil, result = nil)
      super(use_case)
      @result = result
    end

    def success?; true; end

    def success
      yield @result if block_given?
      @result
    end

    def result; @result; end

    def to_s
      "#<UseCase::SuccessfulOutcome: #{@result}>"
    end
  end

  class PreConditionFailed < Outcome
    def initialize(use_case = nil, pre_condition = nil)
      super(use_case)
      @pre_condition = pre_condition
      @failure = PreConditionFailure.new(@pre_condition)
    end

    def pre_condition_failed?; true; end

    def pre_condition_failed
      yield @failure if block_given?
      @pre_condition
    end

    def to_s
      "#<UseCase::PreConditionFailed: #{@pre_condition}>"
    end
  end

  class PreConditionFailure
    attr_reader :pre_condition
    def initialize(pre_condition); @pre_condition = pre_condition; end

    def when(symbol, &block)
      raise Exception.new("Cannot call when after otherwise") if @otherwise
      if symbol == class_symbol
        @called = true
        yield(@pre_condition)
      end
    end

    def otherwise(&block)
      @otherwise = true
      yield(@pre_condition) if !@called
    end

    private
    def class_symbol
      klass = @pre_condition.class
      return klass.symbol if klass.respond_to?(:symbol)
      klass.name.gsub(/([^A-Z])([A-Z])/, '\1_\2').gsub(/[:_]+/, "_").downcase.to_sym
    end
  end

  class FailedOutcome < Outcome
    attr_reader :input

    def initialize(use_case = nil, errors = nil, input = nil)
      super(use_case)
      @errors = errors
      @input = input
    end

    def failure
      yield @errors if block_given?
      @errors
    end

    def to_s
      "#<UseCase::FailedOutcome: #{@errors}>"
    end
  end
end
