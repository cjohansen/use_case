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
require "virtus"
require "use_case"

class Model
  attr_reader :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end

  def to_s; "#<#{self.class.name}[id: #{id}, name: #{name}]>"; end
  def self.find(id); new(id, "From #{self.class.name}.find"); end
end

class Project < Model; end
class Repository < Model; end

class User < Model
  def can_admin?; @can_admin; end
  def can_admin=(ca); @can_admin = ca; end
end

class NewRepositoryInput
  include Virtus
  attribute :name, String
end

NewRepositoryValidator = UseCase::Validator.define do
  validates_presence_of :name
end

class UserLoggedInPrecondition
  def initialize(user); @user = user; end
  def satiesfied?(params); @user && @user.id == 42; end
end

class ProjectAdminPrecondition
  def initialize(user); @user = user; end
  def satiesfied?(params); @user.can_admin?; end
end

class CreateRepositoryCommand
  def initialize(user); @user = user; end
  def execute(params); Repository.new(1349, params.name); end
end

class CreateRepository
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    pre_condition(UserLoggedInPrecondition.new(user))
    pre_condition(ProjectAdminPrecondition.new(user))
    validator(NewRepositoryValidator)
    command(CreateRepositoryCommand.new(user))
  end
end

class ExplodingRepository
  include UseCase

  def initialize(user)
    cmd = CreateRepositoryCommand.new(user)
    def cmd.execute(params); raise "Crash!"; end
    command(cmd)
  end
end

class RepositoryBuilder
  attr_reader :name
  def initialize(name); @name = name; end
  def self.build(params)
    return new(nil) if params[:name] == "invalid"
    new(params[:name] + "!")
  end
end

class CreateRepositoryWithBuilder
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    builder(RepositoryBuilder)
    validator(NewRepositoryValidator)
    command(CreateRepositoryCommand.new(user))
  end
end

class CreateRepositoryWithExplodingBuilder
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    builder(self)
    validator(NewRepositoryValidator)
    command(CreateRepositoryCommand.new(user))
  end

  def build; raise "Oops"; end
end
