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
require "test_helper"
require "use_case/outcome"

class MyPreCondition
  def self.symbol; :something; end
end

describe UseCase::Outcome do
  it "defaults to not failing and not being successful (noop)" do
    outcome = UseCase::Outcome.new
    outcome.success { fail "Shouldn't succeed" }
    outcome.pre_condition_failed { fail "Shouldn't have failed pre-conditions" }
    outcome.failure { fail "Shouldn't fail" }

    refute outcome.pre_condition_failed?
    refute outcome.success?
  end

  describe UseCase::SuccessfulOutcome do
    it "does not fail" do
      outcome = UseCase::SuccessfulOutcome.new
      outcome.pre_condition_failed { fail "Shouldn't have failed pre-conditions" }
      outcome.failure { fail "Shouldn't fail" }

      refute outcome.pre_condition_failed?
      assert outcome.success?
    end

    it "yields and returns result" do
      result = 42
      yielded_result = nil
      outcome = UseCase::SuccessfulOutcome.new(result)
      returned_result = outcome.success { |res| yielded_result = res }

      assert_equal result, yielded_result
      assert_equal result, returned_result
    end

    it "gets result without block" do
      outcome = UseCase::SuccessfulOutcome.new(42)
      assert_equal 42, outcome.success
    end
  end

  describe UseCase::PreConditionFailed do
    it "does not succeed or fail" do
      outcome = UseCase::PreConditionFailed.new
      outcome.success { fail "Shouldn't succeed" }
      outcome.failure { fail "Shouldn't fail" }

      assert outcome.pre_condition_failed?
      refute outcome.success?
    end

    it "returns failed pre-condition wrapped" do
      pre_condition = 42
      outcome = UseCase::PreConditionFailed.new(pre_condition)
      returned_pc = outcome.pre_condition_failed

      assert_equal pre_condition, returned_pc.pre_condition
    end

    describe "yielded wrapper" do
      it "has flow control API" do
        yielded = false
        pre_condition = Array.new
        outcome = UseCase::PreConditionFailed.new(pre_condition)

        returned_pc = outcome.pre_condition_failed do |f|
          f.when(:array) { |pc| yielded = pc }
        end

        assert_equal yielded, pre_condition
      end

      it "does not call non-matching block" do
        yielded = nil
        pre_condition = Array.new
        outcome = UseCase::PreConditionFailed.new(pre_condition)

        outcome.pre_condition_failed do |f|
          f.when(:something) { |pc| yielded = pc }
        end

        assert_nil yielded
      end

      it "matches by class symbol" do
        yielded = false
        pre_condition = MyPreCondition.new
        outcome = UseCase::PreConditionFailed.new(pre_condition)

        returned_pc = outcome.pre_condition_failed do |f|
          f.when(:something) { |pc| yielded = pc }
        end

        assert_equal yielded, pre_condition
      end

      it "yields to otherwise if no match" do
        yielded = false
        pre_condition = MyPreCondition.new
        outcome = UseCase::PreConditionFailed.new(pre_condition)

        returned_pc = outcome.pre_condition_failed do |f|
          f.when(:nothing) { |pc| yielded = 42 }
          f.otherwise { |pc| yielded = pc }
        end

        assert_equal yielded, pre_condition
      end

      it "raises if calling when after otherwise" do
        pre_condition = MyPreCondition.new
        outcome = UseCase::PreConditionFailed.new(pre_condition)

        assert_raises(Exception) do
          returned_pc = outcome.pre_condition_failed do |f|
            f.otherwise { |pc| yielded = pc }
            f.when(:nothing) { |pc| yielded = 42 }
          end
        end
      end

      it "accesses pre-condition symbol" do
        pre_condition = MyPreCondition.new
        outcome = UseCase::PreConditionFailed.new(pre_condition)
        failure = nil

        outcome.pre_condition_failed do |f|
          failure = f
        end

        assert_equal :something, failure.symbol
      end

      it "accesses pre-condition instance symbol" do
        pre_condition = MyPreCondition.new
        def pre_condition.symbol; :other; end
        outcome = UseCase::PreConditionFailed.new(pre_condition)
        failure = nil

        outcome.pre_condition_failed do |f|
          failure = f
        end

        assert_equal :other, failure.symbol
      end
    end
  end

  describe UseCase::FailedOutcome do
    it "does not succeed or fail pre-conditions" do
      outcome = UseCase::FailedOutcome.new
      outcome.success { fail "Shouldn't succeed" }
      outcome.pre_condition_failed { fail "Shouldn't fail pre-conditions" }

      refute outcome.pre_condition_failed?
      refute outcome.success?
    end

    it "yields and returns validation failure" do
      failure = 42
      yielded_result = nil
      outcome = UseCase::FailedOutcome.new(failure)
      returned_result = outcome.failure { |result| yielded_result = result }

      assert_equal failure, yielded_result
      assert_equal failure, returned_result
    end

    it "gets failure without block" do
      outcome = UseCase::FailedOutcome.new(42)
      assert_equal 42, outcome.failure
    end
  end
end
