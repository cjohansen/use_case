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

    outcome.pre_condition_failed do |pc|
      assert_equal UserLoggedInPrecondition, pc.class
    end
  end

  it "fails second pre-condition; user cannot admin" do
    @logged_in_user.can_admin = false
    outcome = CreateRepository.new(@logged_in_user).execute({})

    outcome.pre_condition_failed do |pc|
      assert_equal ProjectAdminPrecondition, pc.class
    end
  end

  it "fails with error if pre-condition raises" do
    def @logged_in_user.id; raise "Oops!"; end
    outcome = CreateRepository.new(@logged_in_user).execute({})

    outcome.pre_condition_failed do |pc|
      assert_equal RuntimeError, pc.class
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
end
