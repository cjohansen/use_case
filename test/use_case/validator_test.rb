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
require "use_case/validator"

NewPersonValidator = UseCase::Validator.define do
  validates_presence_of :name
end

CustomValidator = UseCase::Validator.define do
  validate :validate_custom

  def validate_custom
    errors.add(:name, "is not Dude") if name != "Dude"
  end
end

class Person
  attr_accessor :name
end

describe UseCase::Validator do
  it "delegates all calls to underlying object" do
    person = Person.new
    person.name = "Christian"
    result = NewPersonValidator.call(person)

    assert result.respond_to?(:name)
    assert_equal "Christian", result.name
  end

  it "passes valid object" do
    person = Person.new
    person.name = "Christian"
    result = NewPersonValidator.call(person)

    assert result.valid?
  end

  it "fails invalid object" do
    result = NewPersonValidator.call(Person.new)

    refute result.valid?
    assert_equal 1, result.errors.count
  end

  it "supports custom validators" do
    result = CustomValidator.call(Person.new)

    refute result.valid?
    assert_equal 1, result.errors.count
  end

  it "passes custom validator" do
    person = Person.new
    person.name = "Dude"
    result = CustomValidator.call(person)

    assert result.valid?
  end
end
