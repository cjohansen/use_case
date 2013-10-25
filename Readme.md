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

_NB!_ This example illustrates how to solve common design challenges in Rails
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

    outcome.pre_condition_failed do |f|
      f.when(:user_required) { redirect_to(login_path) }
      f.otherwise do
        flash[:error] = "You're not allowed to do that"
        redirect_to project_path
      end
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
  include Virtus.model
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
class UserRequired
  # The constructor is only used by us and can look and do whever we want
  def initialize(user)
    @user = user
  end

  # A pre-condition must define this method
  # Params is an instance of NewRepositoryInput
  def satisfied?(params)
    !@user.nil?
  end
end

# Another pre-condition that uses app-wide state
class ProjectAdminPrecondition
  def initialize(auth, user)
    @auth = auth
    @user = user
  end

  def satisfied?(params)
    @auth.can_admin?(@user, params.project)
  end
end

# The business logic. Here we can safely assume that all pre-conditions are
# satisfied, and that input is valid and has the correct type.
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
    add_pre_condition(UserLoggedInPrecondition.new(user))
    add_pre_condition(ProjectAdminPrecondition.new(auth, user))
    # A step is comprised of a command with 0, 1 or many validators
    # (e.g. :validators => [...])
    # The use case can span multiple steps (see below)
    step(CreateRepositoryCommand.new(user), :validator => NewRepositoryValidator)
  end
end
```

## The use case pipeline at a glance

This is the high-level overview of how `UseCase` strings up a pipeline
for you to plug in various kinds of business logic:

```
User input (-> input sanitation) (-> pre-conditions) -> steps
```

1. Start with a hash of user input
2. Optionally wrap this in an object that performs type-coercion,
   enforces types etc.
3. Optionally run pre-conditions on the santized input
4. Execute steps. The initial step is fed the sanitized input, each
   following command is fed the result from the previous step.

Each step is a pipeline in its own right:

```
Step: (-> builder) (-> validations) -> command
```

1. Optionally refine input by running it through a pre-execution "builder"
2. Optionally run (refined) input through one or more validators
3. Execute command with (refined) input

## Input sanitation

In your `UseCase` instance (typically in the constructor), you can call the
`input_class` method to specify which class is used to santize inputs. If you do
not use this, inputs are forwarded to pre-conditions and commands untouched
(i.e. as a `Hash`).

Datamapper 2's [Virtus](https://github.com/solnic/virtus) is a very promising
solution for input sanitation and some level of type-safety. If you provide a
`Virtus` backed class as `input_class` you will get an instance of that class as
`params` in pre-conditions and commands.

## Pre-conditions

A pre-condition is any object that responds to `satisfied?(params)` where params
will either be a `Hash` or an instance of whatever you passed to `input_class`.
The method should return `true/false`. If it raises, the outcome of the use case
will call the `pre_condition_failed` block with the raised error. If it fails,
the `pre_condition_failed` block will be called with a failure object wrapping
the pre-condition instance that failed.

The wrapper failure object provides three methods of interest:

### `when`

The when method allows you to associate a block of code with a specific
pre-condition. The block is called with the pre-condition instance if that
pre-condition fails. Because the pre-condition class may not be explicitly
available in contexts where you want to use `when`, a symbolic representation is
used.

If you have the following two pre-conditions:

* `UserRequired`
* `ProjectAdminRequired`

Then you can use `when(:user_required) { |condition ... }` and
`when(:project_admin_required) { |condition ... }`. If you want control over how
a class name is symbolized, make the class implement `symbol`, i.e.:

```js
class UserRequired
  def self.symbol; :user_plz; end
  def initialize(user); @user = user; end
  def satisfied?(params); !@user.nil?; end
end

# Then:

outcome = use_case.execute(params)

outcome.pre_condition_failed do |f|
  f.when(:user_plz) { |c| puts "Needs moar user" }
  # ...
end
```

### `otherwise`

`otherwise` is a catch-all that is called if no calls to `when` mention the
offending pre-condition:


```js
class CreateProject
  include UseCase

  def initialize(user)
    add_pre_condition(UserRequired.new(user))
    add_pre_condition(AdminRequired.new(user))
    step(CreateProjectCommand.new(user))
  end
end

# Then:

outcome = CreateProject.new(current_user).execute(params)

outcome.pre_condition_failed do |f|
  f.when(:user_required) { |c| puts "Needs moar user" }
  f.otherwise { |c| puts "#{c.name} pre-condition failed" }
