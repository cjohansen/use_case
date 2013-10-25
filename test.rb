require "virtus"
require "use_case"

class Project
  attr_reader :title
  def initialize(title); @title = title; end
  def self.find(id); new("<Project> My name is #{id}"); end
end

class User
  attr_reader :name
  def initialize(name); @name = name; end
  def self.find(id); new("<User> My name is #{id}"); end
end

class NewRepositoryInput
  include Virtus.model

  attribute :name, String
  attribute :description, String
  attribute :merge_requests_enabled, Boolean, :default => true
  attribute :private_repository, Boolean, :default => true

  attribute :user, User
  attribute :user_id, Integer
  attribute :project, Project
  attribute :project_id, Integer

  def project; @project ||= Project.find(@project_id); end
  def user; @user ||= User.find(@user_id); end
end

class NewRepositoryValidator
  include UseCase::Validator
  validates_presence_of :name, :description, :merge_requests_enabled, :private_repository
end

class UserLoggedInPrecondition
  def initialize(user)
    @user = user
  end

  def satisfied?(params)
    @user[:id] == 42
  end
end

class ProjectAdminPrecondition
  def initialize(user)
    @user = user
  end

  def satisfied?(params)
    @user[:name] == params.name
  end
end

class CreateRepositoryCommand
  def initialize(user)
    @user = user
  end

  def execute(params)
    @user.merge(params)
  end
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

### Example

outcome = CreateRepository.new({ :id => 42, :name => "Boy" }).execute({ :name => "Boy" })

outcome.precondition_failed do |pc|
  puts "Pre-condition failed! #{pc}"
end

outcome.success do |result|
  puts "Your request was successful! #{result}"
end

outcome.failure do |errors|
  puts "There was a failure #{errors}"
end

puts outcome.to_s
