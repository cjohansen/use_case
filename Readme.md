# Use Case

Compose non-trivial business logic into use cases, that combine:

* Input parameter abstractions; type safety and coercion, and white-listing of
  supported input for any given operation
* Pre-conditions: System-level conditions that must be met, e.g. "a user must be
  logged in" etc.
* Input parameter validation: ActiveRecord-like validations as composable
  objects. Combine specific sets of validation rules for the same input in
  different contexts etc.
* Commands: Avoid defensive coding by performing the core actions in commands
  that receive type-converted input, and are only executed when pre-conditions
  are met and input is validated.

## Example

`UseCase` is designed to break up and keep non-trivial workflows understandable
and decoupled. As such, a trivial example would not illustrate what is good
about it. The following example is simplified, yet still has enough aspects to
show how `UseCase` helps you break things up.

Pre-conditions are conditions not directly related to input parameters alone,
and whose failure signifies other forms of errors than simple validation errors.
If you have a Rails application that uses controller filters, then those are
very likely good candidates for pre-conditions.

The following example is a simplified use case from
[Gitorious](http://gitorious.org) where we want to create a new repository. To
do this, we need a user that can admin the project under which we want the new
repository to live.

This example illustrates how to solve common design challenges in Rails
applications; that does not mean that `UseCase` is only useful to Rails
applications.

First, let's look at what your Rails controller will look like using a
`UseCase`:

```rb
class RepositoryController < ApplicationController
  include Gitorious::Authorization # Adds stuff like can_admin?(actor, thing)

  # ...

  def create
    outcome = CreateRepository.new(self, current_user).execute(params)

    outcome.pre_condition_failed do |condition|
      redirect_to(login_path) and return if condition.is_a?(UserLoggedInPrecondition)
      flash[:error] = "You're not allowed to do that"
      redirect_to project_path
    end

    outcome.failure do |model|
      # Render form with validation errors
      render :new, :locals => { :repository => model }
    end

    outcome.success do |repository|
      redirect_to(repository_path(repository))
    end
  end
end
```

Executing the use case in an `irb` session could look like this:

```rb
include Gitorious::Authorization
user = User.find_by_login("christian")
project = Project.find_by_name("gitorious")
outcome = CreateRepository.new(self, user).execute(:project => project,
                                                   :name => "use_case")
outcome.success? #=> true
outcome.result.name #=> "use_case"
```

The code behind this use case follows:

```rb
require "use_case"
require "virtus"

# Input parameters can be sanitized and pre-processed any way you like. One nice
# way to go about it is to use Datamapper 2's Virtus gem to define a parameter
# set.
#
# This class uses Project.find to look up a project by id if project_id is
# provided and project is not. This is the only class that directly touches
# classes from the Rails application.
class NewRepositoryInput
  include Virtus
  attribute :name, String
  attribute :description, String
  attribute :project, Project
  attribute :project_id, Integer

  def project
    @project ||= Project.find(@project_id)
  end
end

# Validate new repositories. Extremely simplified example.
NewRepositoryValidator = UseCase::Validator.define do
  validates_presence_of :name, :project
end

# This is often implemented as a controller filter in many Rails apps.
# Unfortunately that means we have to duplicate the check when exposing the use
# case in other contexts (e.g. a stand-alone API app, console API etc).
class UserLoggedInPrecondition
  # The constructor is only used by us and can look and do whever we want
  def initialize(user)
    @user = user
  end

  # A pre-condition must define this method
  # Params is an instance of NewRepositoryInput
  def satiesfied?(params)
    !@user.nil?
  end
end

# Another pre-condition that uses app-wide state
class ProjectAdminPrecondition
  def initialize(auth, user)
    @auth = auth
    @user = user
  end

  def satiesfied?(params)
    @auth.can_admin?(@user, params.project)
  end
end

# The business logic. Here we can safely assume that all pre-conditions are
# satiesfied, and that input is valid and has the correct type.
class CreateRepositoryCommand
  def initialize(user)
    @user = user
  end

  # Params is an instance of NewRepositoryInput
  def execute(params)
    params.project.repositories.create(:name => params.name, :user => @user)
  end
end

# The UseCase - this is just wiring together the various classes
class CreateRepository
  include UseCase

  # There's no contract to satiesfy with the constructor - design it to receive
  # any dependencies you need.
  def initialize(auth, user)
    input_class(NewRepositoryInput)
    pre_condition(UserLoggedInPrecondition.new(user))
    pre_condition(ProjectAdminPrecondition.new(auth, user))
    # Multiple validators can be added if needed
    validator(NewRepositoryValidator)
    command(CreateRepositoryCommand.new(user))
  end
end
```

## Input sanitation

In your `UseCase` instance (typically in the constructor), you can call the
`input_class` method to specify which class is used to santize inputs. If you do
not use this, inputs are forwarded to pre-conditions and commands untouched
(i.e. as a `Hash`).

Datamapper 2's [Virtus](https://github.com/solnic/virtus) is a very promising
solution for input sanitation and some level of type-safety. If you provide a
`Virtus` backed class as `input_class` you will get an instance of that class as
`params` in pre-conditions and commands.

## Validations

The validator uses `ActiveModel::Validations`, so any Rails validation can go in
here. The main difference is that the validator is created as a stand-alone
object that can be used with any model instance. This design allows you to
define multiple context-sensitive validations for a single object.

You can of course provide your own validation if you want - any object that
defines `call(object)` and returns something that responds to `valid?` is good.
I am following the Datamapper project closely in this area.

Because `UseCase::Validation` is not a required part of `UseCase`, and people
may want to control their own dependencies, `activemodel` is _not_ a hard
dependency. To use this feature, `gem install activemodel`.

## Pre-conditions

A pre-condition is any object that responds to `satiesfied?(params)` where
params will either be a `Hash` or an instance of whatever you passed to
`input_class`. The method should return `true/false`. If it raises, the outcome
of the use case will call the `pre_condition_failed` block with the raised
error. If it fails, the `pre_condition_failed` block will be called with the
pre-condition instance that failed.

## Commands

A command is any Ruby object that defines an `execute(params)` method. Its
return value will be passed to the outcome's `success` block. Any errors raised
by this method is not rescued, so be sure to wrap `use_case.execute(params)` in
a rescue block if you're worried that it raises.

## Use cases

A use case simply glues together all the components. Define a class, include
`UseCase`, and configure the instance in the constructor. The constructor can
take any arguments you like, making this solution suitable for DI (dependency
injection) style designs.

The use case can optionally call `input_class` once, `pre_condition` multiple
times, and `validator` multiple times. It *must* call `command` once with the
command object.

## Outcomes

`UseCase#execute` returns an `Outcome`. You can use the outcome in primarily two
ways. The primary approach is one that takes blocks for the three situations:
`success(&block)`, `failure(&block)`, and `pre_condition_failed(&block)`. Only
one of these will ever be called. This allows you to declaratively describe
further flow in your program.

For use on the console and other situations, this style is not the most
convenient. For that reason each of the three methods above can also be called
without a block, and they always return something:

* `success` returns the command result
* `failure` returns the validation object (e.g. `failure.errors.inspect`)
* `pre_condition_failed` returns the pre-condition that failed, *or* an
  exception object, if a pre-condition raised an exception.

In addition to these, the outcome object responds to `success?` and
`pre_condition_failed?`.

## Inspiration and design considerations

This small library is very much inspired by
[Mutations](http://github.com/cypriss/mutations). Nice as it is, I found it to
be a little limiting in terms of what kinds of commands it could comfortably
encapsulate. Treating everything as a hash of inputs makes it hard to do things
like "redirect if there's no user, render form if there are validation errors
and redirect to new object if successful".

As I started working on my own solution I quickly recognized the power in
separating input parameter type constraints/coercions from validation rules.
This is another area where UseCase differs from Mutations. UseCase is probably
slightly more "enterprise" than Mutations, but fits the kinds of problems I
intend to solve with it better than Mutations did.

## Testing

Using UseCase will allow you to test almost all logic completely without loading
Rails. In the example above, the input conversion is the only place that
directly touches any classes from the Rails application. The rest of the classes
work by the "data in, data out" principle, meaning you can easily test them with
any kind of object (which spares you of loading heavy ActiveRecord-bound models,
running opaque controller tets etc).

## Installation

    $ gem install use_case

## Developing

    $ bundle install
    $ rake

## Contributing

* Clone repo
* Make changes
* Add test(s)
* Run tests
* If adding new abilities, add docs in Readme, or commit a working example
* Send patch, [pull request](http://github.com/cjohansen/use_case) or [merge request](http://gitorious.org/gitorious/use_case)

If you intend to add entirely new features, you might want to open an issue to
discuss it with me first.

## License

UseCase is free software licensed under the MIT license.

```
The MIT License (MIT)

Copyright (C) 2013 Gitorious AS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