end
```
### `pre_condition`

If you want to roll your own flow control, simply get the offending
pre-condition from this method.

## Validations

The validator uses `ActiveModel::Validations`, so any Rails validation can go in
here (except for `validates_uniqueness_of`, which apparently comes from
elsewhere - see example below for how to work around this). The main difference
is that the validator is created as a stand-alone object that can be used with
any model instance. This design allows you to define multiple context-sensitive
validations for a single object.

You can of course provide your own validation if you want - any object that
defines `call(object)` and returns something that responds to `valid?` is good.
I am following the Datamapper2 project closely in this area.

Because `UseCase::Validation` is not a required part of `UseCase`, and people
may want to control their own dependencies, `activemodel` is _not_ a hard
dependency. To use this feature, `gem install activemodel`.

## Builders

When user input has passed input sanitation and pre-conditions have been
satisfied, you can optionally pipe input through a "builder" before handing it
over to validations and a command.

The builder should be an object with a `build` or a `call` method (if it has
both, `build` will be preferred). The method will be called with santized input.
The return value will be passed on to validators and the commands.

Builders can be useful if you want to run validations on a domain object rather
than directly on "dumb" input.

### Example

In a Rails application, the builder is useful to wrap user input in an unsaved
`ActiveRecord` instance. The unsaved object will be run through the validators,
and (if found valid), the command can save it and perform additional tasks that
you possibly do with `ActiveRecord` observers now.

This example also shows how to express uniqueness validators when you move
validations out of your `ActiveRecord` models.

```rb
require "activemodel"
require "virtus"
require "use_case"

class User < ActiveRecord::Base
  def uniq?
    user = User.where("lower(name) = ?", name).first
    user.nil? || user == self
  end
end

UserValidator = UseCase::Validator.define do
  validates_presence_of :name
  validate :uniqueness

  def uniqueness
    errors.add(:name, "is taken") if !uniq?
  end
end

class NewUserInput
  include Virtus.model
  attribute :name, String
end

class NewUserCommand
  def execute(user)
    user.save!
    Mailer.user_signup(user).deliver
    user
  end

  def build(params)
    User.new(:name => params.name)
  end
end

class CreateUser
  include UseCase

  def initialize
    input_class(NewUserInput)
    cmd = NewUserCommand.new
    # Use the command as a builder too
    step(cmd, :builder => cmd, :validator => UserValidator)
  end
end

# Usage:
outcome = CreateUser.new.execute(:name => "Chris")
outcome.success? #=> true
outcome.result #=> #<User name: "Chris">
```

If the command fails to execute due to validation errors, using the builder
allows us to access the partial object for re-rendering forms etc. Because this
is such a common scenario, the command will automatically be used as the builder
as well if there is no explicit `:builder` option, and the command responds to
`build`. This means that the command in the previous example could be written as
so:

```rb
class CreateUser
  include UseCase

  def initialize
    input_class(NewUserInput)
    step(NewUserCommand.new, :validator => UserValidator)
  end
end
```

When calling `execute` on this use case, we can observe the following flow:

```rb
# This
params = { :name => "Dude" }
CreateUser.new.execute(params)

# ...roughly expands to:
# (command is the command instance wired in the use case constructor)
input = NewUserInput.new(params)
prepared = command.build(input)

if UserValidator.call(prepared).valid?
  command.execute(prepared)
end
```

### Note

I'm not thrilled by `builder` as a name/concept. Suggestions for a better name
is welcome.

## Commands

A command is any Ruby object that defines an `execute(params)` method.
Alternately, it can be an object that responds to `call` (e.g. a lambda). Its
return value will be passed to the outcome's `success` block. Any errors raised
by this method is not rescued, so be sure to wrap `use_case.execute(params)` in
a rescue block if you're worried that it raises. Better yet, detect known causes
of exceptions in a pre-condition so you know that the command does not raise.

If the command responds to the `build` message and there is no explicitly
configured `:builder` for the current step, the command is also used as a
builder (see example above, under "Builders").

## Use cases

A use case simply glues together all the components. Define a class, include
`UseCase`, and configure the instance in the constructor. The constructor can
take any arguments you like, making this solution suitable for DI (dependency
injection) style designs.

The use case can optionally call `input_class` once, `add_pre_condition`
multiple times, and `step` multiple times.

When using multiple steps, input sanitation with the `input_class` is
performed once only. Pre-conditions are also only checked once - before any
steps are executed. The use case will then execute the steps:

```
step_1: sanitizied_input -> (builder ->) (validators ->) command
step_n: command_n-1 result -> (builder ->) (validators ->) command
```

In other words, all commands except the first one will be executed with the
result of the previous command as input.

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
