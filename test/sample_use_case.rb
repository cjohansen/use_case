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
  attr_accessor :id, :name

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
  include Virtus.model
  attribute :name, String
end

NewRepositoryValidator = UseCase::Validator.define do
  validates_presence_of :name
end

class UserLoggedInPrecondition
  def initialize(user); @user = user; end
  def satisfied?(params); @user && @user.id == 42; end
end

class ProjectAdminPrecondition
  def initialize(user); @user = user; end
  def satisfied?(params); @user.can_admin?; end
end

class CreateRepositoryCommand
  def initialize(user); @user = user; end
  def execute(params); Repository.new(1349, params.name); end
end

class CreateRepository
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    add_pre_condition(UserLoggedInPrecondition.new(user))
    add_pre_condition(ProjectAdminPrecondition.new(user))
    step(CreateRepositoryCommand.new(user), :validators => NewRepositoryValidator)
  end
end

class ExplodingRepository
  include UseCase

  def initialize(user)
    cmd = CreateRepositoryCommand.new(user)
    def cmd.execute(params); raise "Crash!"; end
    step(cmd)
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
    step(CreateRepositoryCommand.new(user), {
        :validators => NewRepositoryValidator,
        :builder => RepositoryBuilder
      })
  end
end

class CreateRepositoryWithExplodingBuilder
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    step(CreateRepositoryCommand.new(user), :builder => self)
  end

  def build(params); raise "Oops"; end
end

class PimpRepositoryCommand
  def execute(repository)
    repository.name += " (Pimped)"
    repository
  end
end

class PimpRepositoryCommandWithBuilder
  def build(repository)
    repository.id = 42
    repository
  end

  def execute(repository)
    repository.name += " (Pimped)"
    repository
  end
end

class CreatePimpedRepository
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    step(CreateRepositoryCommand.new(user))
    step(PimpRepositoryCommand.new)
  end
end

class CreatePimpedRepository2
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    step(CreateRepositoryCommand.new(user), :builder => RepositoryBuilder)
    cmd = PimpRepositoryCommandWithBuilder.new
    step(cmd, :builder => cmd)
  end
end

PimpedRepositoryValidator = UseCase::Validator.define do
  validate :cannot_win
  def cannot_win; errors.add(:name, "You cannot win"); end
end

class CreatePimpedRepository3
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    cmd = PimpRepositoryCommandWithBuilder.new
    step(CreateRepositoryCommand.new(user), :builder => RepositoryBuilder, :validator => NewRepositoryValidator)
    step(cmd, :builder => cmd, :validators => [NewRepositoryValidator, PimpedRepositoryValidator])
  end
end

class InlineCommand
  include UseCase

  def initialize
    step(lambda { |params| params[:name] })
  end
end

class ImplicitBuilder
  include UseCase

  def initialize(user)
    input_class(NewRepositoryInput)
    step(CreateRepositoryCommand.new(user), :builder => RepositoryBuilder)
    step(PimpRepositoryCommandWithBuilder.new)
  end
end
