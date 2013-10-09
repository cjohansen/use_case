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
require "use_case"
require "sample_use_case"

describe UseCase do
  before do
    @logged_in_user = User.new(42, "Christian")
    @logged_in_user.can_admin = true
  end

  it "fails first pre-condition; no user logged in" do
    outcome = CreateRepository.new(nil).execute({})

    outcome.pre_condition_failed do |f|
      assert_equal UserLoggedInPrecondition, f.pre_condition.class
    end
  end

  it "fails second pre-condition; user cannot admin" do
    @logged_in_user.can_admin = false
    outcome = CreateRepository.new(@logged_in_user).execute({})

    outcome.pre_condition_failed do |f|
      assert_equal ProjectAdminPrecondition, f.pre_condition.class
    end
  end

  it "fails with error if pre-condition raises" do
    def @logged_in_user.id; raise "Oops!"; end

    assert_raises RuntimeError do
      CreateRepository.new(@logged_in_user).execute({})
    end
  end

  it "fails on input validation" do
    outcome = CreateRepository.new(@logged_in_user).execute({})

    validation = outcome.failure do |v|
      refute v.valid?
      assert_equal 1, v.errors.count
      assert v.errors[:name]
    end

    refute_nil validation
  end

  it "executes command" do
    outcome = CreateRepository.new(@logged_in_user).execute({ :name => "My repository" })

    result = outcome.success do |res|
      assert_equal "My repository", res.name
      assert res.is_a?(Repository)
    end

    refute_nil result
  end

  it "raises if command raises" do
    use_case = ExplodingRepository.new(@logged_in_user)

    assert_raises RuntimeError do
      use_case.execute(nil)
    end
  end

  it "fails when builder processed inputs fail validation" do
    outcome = CreateRepositoryWithBuilder.new(@logged_in_user).execute({ :name => "invalid" })

    validation = outcome.failure do |v|
      refute v.valid?
      assert_equal 1, v.errors.count
      assert v.errors[:name]
    end

    refute_nil validation
  end

  it "passes builder processed inputs to command" do
    outcome = CreateRepositoryWithBuilder.new(@logged_in_user).execute({ :name => "Dude" })

    assert outcome.success?, outcome.failure && outcome.failure.full_messages.join("\n")
    assert_equal "Dude!", outcome.result.name
  end

  it "treats builder error as failed pre-condition" do
    assert_raises RuntimeError do
      CreateRepositoryWithExplodingBuilder.new(@logged_in_user).execute({ :name => "Dude" })
    end
  end

  it "chains two commands" do
    outcome = CreatePimpedRepository.new(@logged_in_user).execute({ :name => "Mr" })

    assert_equal 1349, outcome.result.id
    assert_equal "Mr (Pimped)", outcome.result.name
  end

  it "chains two commands with individual builders" do
    outcome = CreatePimpedRepository2.new(@logged_in_user).execute({ :name => "Mr" })

    assert_equal 42, outcome.result.id
    assert_equal "Mr! (Pimped)", outcome.result.name
  end

  it "fails one of three validators" do
    outcome = CreatePimpedRepository3.new(@logged_in_user).execute({ :name => "Mr" })

    refute outcome.success?
    assert_equal "You cannot win", outcome.failure.errors[:name].join
  end

  it "calls command lambda" do
    outcome = InlineCommand.new.execute({ :name => "Dissection" })

    assert outcome.success?
    assert_equal "Dissection", outcome.result
  end

  it "implicitly uses command as builder" do
    outcome = ImplicitBuilder.new(@logged_in_user).execute({ :name => "Mr" })

    assert_equal 42, outcome.result.id
    assert_equal "Mr! (Pimped)", outcome.result.name
  end
end
